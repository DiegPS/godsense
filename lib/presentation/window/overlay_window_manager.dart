part of '../../app/godsense_app.dart';

class OverlayWindowManager extends WindowObserver {
  OverlayWindowManager(this.container);

  final ProviderContainer container;
  int? _viewId;
  Future<int>? _opening;

  bool get isOpen => container.read(overlayOpenProvider);
  int? get viewId => _viewId;

  Future<void> toggle(BuildContext ownerContext) async {
    final existing = _viewId;
    if (existing != null &&
        MultiViewDesktop.allWindowViewIds.contains(existing)) {
      if (isOpen) {
        await hide();
      } else {
        await show(ownerContext);
      }
      return;
    }
    await open(ownerContext);
  }

  Future<int> open(BuildContext ownerContext) async {
    final existing = _viewId;
    if (existing != null &&
        MultiViewDesktop.allWindowViewIds.contains(existing)) {
      await show(ownerContext);
      return existing;
    }

    final pending = _opening;
    if (pending != null) return pending;

    final ownerId = MultiViewDesktop.getIdByContext(ownerContext);
    final opening = openWindow(
      (_, _) => const GodSenseOverlay(),
      options: const WindowOptions(
        fullScreen: true,
        title: 'GodSense Overlay',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        backgroundColor: Colors.transparent,
        alwaysOnTop: true,
      ),
      parentContext: ownerContext,
    );
    _opening = opening;

    try {
      final id = await opening;
      _viewId = id;
      final window = MultiViewDesktop.fromId(id);
      await window.setHasShadow(false);
      await window.setResizable(false);
      await window.setMovable(false);
      await window.setIgnoreMouseEvents(true);
      await window.hideCurrentAppTabFromTaskbar(true);
      container.read(overlayOpenProvider.notifier).state = true;

      await MultiViewDesktop.fromId(ownerId).focus();
      return id;
    } finally {
      _opening = null;
    }
  }

  Future<void> show([BuildContext? ownerContext]) async {
    final id = _viewId;
    if (id != null && MultiViewDesktop.allWindowViewIds.contains(id)) {
      final window = MultiViewDesktop.fromId(id);
      await window.show();
      await window.setAsFrameless();
      await window.setHasShadow(false);
      await window.setIgnoreMouseEvents(true);
      await window.hideCurrentAppTabFromTaskbar(true);
      container.read(overlayOpenProvider.notifier).state = true;
      return;
    }
    if (ownerContext != null) {
      await open(ownerContext);
    }
  }

  Future<void> hide() async {
    final id = _viewId;
    if (id != null && MultiViewDesktop.allWindowViewIds.contains(id)) {
      await MultiViewDesktop.fromId(id).hide();
    }
    container.read(overlayOpenProvider.notifier).state = false;
  }

  Future<void> close() async {
    await hide();
  }

  @override
  void onWindowClosed(int viewId) {
    if (_viewId != viewId) return;
    _viewId = null;
    container.read(overlayOpenProvider.notifier).state = false;
  }
}
