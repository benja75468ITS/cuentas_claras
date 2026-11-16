import '../models/modelos.dart';

class Transferencia {
  final int deId;
  final int aId;
  final double monto;
  Transferencia(this.deId, this.aId, this.monto);
}

int _aCentavos(double monto) => (monto * 100).round();
double _deCentavos(int centavos) => centavos / 100.0;

/// Reparte exactamente [totalCentavos] entre los participantes únicos de [g]
/// asignando los centavos sobrantes primero a quienes no pagaron (en orden
/// determinista por ID), garantizando que la suma de partes == totalCentavos.
Map<int, int> _repartoEnCentavos(Gasto g) {
  final unicos = g.participantes.toSet().toList()..sort();
  if (unicos.isEmpty) return const {};

  final total = _aCentavos(g.monto);
  final n = unicos.length;
  final base = total ~/ n;
  var residuo = total % n;

  final orden = [
    for (final id in unicos)
      if (id != g.pagadorId) id,
    if (unicos.contains(g.pagadorId)) g.pagadorId,
  ];

  final partes = <int, int>{};
  for (final id in orden) {
    final extra = residuo > 0 ? 1 : 0;
    if (residuo > 0) residuo--;
    partes[id] = base + extra;
  }
  return partes;
}

/// Devuelve cuánto le corresponde pagar a cada participante del gasto [g] (en pesos exactos).
Map<int, double> repartirGasto(Gasto g) {
  final centavos = _repartoEnCentavos(g);
  return {
    for (final e in centavos.entries) e.key: _deCentavos(e.value),
  };
}

/// Saldo neto por persona: positivo = le deben, negativo = debe.
/// Un pago de X a Y sube el saldo de X y baja el de Y.
Map<int, double> calcularSaldos(List<Persona> personas, List<Gasto> gastos,
    [List<Pago> pagos = const []]) {
  final centavos = {for (final p in personas) p.id: 0};

  for (final g in gastos) {
    final partes = _repartoEnCentavos(g);
    if (partes.isEmpty) continue;
    final total = partes.values.fold<int>(0, (a, b) => a + b);
    centavos[g.pagadorId] = (centavos[g.pagadorId] ?? 0) + total;
    partes.forEach((id, parte) {
      centavos[id] = (centavos[id] ?? 0) - parte;
    });
  }

  for (final p in pagos) {
    final m = _aCentavos(p.monto);
    centavos[p.deId] = (centavos[p.deId] ?? 0) + m;
    centavos[p.aId] = (centavos[p.aId] ?? 0) - m;
  }

  return {
    for (final e in centavos.entries) e.key: _deCentavos(e.value),
  };
}

class _Saldo {
  final int id;
  int centavos;
  _Saldo(this.id, this.centavos);
}

/// Minimiza el número de pagos: el que más debe le paga al que más se le debe.
List<Transferencia> simplificar(Map<int, double> saldos) {
  final deudores = <_Saldo>[];
  final acreedores = <_Saldo>[];
  saldos.forEach((id, v) {
    final c = _aCentavos(v);
    if (c < 0) deudores.add(_Saldo(id, -c));
    if (c > 0) acreedores.add(_Saldo(id, c));
  });
  deudores.sort((a, b) => b.centavos.compareTo(a.centavos));
  acreedores.sort((a, b) => b.centavos.compareTo(a.centavos));

  final pagos = <Transferencia>[];
  var i = 0, j = 0;
  while (i < deudores.length && j < acreedores.length) {
    final monto = deudores[i].centavos < acreedores[j].centavos
        ? deudores[i].centavos
        : acreedores[j].centavos;
    if (monto > 0) {
      pagos.add(Transferencia(deudores[i].id, acreedores[j].id, _deCentavos(monto)));
    }
    deudores[i].centavos -= monto;
    acreedores[j].centavos -= monto;
    if (deudores[i].centavos == 0) i++;
    if (acreedores[j].centavos == 0) j++;
  }
  return pagos;
}

/// Deudas directas pendientes sin compensar entre pares.
/// Si A le debe a B por un gasto y B le debe a A por otro gasto, ambas deudas
/// permanecen activas por separado. Un pago superior a una deuda se aplica
/// como crédito a favor de quien lo recibió de más.
List<Transferencia> deudasDirectas(List<Gasto> gastos, [List<Pago> pagos = const []]) {
  final d = <(int, int), int>{};
  for (final g in gastos) {
    final partes = _repartoEnCentavos(g);
    partes.forEach((id, parte) {
      if (id == g.pagadorId || parte == 0) return;
      final k = (id, g.pagadorId);
      d[k] = (d[k] ?? 0) + parte;
    });
  }
  for (final p in pagos) {
    final k = (p.deId, p.aId);
    d[k] = (d[k] ?? 0) - _aCentavos(p.monto);
  }

  final res = <Transferencia>[];
  final paresProcesados = <(int, int)>{};
  for (final k in d.keys) {
    final menor = k.$1 < k.$2 ? k.$1 : k.$2;
    final mayor = k.$1 < k.$2 ? k.$2 : k.$1;
    if (!paresProcesados.add((menor, mayor))) continue;

    final menorAMayor = d[(menor, mayor)] ?? 0;
    final mayorAMenor = d[(mayor, menor)] ?? 0;
    if (menorAMayor < 0 || mayorAMenor < 0) {
      final neto = menorAMayor - mayorAMenor;
      if (neto > 0) {
        res.add(Transferencia(menor, mayor, _deCentavos(neto)));
      } else if (neto < 0) {
        res.add(Transferencia(mayor, menor, _deCentavos(-neto)));
      }
      continue;
    }

    if (menorAMayor > 0) {
      res.add(Transferencia(menor, mayor, _deCentavos(menorAMayor)));
    }
    if (mayorAMenor > 0) {
      res.add(Transferencia(mayor, menor, _deCentavos(mayorAMenor)));
    }
  }
  return res;
}
