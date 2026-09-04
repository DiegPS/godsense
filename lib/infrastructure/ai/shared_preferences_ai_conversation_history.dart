import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ai/ai_conversation_controller.dart';

class SharedPreferencesAiConversationHistory
    implements AiConversationHistoryStore {
  const SharedPreferencesAiConversationHistory();

  static const _key = 'coach.conversation.history.v1';

  @override
  Future<List<AiChatMessage>> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null ? const [] : decodeAiConversationHistory(value);
  }

  @override
  Future<void> save(List<AiChatMessage> messages) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      encodeAiConversationHistory(messages),
    );
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
