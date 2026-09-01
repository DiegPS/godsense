// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tactical/tactical_models.dart';

class NativeVoiceCoachState {
  const NativeVoiceCoachState({
    this.processing = false,
    this.question = '',
    this.advice,
    this.answeredAt,
    this.error,
  });

  final bool processing;
  final String question;
  final TacticalAdvice? advice;
  final DateTime? answeredAt;
  final String? error;

  NativeVoiceCoachState copyWith({
    bool? processing,
    String? question,
    TacticalAdvice? advice,
    DateTime? answeredAt,
    String? error,
    bool clearError = false,
  }) => NativeVoiceCoachState(
    processing: processing ?? this.processing,
    question: question ?? this.question,
    advice: advice ?? this.advice,
    answeredAt: answeredAt ?? this.answeredAt,
    error: clearError ? null : error ?? this.error,
  );
}

class NativeVoiceCoachController extends StateNotifier<NativeVoiceCoachState> {
  NativeVoiceCoachController({
    required Stream<String> questions,
    required FutureOr<TacticalAdvice> Function(String question) answer,
    required void Function(String text) speak,
    DateTime Function()? now,
  }) : _answer = answer,
       _speak = speak,
       _now = now ?? DateTime.now,
       super(const NativeVoiceCoachState()) {
    _subscription = questions.listen(
      (question) => unawaited(handleQuestion(question)),
      onError: (Object error) {
        if (!_disposed) state = state.copyWith(error: error.toString());
      },
    );
  }

  final FutureOr<TacticalAdvice> Function(String question) _answer;
  final void Function(String text) _speak;
  final DateTime Function() _now;
  late final StreamSubscription<String> _subscription;
  int _revision = 0;
  bool _disposed = false;

  Future<void> handleQuestion(String rawQuestion) async {
    final question = rawQuestion.trim();
    if (_disposed || question.isEmpty) return;
    final revision = ++_revision;
    state = state.copyWith(
      processing: true,
      question: question,
      clearError: true,
    );
    try {
      final advice = await Future<TacticalAdvice>.sync(() => _answer(question));
      if (_disposed || revision != _revision) return;
      state = state.copyWith(
        processing: false,
        advice: advice,
        answeredAt: _now(),
        clearError: true,
      );
      if (advice.ttsText.trim().isNotEmpty) _speak(advice.ttsText);
    } catch (error) {
      if (_disposed || revision != _revision) return;
      state = state.copyWith(processing: false, error: error.toString());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
