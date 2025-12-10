import 'package:flutter/foundation.dart';

///强制更新的ValueNotifier，即使value相同也会触发
class ForceValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  ForceValueNotifier(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T newValue) {
    _value = newValue;
    notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';
}
