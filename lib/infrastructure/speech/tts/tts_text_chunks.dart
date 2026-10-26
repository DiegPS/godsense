Iterable<String> ttsTextChunks(String text, {int maxRunes = 160}) sync* {
  if (maxRunes < 1) throw ArgumentError.value(maxRunes, 'maxRunes');
  final runes = text.replaceAll(RegExp(r'\s+'), ' ').trim().runes.toList();
  var start = 0;
  while (start < runes.length) {
    var end = (start + maxRunes).clamp(0, runes.length);
    if (end < runes.length) {
      var space = -1;
      for (var index = end - 1; index > start; index--) {
        if (runes[index] != 32) continue;
        space = space < 0 ? index : space;
        if (const [46, 33, 63, 59].contains(runes[index - 1])) {
          end = index;
          break;
        }
      }
      if (end == start + maxRunes && space > start) end = space;
    }
    final chunk = String.fromCharCodes(runes.sublist(start, end)).trim();
    if (chunk.isNotEmpty) yield chunk;
    start = end;
    while (start < runes.length && runes[start] == 32) {
      start++;
    }
  }
}
