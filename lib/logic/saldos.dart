import '../models/modelos.dart';

class Transferencia {
  final int deId;
  final int aId;
  final double monto;
  Transferencia(this.deId, this.aId, this.monto);
}

/// Saldo neto por persona: positivo = le deben, negativo = debe.
/// Un pago de X a Y sube el saldo de X y baja el de Y.
Map<int, double> calcularSaldos(List<Persona> personas, List<Gasto> gastos,
    [List<Pago> pagos = const []]) {
  final s = {for (final p in personas) p.id: 0.0};
  for (final g in gastos) {
    if (g.participantes.isEmpty) continue;
    final parte = g.monto / g.participantes.length;
    s[g.pagadorId] = (s[g.pagadorId] ?? 0) + g.monto;
    for (final id in g.participantes) {
      s[id] = (s[id] ?? 0) - parte;
    }
  }
  for (final p in pagos) {
    s[p.deId] = (s[p.deId] ?? 0) + p.monto;
    s[p.aId] = (s[p.aId] ?? 0) - p.monto;
  }
  return s;
}

class _Saldo {
  final int id;
  double v;
  _Saldo(this.id, this.v);
}

/// Minimiza el número de pagos: el que más debe le paga al que más se le debe.
List<Transferencia> simplificar(Map<int, double> saldos) {
  final deudores = <_Saldo>[];
  final acreedores = <_Saldo>[];
  saldos.forEach((id, v) {
    if (v < -0.005) deudores.add(_Saldo(id, -v));
    if (v > 0.005) acreedores.add(_Saldo(id, v));
  });
  deudores.sort((a, b) => b.v.compareTo(a.v));
  acreedores.sort((a, b) => b.v.compareTo(a.v));

  final pagos = <Transferencia>[];
  var i = 0, j = 0;
  while (i < deudores.length && j < acreedores.length) {
    final monto = deudores[i].v < acreedores[j].v ? deudores[i].v : acreedores[j].v;
    pagos.add(Transferencia(deudores[i].id, acreedores[j].id, monto));
    deudores[i].v -= monto;
    acreedores[j].v -= monto;
    if (deudores[i].v < 0.005) i++;
    if (acreedores[j].v < 0.005) j++;
  }
  return pagos;
}

/// Deudas directas entre pares de personas (sin simplificar).
/// Para cada par se restan las deudas en ambos sentidos y los pagos hechos.
List<Transferencia> deudasDirectas(List<Gasto> gastos, [List<Pago> pagos = const []]) {
  final d = <String, double>{};
  for (final g in gastos) {
    if (g.participantes.isEmpty) continue;
    final parte = g.monto / g.participantes.length;
    for (final id in g.participantes) {
      if (id == g.pagadorId) continue;
      final k = '$id>${g.pagadorId}';
      d[k] = (d[k] ?? 0) + parte;
    }
  }
  for (final p in pagos) {
    final k = '${p.deId}>${p.aId}';
    d[k] = (d[k] ?? 0) - p.monto;
  }
  final res = <Transferencia>[];
  final vistos = <String>{};
  for (final k in d.keys.toList()) {
    final p = k.split('>');
    final a = int.parse(p[0]);
    final b = int.parse(p[1]);
    final canon = a < b ? '$a|$b' : '$b|$a';
    if (!vistos.add(canon)) continue;
    final neto = (d['$a>$b'] ?? 0) - (d['$b>$a'] ?? 0);
    if (neto > 0.005) {
      res.add(Transferencia(a, b, neto));
    } else if (neto < -0.005) {
      res.add(Transferencia(b, a, -neto));
    }
  }
  return res;
}