part of '../../app/godsense_app.dart';

class OverlayWindowManager extends WindowObserver {
  OverlayWindowManager(this.container);

  final ProviderContainer container;
  int? _viewId;
  Future<int>? _opening;
  Future<void> _transition = Future<void>.value();
  bool _desiredVisible = false;

  bool get isOpen => container.read(overlayOpenProvider);
  int? get viewId => _viewId;

  Future<void> setVisible(BuildContext ownerContext, bool visible) async {
    _desiredVisible = visible;
    await _enqueue(() => _reconcile(ownerContext));
  }

  Future<int?> prewarm(BuildContext ownerContext) async {
    await _enqueue(() async {
      await _ensureCreated(ownerContext);
    });
    return _viewId;
  }

  Future<void> toggle(BuildContext ownerContext) async {
    await setVisible(ownerContext, !isOpen);
  }

  Future<int?> open(BuildContext ownerContext) async {
    await setVisible(ownerContext, true);
    return _viewId;
  }

  Future<void> _reconcile(BuildContext ownerContext) async {
    final id = await _ensureCreated(ownerContext);
    if (id == null) return;
    if (_desiredVisible) {
      await _showWindow(id);
    } else {
      await _hideWindow(id);
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _transition.then((_) => operation());
    _transition = next.onError((error, stackTrace) {
      debugPrint('GodSense overlay transition failed: $error');
    });
    return next;
  }

  Future<int?> _ensureCreated(BuildContext ownerContext) async {
    if (MultiViewDesktop.maybeGetIdByContext(ownerContext) == null) return null;
    final existing = _viewId;
    if (existing != null &&
        MultiViewDesktop.allWindowViewIds.contains(existing)) {
      return existing;
    }

    final pending = _opening;
    if (pending != null) return pending;

    try {
      final opening = openWindow(
        (_, _) => const GodSenseOverlay(),
        options: const WindowOptions(
          fullScreen: true,
          title: 'GodSense Overlay',
          titleBarStyle: TitleBarStyle.hidden,
          windowButtonVisibility: false,
          backgroundColor: Colors.transparent,
          alwaysOnTop: true,
          showOnInit: false,
        ),
        parentContext: ownerContext,
      );
      _opening = opening;

      final id = await opening;
      _viewId = id;
      final window = MultiViewDesktop.fromId(id);
      await window.setHasShadow(false);
      await window.setResizable(false);
      await window.setMovable(false);
      await window.setIgnoreMouseEvents(true);
      await window.hideCurrentAppTabFromTaskbar(true);
      container.read(overlayOpenProvider.notifier).state = false;
      return id;
    } catch (error) {
      debugPrint('GodSense overlay could not be created: $error');
      return null;
    } finally {
      _opening = null;
    }
  }

  Future<void> show([BuildContext? ownerContext]) async {
    _desiredVisible = true;
    if (ownerContext != null) {
      await setVisible(ownerContext, true);
      return;
    }
    final id = _viewId;
    if (id != null && MultiViewDesktop.allWindowViewIds.contains(id)) {
      await _enqueue(() => _showWindow(id));
    }
  }

  Future<void> hide() async {
    _desiredVisible = false;
    final id = _viewId;
    if (id != null && MultiViewDesktop.allWindowViewIds.contains(id)) {
      await _enqueue(() => _hideWindow(id));
    } else {
      container.read(overlayOpenProvider.notifier).state = false;
    }
  }

  Future<void> close() async {
    await hide();
  }

  Future<void> _showWindow(int id) async {
    if (!_desiredVisible || !MultiViewDesktop.allWindowViewIds.contains(id)) {
      return;
    }
    final window = MultiViewDesktop.fromId(id);
    await window.setAsFrameless();
    await window.setHasShadow(false);
    await window.setIgnoreMouseEvents(
      !container.read(overlayLayoutProvider).editing,
    );
    await window.hideCurrentAppTabFromTaskbar(true);
    await window.show();
    container.read(overlayOpenProvider.notifier).state = true;
  }

  Future<void> _hideWindow(int id) async {
    if (_desiredVisible || !MultiViewDesktop.allWindowViewIds.contains(id)) {
      return;
    }
    await MultiViewDesktop.fromId(id).hide();
    container.read(overlayOpenProvider.notifier).state = false;
  }

  @override
  void onWindowClosed(int viewId) {
    if (_viewId != viewId) return;
    _viewId = null;
    _desiredVisible = false;
    container.read(overlayOpenProvider.notifier).state = false;
  }
}
