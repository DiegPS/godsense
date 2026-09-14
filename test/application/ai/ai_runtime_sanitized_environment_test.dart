import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_paths.dart';
import 'package:godsense/infrastructure/ai/local_ai_runtime_process_service.dart';

void main() {
  test(
    'buildSanitizedEnvironment filters sensitive parent environment variables',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'godsense-env-test-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final storage = AiRuntimeStorage(
        sharedStoreRoot: Directory('${tempDir.path}\\shared'),
        applicationDataRoot: Directory('${tempDir.path}\\private'),
        applicationId: 'godsense',
      );
      final dirtyParentEnv = {
        'SYSTEMROOT': 'C:\\Windows',
        'PATH': 'C:\\Windows\\System32;C:\\Program Files',
        'COMSPEC': 'C:\\Windows\\system32\\cmd.exe',
        'OPENAI_API_KEY': 'sk-proj-super-secret-key',
        'ANTHROPIC_API_KEY': 'sk-ant-secret',
        'GEMINI_API_KEY': 'AIzaSySecret',
        'GITHUB_TOKEN': 'ghp_secret_token',
        'AWS_SECRET_ACCESS_KEY': 'awsSecret',
        'KILO_API_KEY': 'kilo-secret',
        'RANDOM_CUSTOM_VAR': 'custom_value',
      };

      final sanitized = LocalAiRuntimeProcessService.buildSanitizedEnvironment(
        kind: AiRuntimeKind.kilo,
        storage: storage,
        username: 'kilo',
        password: 'test-password-123',
        parentEnvironment: dirtyParentEnv,
      );

      // Whitelisted system variables are kept
      expect(sanitized['SYSTEMROOT'], 'C:\\Windows');
      expect(sanitized['PATH'], contains('System32'));
      expect(sanitized['COMSPEC'], 'C:\\Windows\\system32\\cmd.exe');

      // Sensitive parent variables are strictly removed
      expect(sanitized.containsKey('OPENAI_API_KEY'), isFalse);
      expect(sanitized.containsKey('ANTHROPIC_API_KEY'), isFalse);
      expect(sanitized.containsKey('GEMINI_API_KEY'), isFalse);
      expect(sanitized.containsKey('GITHUB_TOKEN'), isFalse);
      expect(sanitized.containsKey('AWS_SECRET_ACCESS_KEY'), isFalse);
      expect(sanitized.containsKey('KILO_API_KEY'), isFalse);
      expect(sanitized.containsKey('RANDOM_CUSTOM_VAR'), isFalse);

      // Tool blocking and isolation variables are injected
      expect(sanitized['KILO_DISABLE_TOOLS'], '1');
      expect(sanitized['KILO_DISABLE_EXTERNAL_SKILLS'], '1');
      expect(sanitized['KILO_SERVER_PASSWORD'], 'test-password-123');
      expect(sanitized['KILO_SERVER_USERNAME'], 'kilo');
      expect(sanitized['KILO_CLIENT'], 'godsense');
      expect(sanitized['KILO_PURE'], '1');
    },
  );

  test('AiPrompt payload strictly enforces tools: {"*": false} to forbid all tool execution in Kilo', () {
    const prompt = AiPrompt(
      providerId: 'kilo',
      modelId: 'kilo-auto/free',
      system: 'No uses herramientas.',
      text: '¿Cómo juego?',
    );

    final json = prompt.toJson();
    final tools = json['tools'];

    expect(tools, isA<Map>());
    final toolsMap = tools as Map;
    expect(
      toolsMap['*'],
      isFalse,
      reason: 'Kilo prompt.ts requires {"*": false} to deny tool permissions.',
    );
  });
}
