import 'dart:ui';

///作用类似ChangeNotifier，区别在于可以通过key，选择性监听和选择性触发
mixin EventNotifierMixin {
  final Map<dynamic, List<VoidCallback>> _eventListenersMap = {};

  /// 订阅事件
  void addEventListener(dynamic key, VoidCallback listener) {
    _eventListenersMap.putIfAbsent(key, () => []).add(listener);
  }

  /// 取消订阅事件
  void removeEventListener(dynamic key, VoidCallback listener) {
    _eventListenersMap[key]?.remove(listener);
  }

  /// 触发指定事件
  void notifyEvent(dynamic key) {
    final originHandlers = _eventListenersMap[key];
    if (originHandlers == null) return;

    final handlers = List.from(originHandlers);
    for (var h in handlers) {
      h();
    }
  }

  /// 销毁（可选）
  void disposeEventNotifier() {
    _eventListenersMap.clear();
  }
}
