import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/dependencies.dart';
import '../../../domain/ai/ai_runtime_api_models.dart';

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
    final connected = ref
        .watch(aiModelSelectionProvider)
        .providers
        .map((provider) => provider.id)
        .toSet();
    final grouped = <String, List<AiAuthMethod>>{};
    for (final method in state.methods) {
      grouped.putIfAbsent(method.providerId, () => []).add(method);
    }

    Future<void> refreshModels() async {
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
      if (value?.trim().isEmpty != false) return;
      await controller.connectApiKey(method.providerId, value!);
      await refreshModels();
    }

    Future<void> oauth(AiAuthMethod method) async {
      await controller.beginOAuth(method);
      final authorization = ref.read(aiProviderConnectionProvider);
      final url = authorization.authorizationUrl;
      if (url != null && authorization.instructions == null) {
        await Process.start('rundll32.exe', [
          'url.dll,FileProtocolHandler',
          url.toString(),
        ], runInShell: false);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loading) const LinearProgressIndicator(),
        if (state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!state.loading && grouped.isEmpty)
          const Text('El motor no publicó métodos de conexión.'),
        for (final entry in grouped.entries)
          ListTile(
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
                      child: Text(method.type == 'api' ? 'API key' : 'Entrar'),
                    ),
              ],
            ),
          ),
        if (state.instructions != null) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(state.instructions!)),
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
            onPressed: () async {
              await Future<void>.delayed(const Duration(milliseconds: 400));
              await controller.refresh();
              await refreshModels();
            },
            child: const Text('Ya terminé de iniciar sesión'),
          ),
        ],
      ],
    );
  }
}
