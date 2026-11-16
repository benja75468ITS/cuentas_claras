import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/modelos.dart';
import '../services/divisas_service.dart';

class GastoScreen extends StatefulWidget {
  final Grupo grupo;
  const GastoScreen({super.key, required this.grupo});
  @override
  State<GastoScreen> createState() => _GastoScreenState();
}

class _GastoScreenState extends State<GastoScreen> {
  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _monto = TextEditingController();
  String _moneda = 'MXN';
  int? _pagador;
  final Set<int> _sel = {};
  List<Persona> _personas = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    DbHelper.instancia.personas(widget.grupo.id).then((p) {
      if (!mounted) return;
      setState(() {
        _personas = p;
        _pagador = p.isNotEmpty ? p.first.id : null;
        _sel.addAll(p.map((e) => e.id));
        _cargando = false;
      });
    });
  }

  @override
  void dispose() {
    _desc.dispose();
    _monto.dispose();
    super.dispose();
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_pagador == null) return _aviso('Selecciona quién pagó');
    if (_sel.isEmpty) return _aviso('Elige al menos un participante');
    if (_sel.length == 1 && _sel.contains(_pagador)) {
      return _aviso('Selecciona al menos otra persona además de quien pagó');
    }

    final original = double.parse(_monto.text.trim().replaceAll(',', '.'));

    setState(() => _guardando = true);
    double tasa;
    try {
      tasa = await DivisasService.tasa(_moneda, 'MXN');
    } catch (e) {
      debugPrint('No se pudo consultar el tipo de cambio: $e');
      if (mounted) {
        setState(() => _guardando = false);
        _aviso('No se pudo obtener el tipo de cambio. Revisa tu conexión o usa MXN.');
      }
      return;
    }

    final montoMxn = redondearMoneda(original * tasa);
    if (!montoMxn.isFinite || montoMxn <= 0) {
      if (mounted) {
        setState(() => _guardando = false);
        _aviso('El monto convertido es demasiado pequeño.');
      }
      return;
    }

    try {
      await DbHelper.instancia.crearGasto(Gasto(
        grupoId: widget.grupo.id,
        descripcion: _desc.text.trim(),
        monto: montoMxn,
        montoOriginal: redondearMoneda(original),
        moneda: _moneda,
        pagadorId: _pagador!,
        participantes: _sel.toList(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('No se pudo guardar el gasto: $e');
      if (mounted) {
        setState(() => _guardando = false);
        _aviso('No se pudo guardar el gasto.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _personas.length < 2
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Se necesitan al menos 2 personas en el grupo para dividir gastos.'),
                  ),
                )
              : Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    TextFormField(
                      controller: _desc,
                      decoration: const InputDecoration(labelText: 'Descripción (ej. Cena)'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Escribe una descripción' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _monto,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Monto'),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                            return (n == null || !n.isFinite || n <= 0)
                                ? 'Monto inválido'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _moneda,
                        items: [
                          for (final m in DivisasService.monedas)
                            DropdownMenuItem(value: m, child: Text(m))
                        ],
                        onChanged: (v) => setState(() => _moneda = v!),
                      ),
                    ]),
                    if (_moneda != 'MXN')
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Se convertirá a MXN con el tipo de cambio actual al guardar.',
                            style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _pagador,
                      decoration: const InputDecoration(labelText: '¿Quién pagó?'),
                      items: [
                        for (final p in _personas)
                          DropdownMenuItem(value: p.id, child: Text(p.nombre))
                      ],
                      onChanged: (v) => setState(() => _pagador = v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Dividir entre:'),
                    Wrap(spacing: 8, children: [
                      for (final p in _personas)
                        FilterChip(
                          label: Text(p.nombre),
                          selected: _sel.contains(p.id),
                          onSelected: (s) => setState(() => s ? _sel.add(p.id) : _sel.remove(p.id)),
                        ),
                    ]),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar gasto'),
                    ),
                  ]),
                ),
    );
  }
}
