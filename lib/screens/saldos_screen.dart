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
  Map<int, double> _saldos = {};
  List<Transferencia> _simplificados = [];
  List<Transferencia> _directos = [];
  bool _cargando = true;
  bool _modoDirecto = false;

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
        _saldos = s;
        _simplificados = simplificar(s);
        _directos = deudasDirectas(g, pg);
        _cargando = false;
      });
    }
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  /// Registra que [t.deId] le pagó a [t.aId] (total o parcial).
  Future<void> _marcarPagado(Transferencia t) async {
    final txt = await pedirTexto(context, 'Registrar pago', 'Monto pagado',
        inicial: t.monto.toStringAsFixed(2), numerico: true);
    if (txt == null || txt.isEmpty) return;
    final m = double.tryParse(txt.replaceAll(',', '.'));
    if (m == null || m <= 0) return _aviso('Monto inválido');
    if (m > t.monto + 0.01) return _aviso('El pago no puede ser mayor a la deuda');
    await DbHelper.instancia.registrarPago(Pago(
      grupoId: widget.grupo.id,
      deId: t.deId,
      aId: t.aId,
      monto: m,
      fecha: DateTime.now().toIso8601String().substring(0, 10),
    ));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final p in _personas) p.id: p.nombre};
    final lista = _modoDirecto ? _directos : _simplificados;
    return Scaffold(
      appBar: AppBar(title: Text('Saldos · ${widget.grupo.nombre}')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Text('Balance por persona', style: Theme.of(context).textTheme.titleMedium),
              for (final p in _personas)
                Builder(builder: (_) {
                  final v = _saldos[p.id] ?? 0;
                  final color = v > 0.005 ? Colors.green : (v < -0.005 ? Colors.red : Colors.grey);
                  return ListTile(
                    leading: CircleAvatar(child: Text(p.nombre[0].toUpperCase())),
                    title: Text(p.nombre),
                    subtitle: Text(v > 0.005 ? 'Le deben' : (v < -0.005 ? 'Debe' : 'Está al corriente')),
                    trailing: Text(dinero(v.abs()),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  );
                }),
              const Divider(height: 32),
              Text('¿Quién le debe a quién?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Simplificado'), icon: Icon(Icons.compress)),
                  ButtonSegment(value: true, label: Text('Directas'), icon: Icon(Icons.call_split)),
                ],
                selected: {_modoDirecto},
                onSelectionChanged: (s) => setState(() => _modoDirecto = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _modoDirecto
                    ? 'Deudas entre cada par de personas, según los gastos.'
                    : 'Menor número de pagos para dejar todo saldado.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('¡Todo saldado! 🎉'),
                ),
              for (final t in lista)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${nombres[t.deId]} le debe a ${nombres[t.aId]}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(dinero(t.monto), style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () => _marcarPagado(t),
                          icon: const Icon(Icons.check),
                          label: const Text('Pagado'),
                        ),
                      ]),
                    ]),
                  ),
                ),
              if (_pagos.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Pagos registrados', style: Theme.of(context).textTheme.titleMedium),
                for (final p in _pagos)
                  ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text('${nombres[p.deId]} le pagó a ${nombres[p.aId]}'),
                    subtitle: Text(p.fecha),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(dinero(p.monto), style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        tooltip: 'Deshacer pago',
                        icon: const Icon(Icons.undo),
                        onPressed: () async {
                          if (await confirmar(context, 'Se eliminará este pago y la deuda volverá a aparecer.')) {
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