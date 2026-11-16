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
    final r = await showDialog<({String nombre, List<String> personas})>(
        context: context, builder: (_) => const _NuevoGrupoDialog());
    if (r == null) return;
    await DbHelper.instancia.crearGrupo(r.nombre, r.personas);
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
                      confirmDismiss: (_) =>
                          confirmar(context, 'Se borrará "${g.nombre}" y todos sus gastos.'),
                      onDismissed: (_) async {
                        setState(() => _grupos.removeWhere((item) => item.id == g.id));
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
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _personas.dispose();
    super.dispose();
  }

  void _crear() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe un nombre para el grupo');
      return;
    }

    final vistos = <String>{};
    final listaPersonas = <String>[];
    for (final raw in _personas.text.split(',')) {
      final p = raw.trim();
      if (p.isEmpty) continue;
      if (!vistos.add(p.toLowerCase())) {
        setState(() => _error = 'Nombre duplicado: "$p"');
        return;
      }
      listaPersonas.add(p);
    }

    if (listaPersonas.length < 2) {
      setState(() => _error = 'Ingresa al menos 2 personas separadas por coma');
      return;
    }

    Navigator.pop(context, (nombre: nombre, personas: listaPersonas));
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
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        TextField(
          controller: _personas,
          decoration: const InputDecoration(
              labelText: 'Personas separadas por coma', hintText: 'Ana, Luis, Marta'),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _crear,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
