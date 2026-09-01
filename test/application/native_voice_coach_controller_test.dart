import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_voice_coach_controller.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';

void main() {
  late StreamController<String> questions;
  late List<String> spoken;
  late NativeVoiceCoachController controller;

  setUp(() {
    questions = StreamController<String>.broadcast();
    spoken = [];
    controller = NativeVoiceCoachController(
      questions: questions.stream,
      answer: _answer,
      speak: spoken.add,
      now: () => DateTime.utc(2026, 9, 1, 12),
    );
  });

  tearDown(() async {
    controller.dispose();
    await questions.close();
  });

  test('connects a transcript to tactical advice and local TTS', () async {
    questions.add(' ¿Dónde está el jungla? ');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.processing, isFalse);
    expect(controller.state.question, '¿Dónde está el jungla?');
    expect(controller.state.advice?.id, 'answer');
    expect(controller.state.answeredAt, DateTime.utc(2026, 9, 1, 12));
    expect(spoken, ['Respuesta local']);
  });

  test('ignores an empty transcript', () async {
    questions.add('   ');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.question, isEmpty);
    expect(spoken, isEmpty);
  });

  test('publishes only the newest concurrent answer', () async {
    final first = Completer<TacticalAdvice>();
    controller.dispose();
    controller = NativeVoiceCoachController(
      questions: questions.stream,
      answer: (question) =>
          question == 'primera' ? first.future : _answer(question),
      speak: spoken.add,
    );

    final firstOperation = controller.handleQuestion('primera');
    await controller.handleQuestion('segunda');
    first.complete(_answer('primera'));
    await firstOperation;

    expect(controller.state.question, 'segunda');
    expect(spoken, ['Respuesta local']);
  });
}

TacticalAdvice _answer(String question) => TacticalAdvice(
  id: 'answer',
  title: 'Respuesta',
  hints: const ['Actúa'],
  rationale: question,
  ttsText: 'Respuesta local',
  priority: 1,
  evidence: [
    TacticalEvidence(
      factType: 'question',
      source: FactSource.user,
      observedAt: DateTime.utc(2026, 9, 1),
      confidence: 1,
    ),
  ],
);
