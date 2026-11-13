import 'package:flutter/material.dart';

/// Host descartável para [TextEditingController]s em diálogos e bottom sheets (A4).
/// Garante criação em [State.initState] e liberação automática via [State.dispose]
/// somente após o término completo da animação de fechamento da rota.
class ManagedTextControllers extends StatefulWidget {
  final List<String> initialTexts;
  final Widget Function(
    BuildContext context,
    List<TextEditingController> controllers,
  ) builder;

  const ManagedTextControllers({
    super.key,
    required this.initialTexts,
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
    _controllers = widget.initialTexts
        .map((text) => TextEditingController(text: text))
        .toList();
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
