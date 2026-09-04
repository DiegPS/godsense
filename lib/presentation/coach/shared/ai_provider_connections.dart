import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/dependencies.dart';
import '../../../domain/ai/ai_runtime_api_models.dart';
import 'ai_auth_inputs_dialog.dart';

class AiProviderConnections extends ConsumerWidget {
  const AiProviderConnections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supervisor = ref.watch(aiRuntimeSupervisorProvider);
    final runtime =
        ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
    if (!runtime.isReady) {
      return const Text('Inicia un motor para conectar cuentas de modelos.');
    }
    final state = ref.watch(aiProviderConnectionProvider);
    final controller = ref.read(aiProviderConnectionProvider.notifier);
    final connected = state.connected;
    final grouped = <String, List<AiAuthMethod>>{};
    for (final method in state.methods) {
      grouped.putIfAbsent(method.providerId, () => []).add(method);
    }

    Future<void> refreshModels() async {
      if (!context.mounted) return;
      await ref.read(aiModelSelectionProvider.notifier).refresh();
    }

    Future<void> apiKey(AiAuthMethod method) async {
      final input = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Conectar ${method.providerId}'),
          content: TextField(
            controller: input,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API key'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text),
              child: const Text('Conectar'),
            ),
          ],
        ),
      );
      input.dispose();
      if (!context.mounted || value?.trim().isEmpty != false) return;
      await controller.connectApiKey(method.providerId, value!);
      await refreshModels();
    }

    Future<void> oauth(AiAuthMethod method) async {
      final inputs = method.prompts.isEmpty
          ? <String, String>{}
          : await showDialog<Map<String, String>>(
              context: context,
              builder: (_) => AiAuthInputsDialog(method: method),
            );
      if (!context.mounted || inputs == null) return;
      await controller.beginOAuth(method, inputs: inputs);
    }

    Future<void> openAuthorization() async {
      final url = state.authorizationUrl;
      if (url == null || !['http', 'https'].contains(url.scheme)) return;
      try {
        await Process.run('rundll32.exe', [
          'url.dll,FileProtocolHandler',
          url.toString(),
        ], runInShell: false);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo abrir el navegador. Usa Copiar enlace de acceso.',
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loading || state.operatingProvider != null)
          const LinearProgressIndicator(),
        if (state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!state.loading && grouped.isEmpty)
          const Text('El motor no publicó métodos de conexión.'),
        for (final entry in grouped.entries)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: Text(
                connected.contains(entry.key)
                    ? 'Cuenta conectada'
                    : entry.value.map((method) => method.label).join(' · '),
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (connected.contains(entry.key))
                    TextButton(
                      onPressed: state.operatingProvider == null
                          ? () async {
                              await controller.disconnect(entry.key);
                              await refreshModels();
                            }
                          : null,
                      child: const Text('Desconectar'),
                    )
                  else
                    for (final method in entry.value)
                      OutlinedButton(
                        onPressed: state.operatingProvider == null
                            ? () => method.type == 'api'
                                  ? apiKey(method)
                                  : oauth(method)
                            : null,
                        child: Text(
                          method.type == 'api' ? 'API key' : 'Entrar',
                        ),
                      ),
                ],
              ),
            ),
          ),
        if (state.instructions != null) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(state.instructions!)),
          if (state.authorizationUrl != null)
            TextButton.icon(
              onPressed: openAuthorization,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Abrir navegador para iniciar sesión'),
            ),
          if (state.authorizationUrl != null)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: state.authorizationUrl.toString()),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar enlace de acceso'),
            ),
          FilledButton(
            onPressed: state.operatingProvider != null
                ? null
                : () async {
                    String? code;
                    if (state.authorizationMethod == 'code') {
                      final values = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (_) => const AiAuthInputsDialog(
                          method: AiAuthMethod(
                            providerId: '',
                            type: 'oauth',
                            label: 'Código de autorización',
                            index: 0,
                            prompts: [
                              AiAuthPrompt(
                                key: 'code',
                                type: 'text',
                                label: 'Pega el código de autorización',
                              ),
                            ],
                          ),
                        ),
                      );
                      if (!context.mounted || values == null) return;
                      code = values['code'];
                    }
                    await controller.completeOAuth(code: code);
                    await refreshModels();
                  },
            child: Text(
              state.authorizationMethod == 'code'
                  ? 'Introducir código y conectar'
                  : 'Ya terminé: verificar conexión',
            ),
          ),
        ],
      ],
    );
  }
}
