import 'package:flutter/material.dart';

/// Passthrough for platforms without window chrome (web). Exists so the
/// conditional import in main.dart resolves on every platform.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
