import 'package:flutter/material.dart';
import '../services/divisas_service.dart';

class DivisasScreen extends StatefulWidget {
  const DivisasScreen({super.key});
  @override
  State<DivisasScreen> createState() => _DivisasScreenState();
}

class _DivisasScreenState extends State<DivisasScreen> {
  final _monto = TextEditingController(text: '100');
  String _de = 'USD';
  String _a = 'MXN';
  String? _resultado;
  String? _error;
  bool _cargando = false;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  Future<void> _convertir() async {
    final m = double.tryParse(_monto.text.trim().replaceAll(',', '.'));
    if (m == null || m <= 0) {
      setState(() {
        _error = 'Ingresa un monto válido mayor a 0';
        _resultado = null;
      });
      return;
    }
    setState(() {
      _cargando = true;
      _resultado = null;
      _error = null;
    });
    try {
      final t = await DivisasService.tasa(_de, _a);
      if (!mounted) return;
      setState(() => _resultado =
          '${m.toStringAsFixed(2)} $_de = ${(m * t).toStringAsFixed(2)} $_a\n(1 $_de = ${t.toStringAsFixed(4)} $_a)');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo consultar el tipo de cambio.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _selector(String valor, ValueChanged<String> cambio) => DropdownButton<String>(
        value: valor,
        items: [
          for (final m in DivisasService.monedas) DropdownMenuItem(value: m, child: Text(m))
        ],
        onChanged: (v) {
          if (v == null) return;
          cambio(v);
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversor de divisas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _selector(_de, (v) => setState(() {
                  _de = v;
                  _resultado = null;
                })),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => setState(() {
                final t = _de;
                _de = _a;
                _a = t;
                _resultado = null;
              }),
            ),
            _selector(_a, (v) => setState(() {
                  _a = v;
                  _resultado = null;
                })),
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: _cargando ? null : _convertir, child: const Text('Convertir')),
          const SizedBox(height: 24),
          if (_cargando) const CircularProgressIndicator(),
          if (_resultado != null)
            Text(_resultado!,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        ]),
      ),
    );
  }
}
