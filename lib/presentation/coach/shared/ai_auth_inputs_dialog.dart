import 'package:flutter/material.dart';

import '../../../domain/ai/ai_runtime_api_models.dart';

class AiAuthInputsDialog extends StatefulWidget {
  const AiAuthInputsDialog({super.key, required this.method});
  final AiAuthMethod method;
  @override
  State<AiAuthInputsDialog> createState() => _AiAuthInputsDialogState();
}

class _AiAuthInputsDialogState extends State<AiAuthInputsDialog> {
  final _form = GlobalKey<FormState>();
  final _inputs = <String, String>{};

  @override
  void initState() {
    super.initState();
    for (final prompt in widget.method.prompts) {
      if (prompt.type == 'select' && prompt.options.isNotEmpty) {
        _inputs[prompt.key] = prompt.options.keys.first;
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.method.label),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final prompt in widget.method.prompts)
                if (prompt.visible(_inputs))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: prompt.type == 'select'
                        ? DropdownButtonFormField<String>(
                            key: ValueKey(prompt.key),
                            initialValue: _inputs[prompt.key],
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: prompt.label,
                            ),
                            items: prompt.options.entries
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option.key,
                                    child: Text(option.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              if (value != null) _inputs[prompt.key] = value;
                            }),
                            validator: (value) =>
                                value == null ? 'Selecciona una opción.' : null,
                          )
                        : TextFormField(
                            key: ValueKey(prompt.key),
                            initialValue: _inputs[prompt.key],
                            decoration: InputDecoration(
                              labelText: prompt.label,
                              hintText: prompt.placeholder,
                            ),
                            autocorrect: false,
                            enableSuggestions: false,
                            onChanged: (value) =>
                                setState(() => _inputs[prompt.key] = value),
                            validator: (value) =>
                                prompt.key == 'code' &&
                                    (value?.trim().isEmpty ?? true)
                                ? 'Introduce el código.'
                                : null,
                          ),
                  ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, {
              for (final prompt in widget.method.prompts)
                if (prompt.visible(_inputs))
                  prompt.key: _inputs[prompt.key] ?? '',
            });
          }
        },
        child: const Text('Continuar'),
      ),
    ],
  );
}
