class Dispatcher<T extends Function> {
  final Set<T> _listeners = <T>{};

  void addListener(T listener) {
    _listeners.add(listener);
  }

  void removeListener(T listener) {
    _listeners.remove(listener);
  }

  void dispatch(List<dynamic> args) {
    for (final listener in _listeners) {
      Function.apply(listener, args);
    }
  }
}