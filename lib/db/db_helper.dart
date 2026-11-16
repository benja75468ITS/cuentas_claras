import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/modelos.dart';

class DbHelper {
  DbHelper._();
  static final DbHelper instancia = DbHelper._();
  Database? _db;

  Future<Database> get db async => _db ??= await _abrir();

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

  Future<void> registrarPago(Pago p) async => (await db).insert('pagos', {
        'grupo_id': p.grupoId,
        'de_id': p.deId,
        'a_id': p.aId,
        'monto': p.monto,
        'fecha': p.fecha,
      });

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
    final d = await db;
    await d.transaction((t) async {
      final id = await t.insert('grupos', {'nombre': nombre});
      for (final p in personas) {
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

  Future<void> agregarPersona(int grupoId, String nombre) async =>
      (await db).insert('personas', {'grupo_id': grupoId, 'nombre': nombre});

  // ---------- Gastos ----------
  Future<List<Gasto>> gastos(int grupoId) async {
    final d = await db;
    final r = await d.query('gastos', where: 'grupo_id = ?', whereArgs: [grupoId], orderBy: 'id DESC');
    final lista = <Gasto>[];
    for (final m in r) {
      final parts = await d.query('participantes',
          where: 'gasto_id = ?', whereArgs: [m['id']]);
      lista.add(Gasto(
        id: m['id'] as int,
        grupoId: grupoId,
        descripcion: m['descripcion'] as String,
        monto: (m['monto'] as num).toDouble(),
        montoOriginal: (m['monto_original'] as num).toDouble(),
        moneda: m['moneda'] as String,
        pagadorId: m['pagador_id'] as int,
        participantes: parts.map((p) => p['persona_id'] as int).toList(),
      ));
    }
    return lista;
  }

  Future<void> crearGasto(Gasto g) async {
    final d = await db;
    await d.transaction((t) async {
      final id = await t.insert('gastos', {
        'grupo_id': g.grupoId,
        'descripcion': g.descripcion,
        'monto': g.monto,
        'monto_original': g.montoOriginal,
        'moneda': g.moneda,
        'pagador_id': g.pagadorId,
      });
      for (final p in g.participantes) {
        await t.insert('participantes', {'gasto_id': id, 'persona_id': p});
      }
    });
  }

  Future<void> eliminarGasto(int id) async =>
      (await db).delete('gastos', where: 'id = ?', whereArgs: [id]);
}