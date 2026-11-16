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
  List<Transferencia> _directos = [];
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
        _saldos = s;
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

  Widget _tilePersona(Persona p, Map<int, String> nombres) {
    final v = _saldos[p.id] ?? 0;
    final color = v > 0.005 ? Colors.green : (v < -0.005 ? Colors.red : Colors.grey);
    final debe = _directos.where((t) => t.deId == p.id).toList();
    final leDeben = _directos.where((t) => t.aId == p.id).toList();
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(p.nombre[0].toUpperCase())),
        title: Text(p.nombre),
        subtitle: Text(
          v > 0.005
              ? 'Le deben ${dinero(v)}'
              : (v < -0.005 ? 'Debe ${dinero(-v)}' : 'Está al corriente'),
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        children: [
          if (debe.isEmpty && leDeben.isEmpty)
            const ListTile(dense: true, title: Text('Sin deudas pendientes')),
          for (final t in debe)
            _filaDeuda(Icons.arrow_upward, Colors.red, 'Debe a ${nombres[t.aId]}', t),
          for (final t in leDeben)
            _filaDeuda(Icons.arrow_downward, Colors.green, '${nombres[t.deId]} le debe', t),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final p in _personas) p.id: p.nombre};
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: Text('Saldos · ${widget.grupo.nombre}')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Text('Balance por persona', style: titulo),
              const Text('Toca una persona para ver con quién tiene deudas.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              if (_directos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('¡Todo saldado! 🎉'),
                  ),
                ),
              for (final p in _personas) _tilePersona(p, nombres),
              if (_pagos.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Pagos registrados', style: titulo),
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