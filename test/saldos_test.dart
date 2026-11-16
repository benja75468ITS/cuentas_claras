import 'package:flutter_test/flutter_test.dart';
import 'package:cuentas_claras/logic/saldos.dart';
import 'package:cuentas_claras/models/modelos.dart';

void main() {
  final personas = [
    Persona(id: 1, grupoId: 1, nombre: 'Ana'),
    Persona(id: 2, grupoId: 1, nombre: 'Luis'),
    Persona(id: 3, grupoId: 1, nombre: 'Marta'),
  ];

  test('reparte los centavos sobrantes de forma determinista', () {
    final partes = repartirGasto(Gasto(
      grupoId: 1,
      descripcion: 'Cena',
      monto: 10.01,
      montoOriginal: 10.01,
      moneda: 'MXN',
      pagadorId: 1,
      participantes: [3, 1, 2, 2],
    ));

    expect(partes, {2: 3.34, 3: 3.34, 1: 3.33});
    expect(partes.values.fold<double>(0, (a, b) => a + b), 10.01);
  });

  test('calcula saldos y descuenta pagos en centavos', () {
    final gasto = Gasto(
      grupoId: 1,
      descripcion: 'Cena',
      monto: 100,
      montoOriginal: 100,
      moneda: 'MXN',
      pagadorId: 1,
      participantes: [1, 2, 3],
    );
    final pago = Pago(
      grupoId: 1,
      deId: 2,
      aId: 1,
      monto: 10,
      fecha: '2026-01-01',
    );

    expect(
      calcularSaldos(personas, [gasto], [pago]),
      {1: 56.67, 2: -23.34, 3: -33.33},
    );
  });

  test('aplica pagos a deudas directas sin generar saldo negativo', () {
    final gasto = Gasto(
      grupoId: 1,
      descripcion: 'Taxi',
      monto: 40,
      montoOriginal: 40,
      moneda: 'MXN',
      pagadorId: 1,
      participantes: [1, 2],
    );
    final pago = Pago(
      grupoId: 1,
      deId: 2,
      aId: 1,
      monto: 5,
      fecha: '2026-01-01',
    );

    final deudas = deudasDirectas([gasto], [pago]);
    expect(deudas, hasLength(1));
    expect(deudas.single.deId, 2);
    expect(deudas.single.aId, 1);
    expect(deudas.single.monto, 15);
  });

  test('simplifica saldos con transferencias que conservan el balance', () {
    final transferencias = simplificar({1: 10.01, 2: -3.34, 3: -6.67});

    expect(transferencias, hasLength(2));
    expect(
      transferencias.fold<double>(0, (total, t) => total + t.monto),
      10.01,
    );
    expect(transferencias.every((t) => t.monto > 0), isTrue);
  });
}
