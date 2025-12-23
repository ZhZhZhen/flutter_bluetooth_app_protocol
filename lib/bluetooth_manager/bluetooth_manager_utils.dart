import 'dart:async';

///用于在监听时重新发射值
///逻辑来自于FlutterBluePlus的_NewStreamWithInitialValueTransformer
class NewStreamWithInitialValueTransformer<T>
    extends StreamTransformerBase<T, T> {
  final T initialValue;

  late StreamController<T> controller;

  late StreamSubscription<T> subscription;

  var listenerCount = 0;

  NewStreamWithInitialValueTransformer(this.initialValue);

  @override
  Stream<T> bind(Stream<T> stream) {
    if (stream.isBroadcast) {
      return _bind(stream, broadcast: true);
    } else {
      return _bind(stream);
    }
  }

  Stream<T> _bind(Stream<T> stream, {bool broadcast = false}) {
    void onData(T data) {
      controller.add(data);
    }

    void onDone() {
      controller.close();
    }

    void onError(Object error) {
      controller.addError(error);
    }

    void onListen() {
      controller.add(initialValue);

      if (listenerCount == 0) {
        subscription = stream.listen(onData, onError: onError, onDone: onDone);
      }

      listenerCount++;
    }

    void onPause() {
      subscription.pause();
    }

    void onResume() {
      subscription.resume();
    }

    void onCancel() {
      listenerCount--;

      if (listenerCount == 0) {
        subscription.cancel();
        controller.close();
      }
    }

    if (broadcast) {
      controller = StreamController<T>.broadcast(
        onListen: onListen,
        onCancel: onCancel,
      );
    } else {
      controller = StreamController<T>(
        onListen: onListen,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
      );
    }

    return controller.stream;
  }
}

///用于创建广播stream，监听者在监听时会立刻收到上一个值
///逻辑来自于FlutterBluePlus的_StreamControllerReEmit
class StreamControllerReEmit<T> {
  T latestValue;

  final StreamController<T> _controller = StreamController<T>.broadcast();

  StreamControllerReEmit({required T initialValue})
    : latestValue = initialValue;

  Stream<T> get stream {
    if (latestValue != null) {
      return _controller.stream.transform(
        NewStreamWithInitialValueTransformer(latestValue!),
      );
    } else {
      return _controller.stream;
    }
  }

  T get value => latestValue;

  void add(T newValue) {
    latestValue = newValue;
    _controller.add(newValue);
  }

  void addError(Object error) {
    _controller.addError(error);
  }

  void listen(
    Function(T) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onData(latestValue);
    _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Future<void> close() {
    return _controller.close();
  }
}
