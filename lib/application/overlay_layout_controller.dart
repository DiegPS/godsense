import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const overlayPanelIds = [
  'gank',
  'jungler',
  'voice_ask',
  'matchup_info',
  'builds',
  'directives',
  'team_comp',
  'gold_chart',
];

class OverlayPanelLayout {
  const OverlayPanelLayout({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.collapsed = false,
  });

  factory OverlayPanelLayout.fromJson(Map<String, dynamic> json) {
    return OverlayPanelLayout(
      x: (json['x'] as num?)?.toDouble() ?? 24,
      y: (json['y'] as num?)?.toDouble() ?? 24,
      width: (json['width'] as num?)?.toDouble() ?? 360,
      height: (json['height'] as num?)?.toDouble() ?? 120,
      collapsed: json['collapsed'] == true,
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;
  final bool collapsed;

  OverlayPanelLayout copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? collapsed,
  }) {
    return OverlayPanelLayout(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'collapsed': collapsed,
  };
}

class OverlayLayoutState {
  const OverlayLayoutState({
    this.editing = false,
    this.loaded = false,
    this.panels = const {},
  });

  final bool editing;
  final bool loaded;
  final Map<String, OverlayPanelLayout> panels;

  OverlayLayoutState copyWith({
    bool? editing,
    bool? loaded,
    Map<String, OverlayPanelLayout>? panels,
  }) {
    return OverlayLayoutState(
      editing: editing ?? this.editing,
      loaded: loaded ?? this.loaded,
      panels: panels ?? this.panels,
    );
  }
}

final overlayLayoutProvider =
    StateNotifierProvider<OverlayLayoutController, OverlayLayoutState>((ref) {
      final controller = OverlayLayoutController();
      controller.load();
      return controller;
    });

class OverlayLayoutController extends StateNotifier<OverlayLayoutState> {
  OverlayLayoutController() : super(const OverlayLayoutState());

  static const _storageKey = 'godsense.overlay.layout.v1';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) {
      state = state.copyWith(loaded: true, panels: _defaultLayouts());
      return;
    }
    try {
      final decoded = jsonDecode(encoded);
      final saved = decoded is Map ? decoded : const {};
      final defaults = _defaultLayouts();
      for (final entry in saved.entries) {
        if (entry.value is Map) {
          defaults[entry.key.toString()] = OverlayPanelLayout.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      state = state.copyWith(loaded: true, panels: defaults);
    } catch (_) {
      state = state.copyWith(loaded: true, panels: _defaultLayouts());
    }
  }

  void setEditing(bool editing) {
    state = state.copyWith(editing: editing);
  }

  void toggleEditing() => setEditing(!state.editing);

  void move(String id, Offset delta, Size viewport) {
    final current = state.panels[id];
    if (current == null) return;
    final next = current.copyWith(
      x: (current.x + delta.dx).clamp(0, viewport.width - current.width),
      y: (current.y + delta.dy).clamp(0, viewport.height - 44),
    );
    _update(id, next, persist: false);
  }

  void resize(String id, Offset delta, Size viewport) {
    final current = state.panels[id];
    if (current == null) return;
    final next = current.copyWith(
      width: (current.width + delta.dx).clamp(240, viewport.width - current.x),
      height: (current.height + delta.dy).clamp(
        80,
        viewport.height - current.y,
      ),
    );
    _update(id, next, persist: false);
  }

  void toggleCollapsed(String id) {
    final current = state.panels[id];
    if (current == null) return;
    _update(id, current.copyWith(collapsed: !current.collapsed));
  }

  Future<void> persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(
        state.panels.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<void> reset() async {
    state = state.copyWith(panels: _defaultLayouts());
    await persist();
  }

  void _update(String id, OverlayPanelLayout layout, {bool persist = true}) {
    state = state.copyWith(panels: {...state.panels, id: layout});
    if (persist) this.persist();
  }

  Map<String, OverlayPanelLayout> _defaultLayouts() => {
    'gank': const OverlayPanelLayout(x: 24, y: 24, width: 360, height: 104),
    'voice_ask': const OverlayPanelLayout(
      x: 24,
      y: 250,
      width: 420,
      height: 130,
    ),
    'matchup_info': const OverlayPanelLayout(
      x: 1520,
      y: 144,
      width: 370,
      height: 130,
    ),
    'builds': const OverlayPanelLayout(
      x: 1140,
      y: 144,
      width: 370,
      height: 130,
    ),
    'directives': const OverlayPanelLayout(
      x: 1520,
      y: 284,
      width: 370,
      height: 170,
    ),
    'team_comp': const OverlayPanelLayout(
      x: 1140,
      y: 284,
      width: 370,
      height: 130,
    ),
    'jungler': const OverlayPanelLayout(x: 24, y: 700, width: 390, height: 310),
    'gold_chart': const OverlayPanelLayout(
      x: 1520,
      y: 900,
      width: 370,
      height: 100,
    ),
  };
}
