import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/global_push_to_talk_hotkey.dart';
import 'package:win32/win32.dart';

void main() {
  test('maps every supported PTT key to its Win32 virtual key', () {
    expect(GlobalPushToTalkHotkey.virtualKeyFor('delete'), VK_DELETE);
    expect(GlobalPushToTalkHotkey.virtualKeyFor('space'), VK_SPACE);
    expect(GlobalPushToTalkHotkey.virtualKeyFor('f8'), VK_F8);
    expect(GlobalPushToTalkHotkey.virtualKeyFor('f12'), VK_F12);
    expect(GlobalPushToTalkHotkey.virtualKeyFor('unknown'), VK_DELETE);
  });
}
