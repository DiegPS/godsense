import 'package:flutter/material.dart';

Future<bool> confirmHudReset(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restablecer el HUD?'),
        content: const Text(
          'Se restaurarán las posiciones, tamaños y paneles colapsados. La calibración del minimapa se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    ) ??
    false;
