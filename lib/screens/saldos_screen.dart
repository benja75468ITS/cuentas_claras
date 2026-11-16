import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../logic/saldos.dart';
import '../models/modelos.dart';
import '../widgets/dialogos.dart';

class SaldosScreen extends StatefulWidget {
  final Grupo grupo;
  const SaldosScreen({super.key, required this.grupo});
  @override
  State<SaldosScreen> createState() => _SaldosScreenState();
}

class _SaldosScreenState extends State<SaldosScreen> {
  List<Persona> _personas = [];
  List<Pago> _pagos = [];
  List<Transferencia> _directos = [];
  List<Transferencia> _simplificados = [];
  bool _modoSimplificado = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await DbHelper.instancia.personas(widget.grupo.id);
    final g = await DbHelper.instancia.gastos(widget.grupo.id);
    final pg = await DbHelper.instancia.pagos(widget.grupo.id);
    final s = calcularSaldos(p, g, pg);
    if (mounted) {
      setState(() {
        _personas = p;
        _pagos = pg;
        _directos = deudasDirectas(g, pg);
        _simplificados = simplificar(s);
        _cargando = false;
      });
    }
  }

  void _aviso(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  /// Registra que [t.deId] le pagó a [t.aId] (total o parcial).
  Future<void> _marcarPagado(Transferencia t) async {
    final maxDeuda = redondearMoneda(t.monto);
    final txt = await pedirTexto(context, 'Registrar pago', 'Monto pagado',
        inicial: maxDeuda.toStringAsFixed(2), numerico: true);
    if (txt == null || txt.isEmpty) return;
    final m = double.tryParse(txt.trim().replaceAll(',', '.'));
    if (m == null || !m.isFinite || m <= 0) return _aviso('Monto inválido');
    final montoRedondeado = redondearMoneda(m);
    if (montoRedondeado <= 0) return _aviso('Monto inválido');
    if (montoRedondeado > maxDeuda) return _aviso('El pago no puede ser mayor a la deuda');

    await DbHelper.instancia.registrarPago(Pago(
      grupoId: widget.grupo.id,
      deId: t.deId,
      aId: t.aId,
      monto: montoRedondeado,
      fecha: DateTime.now().toIso8601String().substring(0, 10),
    ));
    await _cargar();
    _aviso('Pago registrado');
  }

  Widget _filaDeuda(IconData icono, Color color, String texto, Transferencia t) {
    return ListTile(
      dense: true,
      leading: Icon(icono, color: color),
      title: Text(texto),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(dinero(t.monto), style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          tooltip: 'Marcar pagado',
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () => _marcarPagado(t),
        ),
      ]),
    );
  }

  Widget _subtituloPersona(double totalDebe, double totalLeDeben) {
    final tieneDebe = totalDebe > 0.005;
    final tieneLeDeben = totalLeDeben > 0.005;

    if (tieneDebe && tieneLeDeben) {
      return Text.rich(
        TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: [
            TextSpan(
              text: 'Debe ${dinero(totalDebe)}',
              style: const TextStyle(color: Colors.red),
            ),
            const TextSpan(text: ' · ', style: TextStyle(color: Colors.grey)),
            TextSpan(
              text: 'Le deben ${dinero(totalLeDeben)}',
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
      );
    }
    if (tieneDebe) {
      return Text(
        'Debe ${dinero(totalDebe)}',
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      );
    }
    if (tieneLeDeben) {
      return Text(
        'Le deben ${dinero(totalLeDeben)}',
        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
      );
    }
    return const Text(
      'Está al corriente',
      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
    );
  }

  Widget _tilePersona(
      Persona p, Map<int, String> nombres, List<Transferencia> transferenciasActivas) {
    final debe = transferenciasActivas.where((t) => t.deId == p.id).toList();
    final leDeben = transferenciasActivas.where((t) => t.aId == p.id).toList();
    final totalDebe = debe.fold<double>(0.0, (acc, t) => acc + t.monto);
    final totalLeDeben = leDeben.fold<double>(0.0, (acc, t) => acc + t.monto);
    final inicial = p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?';

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(inicial)),
        title: Text(p.nombre),
        subtitle: _subtituloPersona(totalDebe, totalLeDeben),
        children: [
          if (debe.isEmpty && leDeben.isEmpty)
            const ListTile(dense: true, title: Text('Sin deudas pendientes')),
          for (final t in debe)
            _filaDeuda(Icons.arrow_upward, Colors.red, 'Debe a ${nombres[t.aId] ?? '?'}', t),
          for (final t in leDeben)
            _filaDeuda(
                Icons.arrow_downward, Colors.green, '${nombres[t.deId] ?? '?'} le debe', t),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final p in _personas) p.id: p.nombre};
    final titulo = Theme.of(context).textTheme.titleMedium;
    final transferencias = _modoSimplificado ? _simplificados : _directos;

    return Scaffold(
      appBar: AppBar(title: Text('Saldos · ${widget.grupo.nombre}')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Balance por persona', style: titulo),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Directas')),
                      ButtonSegment(value: true, label: Text('Simplificadas')),
                    ],
                    selected: {_modoSimplificado},
                    onSelectionChanged: (s) => setState(() => _modoSimplificado = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _modoSimplificado
                    ? 'Deudas cruzadas compensadas para minimizar transferencias.'
                    : 'Cada deuda se mantiene pendiente hasta que se registre su pago.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (transferencias.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('¡Todo saldado! 🎉'),
                  ),
                ),
              for (final p in _personas) _tilePersona(p, nombres, transferencias),
              if (_pagos.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Pagos registrados', style: titulo),
                for (final p in _pagos)
                  ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text('${nombres[p.deId] ?? '?'} le pagó a ${nombres[p.aId] ?? '?'}'),
                    subtitle: Text(p.fecha),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(dinero(p.monto), style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        tooltip: 'Deshacer pago',
                        icon: const Icon(Icons.undo),
                        onPressed: () async {
                          if (await confirmar(
                              context, 'Se eliminará este pago y la deuda volverá a aparecer.')) {
                            await DbHelper.instancia.eliminarPago(p.id!);
                            _cargar();
                          }
                        },
                      ),
                    ]),
                  ),
              ],
            ]),
    );
  }
}
