import 'dart:typed_data';

import 'package:bluetooth_p/bluetooth_manager/peripheral_manager/app_peripheral_manager.dart';
import 'package:bluetooth_p/display_client/display_client_constant.dart';
import 'package:bluetooth_p/util/system_info_util.dart';

///封装屏幕蓝牙的应用层协议
class DisplayPeripheralManager {
  static final instance = DisplayPeripheralManager._();

  final _peripheralManager = AppPeripheralManager.instance;

  DisplayPeripheralManager._() {
    //todo 写入监听
  }

  Future<void> startAdvertising() async {
    final pMgr = _peripheralManager;

    final permissionResult = await pMgr.requestPermission();
    if (!permissionResult) return;

    final versionNum = await SystemInfoUtil.getAppVersionNumber();
    await pMgr.startAdvertising(
      manufacturerSpecificData: {
        DisplayClientConstant.manufacturerDataVersion: Uint8List.fromList([
          versionNum[0],
          versionNum[1],
          versionNum[2],
        ]),
      },
    );
  }

  Future<void> stopAdvertising() async {
    final pMgr = _peripheralManager;
    await pMgr.stopAdvertising();
  }
}
