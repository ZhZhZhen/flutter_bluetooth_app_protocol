import 'dart:convert';

import 'package:bluetooth_p/bluetooth_manager/central_manager/app_central_manager.dart';
import 'package:bluetooth_p/display_client/display_protocol.dart';

class DisplayCentralManager {
  static final instance = DisplayCentralManager._();

  final _centralManager = AppCentralManager.instance;

  DisplayCentralManager._() {
    final cMgr = _centralManager;
    cMgr.valueReceiveNotifier.addListener(receiveValue);
  }

  //todo 返回扫描结果，不是一个一个吐得，每次都是一个完整列表
  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cMgr = _centralManager;

    final permissionResult = await cMgr.requestPermission();
    if (!permissionResult) return;

    cMgr.scanDevice(timeout: timeout);
  }

  void receiveValue() {
    final cMgr = _centralManager;
    final dataList = cMgr.valueReceiveNotifier.value;
  }

  void writeCommand(String command) async {
    final cMgr = _centralManager;

    final packetSize = cMgr.maxPayloadSize;
    final data = utf8.encode(command);
    final packets = DisplayProtocol.convertPackets(
      data,
      packetSize: packetSize,
      flag: DisplayProtocol.flagCommand,
    );
    for (final packet in packets) {
      cMgr.write(packet);
    }
  }
}
