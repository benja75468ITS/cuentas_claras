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
  List<Transferencia> _pagos = [];
  bool _cargando = true;

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
        _pagos = simplificar(s);
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final p in _personas) p.id: p.nombre};
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
              Text('Cómo saldar las cuentas', style: Theme.of(context).textTheme.titleMedium),
              if (_pagos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('¡Todo saldado! 🎉'),
                ),
              for (final t in _pagos)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.arrow_forward),
                    title: Text('${nombres[t.deId]} le paga a ${nombres[t.aId]}'),
                    trailing: Text(dinero(t.monto),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
    );
  }
}
