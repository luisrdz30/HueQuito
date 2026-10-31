import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Flecha de regresar segura: vuelve a la pantalla anterior si existe; si se llegó
/// con `go` (sin historial), va a [fallback] en lugar de quedarse sin hacer nada.
void goBack(BuildContext context, {required String fallback}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
