import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/modelos.dart';
import '../widgets/dialogos.dart';

class GrupoScreen extends StatefulWidget {
  final Grupo grupo;
  const GrupoScreen({super.key, required this.grupo});
  @override
  State<GrupoScreen> createState() => _GrupoScreenState();
}

class _GrupoScreenState extends State<GrupoScreen> {
  List<Persona> _personas = [];
  List<Gasto> _gastos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await DbHelper.instancia.personas(widget.grupo.id);
    final g = await DbHelper.instancia.gastos(widget.grupo.id);
    if (mounted) setState(() { _personas = p; _gastos = g; _cargando = false; });
  }

  Future<void> _agregarPersona() async {
    final n = await pedirTexto(context, 'Nueva persona', 'Nombre');
    if (n == null || n.isEmpty) return;
    await DbHelper.instancia.agregarPersona(widget.grupo.id, n);
    _cargar();
  }

  Future<void> _nuevoGasto() async {
    if (_personas.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agrega al menos 2 personas al grupo')));
      return;
    }
    await Navigator.pushNamed(context, '/gasto', arguments: widget.grupo);
    _cargar();
  }

  /// Muestra quién pagó este gasto y cuánto le debe cada participante.
  void _verDetalle(Gasto g, Map<int, String> nombres) {
    final pagador = nombres[g.pagadorId] ?? '?';
    final parte = g.participantes.isEmpty ? 0.0 : g.monto / g.participantes.length;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.descripcion, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Total ${dinero(g.monto)} MXN'
                  '${g.moneda != 'MXN' ? '  (${g.montoOriginal.toStringAsFixed(2)} ${g.moneda})' : ''}'),
              Text('Pagó: $pagador'),
              Text('Se divide entre ${g.participantes.length} · ${dinero(parte)} c/u'),
              const Divider(height: 24),
              for (final id in g.participantes)
                if (id == g.pagadorId)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(nombres[id] ?? '?'),
                    subtitle: const Text('Pagó el gasto (su parte ya está cubierta)'),
                    trailing: Text(dinero(parte)),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.arrow_forward, color: Colors.red),
                    title: Text('${nombres[id] ?? '?'} le debe a $pagador'),
                    trailing: Text(dinero(parte),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final p in _personas) p.id: p.nombre};
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.nombre),
        actions: [
          IconButton(
              tooltip: 'Agregar persona',
              icon: const Icon(Icons.person_add),
              onPressed: _agregarPersona),
          IconButton(
            tooltip: 'Ver saldos',
            icon: const Icon(Icons.balance),
            onPressed: () => Navigator.pushNamed(context, '/saldos', arguments: widget.grupo),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Wrap(spacing: 8, children: [
                for (final p in _personas)
                  Chip(avatar: const Icon(Icons.person, size: 18), label: Text(p.nombre)),
              ]),
              const SizedBox(height: 12),
              if (_gastos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Aún no hay gastos')),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Toca un gasto para ver quién debe qué',
                      style: TextStyle(fontSize: 12)),
                ),
              for (final g in _gastos)
                Card(
                  child: ListTile(
                    onTap: () => _verDetalle(g, nombres),
                    leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                    title: Text(g.descripcion),
                    subtitle: Text('Pagó ${nombres[g.pagadorId] ?? '?'} · entre ${g.participantes.length}'
                        '${g.moneda != 'MXN' ? '\n${g.montoOriginal.toStringAsFixed(2)} ${g.moneda}' : ''}'),
                    isThreeLine: g.moneda != 'MXN',
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(dinero(g.monto), style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmar(context, 'Se eliminará "${g.descripcion}".')) {
                            await DbHelper.instancia.eliminarGasto(g.id!);
                            _cargar();
                          }
                        },
                      ),
                    ]),
                  ),
                ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoGasto,
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
    );
  }
}