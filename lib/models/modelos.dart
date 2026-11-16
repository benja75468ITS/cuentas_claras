class Grupo {
  final int id;
  final String nombre;
  final int nPersonas;
  final double total;
  Grupo({required this.id, required this.nombre, this.nPersonas = 0, this.total = 0});

  factory Grupo.fromMap(Map<String, Object?> m) => Grupo(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        nPersonas: (m['n_personas'] ?? 0) as int,
        total: ((m['total'] ?? 0) as num).toDouble(),
      );
}

class Persona {
  final int id;
  final int grupoId;
  final String nombre;
  Persona({required this.id, required this.grupoId, required this.nombre});

  factory Persona.fromMap(Map<String, Object?> m) => Persona(
        id: m['id'] as int,
        grupoId: m['grupo_id'] as int,
        nombre: m['nombre'] as String,
      );
}

class Gasto {
  final int? id;
  final int grupoId;
  final String descripcion;
  final double monto; // siempre en MXN
  final double montoOriginal;
  final String moneda;
  final int pagadorId;
  final List<int> participantes;

  Gasto({
    this.id,
    required this.grupoId,
    required this.descripcion,
    required this.monto,
    required this.montoOriginal,
    required this.moneda,
    required this.pagadorId,
    required this.participantes,
  });
}

String dinero(double v) => '\$${v.toStringAsFixed(2)}';

/// Pago registrado: [deId] le pagó [monto] a [aId].
class Pago {
  final int? id;
  final int grupoId;
  final int deId;
  final int aId;
  final double monto;
  final String fecha;
  Pago({
    this.id,
    required this.grupoId,
    required this.deId,
    required this.aId,
    required this.monto,
    required this.fecha,
  });

  factory Pago.fromMap(Map<String, Object?> m) => Pago(
        id: m['id'] as int,
        grupoId: m['grupo_id'] as int,
        deId: m['de_id'] as int,
        aId: m['a_id'] as int,
        monto: (m['monto'] as num).toDouble(),
        fecha: m['fecha'] as String,
      );
}