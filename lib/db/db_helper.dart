import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/modelos.dart';

class DbHelper {
  DbHelper._();
  static final DbHelper instancia = DbHelper._();
  Future<Database>? _dbFuture;

  Future<Database> get db => _dbFuture ??= _abrir().catchError((Object e) {
        _dbFuture = null;
        throw e;
      });

  Future<Database> _abrir() async {
    return openDatabase(
      join(await getDatabasesPath(), 'cuentas_claras.db'),
      version: 2,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (d, o, n) async {
        if (o < 2) await _crearPagos(d);
      },
      onCreate: (d, v) async {
        await d.execute('''CREATE TABLE grupos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE personas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          grupo_id INTEGER NOT NULL REFERENCES grupos(id) ON DELETE CASCADE,
          nombre TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE gastos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          grupo_id INTEGER NOT NULL REFERENCES grupos(id) ON DELETE CASCADE,
          descripcion TEXT NOT NULL,
          monto REAL NOT NULL,
          monto_original REAL NOT NULL,
          moneda TEXT NOT NULL,
          pagador_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE CASCADE)''');
        await d.execute('''CREATE TABLE participantes(
          gasto_id INTEGER NOT NULL REFERENCES gastos(id) ON DELETE CASCADE,
          persona_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
          PRIMARY KEY (gasto_id, persona_id))''');
        await _crearPagos(d);
      },
    );
  }

  static Future<void> _crearPagos(Database d) => d.execute('''CREATE TABLE pagos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          grupo_id INTEGER NOT NULL REFERENCES grupos(id) ON DELETE CASCADE,
          de_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
          a_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
          monto REAL NOT NULL,
          fecha TEXT NOT NULL)''');

  // ---------- Pagos ----------
  Future<List<Pago>> pagos(int grupoId) async {
    final r = await (await db)
        .query('pagos', where: 'grupo_id = ?', whereArgs: [grupoId], orderBy: 'id DESC');
    return r.map(Pago.fromMap).toList();
  }

  Future<void> registrarPago(Pago p) async {
    if (p.deId == p.aId) {
      throw ArgumentError('El pagador y el receptor no pueden ser la misma persona');
    }
    if (!p.monto.isFinite || p.monto <= 0) {
      throw ArgumentError('El monto del pago debe ser un valor finito mayor a 0');
    }
    final monto = redondearMoneda(p.monto);
    if (!monto.isFinite || monto <= 0) {
      throw ArgumentError('El monto del pago debe ser de al menos un centavo');
    }
    if (p.fecha.trim().isEmpty) {
      throw ArgumentError('La fecha del pago no puede estar vacía');
    }
    final d = await db;
    await d.transaction((t) async {
      await _validarPersonasDelGrupo(t, p.grupoId, [p.deId, p.aId]);
      await t.insert('pagos', {
        'grupo_id': p.grupoId,
        'de_id': p.deId,
        'a_id': p.aId,
        'monto': monto,
        'fecha': p.fecha,
      });
    });
  }

  Future<void> eliminarPago(int id) async =>
      (await db).delete('pagos', where: 'id = ?', whereArgs: [id]);

  // ---------- Grupos ----------
  Future<List<Grupo>> grupos() async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT g.*,
        (SELECT COUNT(*) FROM personas WHERE grupo_id = g.id) AS n_personas,
        (SELECT COALESCE(SUM(monto), 0) FROM gastos WHERE grupo_id = g.id) AS total
      FROM grupos g ORDER BY g.id DESC''');
    return r.map(Grupo.fromMap).toList();
  }

  Future<void> crearGrupo(String nombre, List<String> personas) async {
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      throw ArgumentError('El nombre del grupo no puede estar vacío');
    }
    final vistos = <String>{};
    final unicas = <String>[];
    for (final p in personas) {
      final limpio = p.trim();
      if (limpio.isEmpty) continue;
      if (vistos.add(limpio.toLowerCase())) {
        unicas.add(limpio);
      }
    }
    if (unicas.length < 2) {
      throw ArgumentError('El grupo debe tener al menos 2 personas distintas');
    }

    final d = await db;
    await d.transaction((t) async {
      final id = await t.insert('grupos', {'nombre': nombreLimpio});
      for (final p in unicas) {
        await t.insert('personas', {'grupo_id': id, 'nombre': p});
      }
    });
  }

  Future<void> eliminarGrupo(int id) async =>
      (await db).delete('grupos', where: 'id = ?', whereArgs: [id]);

  // ---------- Personas ----------
  Future<List<Persona>> personas(int grupoId) async {
    final r = await (await db)
        .query('personas', where: 'grupo_id = ?', whereArgs: [grupoId], orderBy: 'id');
    return r.map(Persona.fromMap).toList();
  }

  Future<void> agregarPersona(int grupoId, String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw ArgumentError('El nombre de la persona no puede estar vacío');
    }
    final d = await db;
    await d.transaction((t) async {
      final existentes = await t.query(
        'personas',
        columns: ['nombre'],
        where: 'grupo_id = ?',
        whereArgs: [grupoId],
      );
      if (existentes.any(
        (p) => (p['nombre'] as String).toLowerCase() == limpio.toLowerCase(),
      )) {
        throw ArgumentError('Ya existe "$limpio" en este grupo');
      }
      await t.insert('personas', {'grupo_id': grupoId, 'nombre': limpio});
    });
  }

  // ---------- Gastos ----------
  Future<List<Gasto>> gastos(int grupoId) async {
    final d = await db;
    final r = await d.query('gastos',
        where: 'grupo_id = ?', whereArgs: [grupoId], orderBy: 'id DESC');
    if (r.isEmpty) return [];

    // Carga todos los participantes del grupo en una sola consulta (evita N+1 queries).
    final partsRows = await d.rawQuery('''
      SELECT p.gasto_id, p.persona_id
      FROM participantes p
      INNER JOIN gastos g ON g.id = p.gasto_id
      WHERE g.grupo_id = ?
      ORDER BY p.persona_id
    ''', [grupoId]);

    final porGasto = <int, List<int>>{};
    for (final row in partsRows) {
      final gId = row['gasto_id'] as int;
      final pId = row['persona_id'] as int;
      (porGasto[gId] ??= []).add(pId);
    }

    return [
      for (final m in r)
        Gasto(
          id: m['id'] as int,
          grupoId: grupoId,
          descripcion: m['descripcion'] as String,
          monto: (m['monto'] as num).toDouble(),
          montoOriginal: (m['monto_original'] as num).toDouble(),
          moneda: m['moneda'] as String,
          pagadorId: m['pagador_id'] as int,
          participantes: porGasto[m['id'] as int] ?? const [],
        ),
    ];
  }

  Future<void> crearGasto(Gasto g) async {
    final unicos = g.participantes.toSet().toList();
    if (unicos.isEmpty) {
      throw ArgumentError('El gasto debe tener al menos un participante');
    }
    if (!g.monto.isFinite || g.monto <= 0) {
      throw ArgumentError('El monto del gasto debe ser un valor finito mayor a 0');
    }
    if (!g.montoOriginal.isFinite || g.montoOriginal <= 0) {
      throw ArgumentError('El monto original debe ser un valor finito mayor a 0');
    }
    final monto = redondearMoneda(g.monto);
    final montoOriginal = redondearMoneda(g.montoOriginal);
    if (!monto.isFinite || monto <= 0 || !montoOriginal.isFinite || montoOriginal <= 0) {
      throw ArgumentError('Los montos deben ser de al menos un centavo');
    }
    final descripcion = g.descripcion.trim();
    if (descripcion.isEmpty) {
      throw ArgumentError('La descripción del gasto no puede estar vacía');
    }
    final moneda = g.moneda.trim().toUpperCase();
    if (moneda.isEmpty) {
      throw ArgumentError('La moneda del gasto no puede estar vacía');
    }
    final d = await db;
    await d.transaction((t) async {
      await _validarPersonasDelGrupo(t, g.grupoId, [g.pagadorId, ...unicos]);
      final id = await t.insert('gastos', {
        'grupo_id': g.grupoId,
        'descripcion': descripcion,
        'monto': monto,
        'monto_original': montoOriginal,
        'moneda': moneda,
        'pagador_id': g.pagadorId,
      });
      for (final p in unicos) {
        await t.insert('participantes', {'gasto_id': id, 'persona_id': p});
      }
    });
  }

  Future<void> _validarPersonasDelGrupo(
    Transaction t,
    int grupoId,
    Iterable<int> personaIds,
  ) async {
    final ids = personaIds.toSet().toList();
    if (ids.isEmpty) {
      throw ArgumentError('Se requiere al menos una persona del grupo');
    }
    final placeholders = List.filled(ids.length, '?').join(', ');
    final filas = await t.rawQuery(
      'SELECT id FROM personas WHERE grupo_id = ? AND id IN ($placeholders)',
      [grupoId, ...ids],
    );
    if (filas.length != ids.length) {
      throw ArgumentError('Todas las personas deben pertenecer al mismo grupo');
    }
  }

  Future<void> eliminarGasto(int id) async =>
      (await db).delete('gastos', where: 'id = ?', whereArgs: [id]);
}
