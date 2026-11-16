import 'package:flutter/material.dart';

Future<bool> confirmar(BuildContext context, String mensaje) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('¿Seguro?'),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> pedirTexto(
  BuildContext context,
  String titulo,
  String etiqueta, {
  String inicial = '',
  bool numerico = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextoDialog(
        titulo: titulo, etiqueta: etiqueta, inicial: inicial, numerico: numerico),
  );
}

class _TextoDialog extends StatefulWidget {
  final String titulo;
  final String etiqueta;
  final String inicial;
  final bool numerico;
  const _TextoDialog({
    required this.titulo,
    required this.etiqueta,
    required this.inicial,
    required this.numerico,
  });
  @override
  State<_TextoDialog> createState() => _TextoDialogState();
}

class _TextoDialogState extends State<_TextoDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: widget.numerico
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: widget.etiqueta),
        onSubmitted: (_) => Navigator.pop(context, _c.text.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('Aceptar')),
      ],
    );
  }
}
