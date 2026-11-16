import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../logic/saldos.dart';
import '../models/modelos.dart';

class SaldosScreen extends StatefulWidget {
  final Grupo grupo;
  const SaldosScreen({super.key, required this.grupo});
  @override
  State<SaldosScreen> createState() => _SaldosScreenState();
}

class _SaldosScreenState extends State<SaldosScreen> {
  List<Persona> _personas = [];
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
    final s = calcularSaldos(p, g);
    if (mounted) {
      setState(() {
        _personas = p;
        _saldos = s;
        _simplificados = simplificar(s);
        _directos = deudasDirectas(g);
        _cargando = false;
      });
    }
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
                  child: ListTile(
                    leading: const Icon(Icons.arrow_forward),
                    title: Text('${nombres[t.deId]} le debe a ${nombres[t.aId]}'),
                    trailing: Text(dinero(t.monto),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
    );
  }
}