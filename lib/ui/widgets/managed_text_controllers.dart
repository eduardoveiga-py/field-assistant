import 'package:flutter/material.dart';

/// Host descartável para [TextEditingController]s em diálogos e bottom sheets (A4).
/// Garante criação em [State.initState] e liberação automática via [State.dispose]
/// somente após o término completo da animação de fechamento da rota.
class ManagedTextControllers extends StatefulWidget {
  final List<String> initialTexts;
  final List<TextEditingController Function(String text)?>? customFactories;
  final Widget Function(
    BuildContext context,
    List<TextEditingController> controllers,
  )
  builder;

  const ManagedTextControllers({
    super.key,
    required this.initialTexts,
    this.customFactories,
    required this.builder,
  });

  @override
  State<ManagedTextControllers> createState() => _ManagedTextControllersState();
}

class _ManagedTextControllersState extends State<ManagedTextControllers> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.initialTexts.length, (i) {
      final text = widget.initialTexts[i];
      final factory =
          widget.customFactories != null && i < widget.customFactories!.length
          ? widget.customFactories![i]
          : null;
      return factory != null
          ? factory(text)
          : TextEditingController(text: text);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controllers);
  }
}
