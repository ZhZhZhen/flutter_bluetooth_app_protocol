import 'package:bluetooth_p/bluetooth_manager/central_manager/app_central_manager.dart';

class DisplayCentralManager {
  static final instance = DisplayCentralManager._();

  final _centralManager = AppCentralManager.instance;

  DisplayCentralManager._(){
    //todo 写入监听
  }

  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cMgr = _centralManager;

    final permissionResult = await cMgr.requestPermission();
    if (!permissionResult) return;

    cMgr.scanDevice(timeout: timeout);
  }
}
