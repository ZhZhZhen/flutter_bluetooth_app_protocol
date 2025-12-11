import 'package:flutter_blue_plus/flutter_blue_plus.dart';

///描述带版本号的屏幕设备信息
class DisplayBluetoothDevice {
  final BluetoothDevice device;
  final String version;

  DisplayBluetoothDevice({required this.device, required this.version});
}
