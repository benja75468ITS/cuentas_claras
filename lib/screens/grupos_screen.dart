import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/modelos.dart';
import '../widgets/dialogos.dart';

class GruposScreen extends StatefulWidget {
  const GruposScreen({super.key});
  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  List<Grupo> _grupos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await DbHelper.instancia.grupos();
    if (mounted) setState(() { _grupos = r; _cargando = false; });
  }

  Future<void> _nuevo() async {
    final r = await showDialog<List<String>>(
        context: context, builder: (_) => const _NuevoGrupoDialog());
    if (r == null) return;
    final personas = r[1]
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await DbHelper.instancia.crearGrupo(r[0], personas);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas Claras')),
      drawer: Drawer(
        child: ListView(children: [
          const DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Cuentas Claras', style: TextStyle(fontSize: 24)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Mis grupos'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Conversor de divisas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/divisas');
            },
          ),
        ]),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _grupos.isEmpty
              ? const Center(child: Text('Crea tu primer grupo con el botón +'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _grupos.length,
                  itemBuilder: (_, i) {
                    final g = _grupos[i];
                    return Dismissible(
                      key: ValueKey(g.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => confirmar(context, 'Se borrará "${g.nombre}" y todos sus gastos.'),
                      onDismissed: (_) async {
                        await DbHelper.instancia.eliminarGrupo(g.id);
                        _cargar();
                      },
                      child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.group)),
                          title: Text(g.nombre),
                          subtitle: Text('${g.nPersonas} personas · Total ${dinero(g.total)} MXN'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.pushNamed(context, '/grupo', arguments: g);
                            _cargar();
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
    );
  }
}

class _NuevoGrupoDialog extends StatefulWidget {
  const _NuevoGrupoDialog();
  @override
  State<_NuevoGrupoDialog> createState() => _NuevoGrupoDialogState();
}

class _NuevoGrupoDialogState extends State<_NuevoGrupoDialog> {
  final _nombre = TextEditingController();
  final _personas = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _personas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo grupo'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _nombre,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre (ej. Viaje a Mérida)'),
        ),
        TextField(
          controller: _personas,
          decoration: const InputDecoration(
              labelText: 'Personas separadas por coma', hintText: 'Ana, Luis, Marta'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_nombre.text.trim().isEmpty) return;
            Navigator.pop(context, [_nombre.text.trim(), _personas.text]);
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
