import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_p/util/system_info_util.dart';

import '../bluetooth_manager/bluetooth_peripheral_manager.dart';
import 'app_bluetooth_constant.dart';
import 'app_bluetooth_protocol.dart';
import 'model/packets.dart';

///封装屏幕蓝牙的应用层协议
class AppBluetoothPeripheralManager {
  static final instance = AppBluetoothPeripheralManager._();

  final peripheralManager = BluetoothPeripheralManager.instance;

  //内布值
  final _receivePacketsController = StreamController<Packets>.broadcast();
  final _appProtocol = AppBluetoothProtocol();

  AppBluetoothPeripheralManager._() {
    final pMgr = peripheralManager;
    pMgr.receiveStream.listen((data) {
      _receiveValue(data);
    });
  }

  ///接收包监听
  Stream<Packets> get receivePacketsStream => _receivePacketsController.stream;

  ///开启广播
  Future<void> startAdvertising() async {
    final pMgr = peripheralManager;

    final versionNum = await SystemInfoUtil.getAppVersionNumber();
    await pMgr.startAdvertising(
      advertisementName: AppBluetoothConstant.devicePlatformName,
      manufacturerSpecificData: {
        AppBluetoothConstant.manufacturerDataVersion: Uint8List.fromList([
          versionNum[0],
          versionNum[1],
          versionNum[2],
        ]),
      },
    );
  }

  ///关闭广播
  Future<void> stopAdvertising() async {
    final pMgr = peripheralManager;
    await pMgr.stopAdvertising();
  }

  ///带返回写入数据
  Future<List<int>> writeWithResponse(
    List<int> data, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final pMgr = peripheralManager;

    final packetSize = await pMgr.maxPayloadSize;
    return _appProtocol.writeWithResponse(
      data: data,
      maxPacketSize: packetSize,
      onWrite: (packet) async {
        await pMgr.notify(packet);
      },
      timeout: timeout,
    );
  }

  ///无返回写入数据
  Future<void> writeWithoutResponse(List<int> data) async {
    final pMgr = peripheralManager;

    final packetSize = await pMgr.maxPayloadSize;
    await _appProtocol.writeWithoutResponse(
      data: data,
      maxPacketSize: packetSize,
      onWrite: (packet) async {
        await pMgr.notify(packet);
      },
    );
  }

  ///应答，需要请求的消息序号
  Future<void> respond(List<int> data, int messageIndex) async {
    final pMgr = peripheralManager;

    final packetSize = await pMgr.maxPayloadSize;
    await _appProtocol.writeWithoutResponse(
      data: data,
      maxPacketSize: packetSize,
      opFlag: AppBluetoothProtocol.opFlagResponse,
      messageIndex: messageIndex,
      onWrite: (packet) async {
        await pMgr.notify(packet);
      },
    );
  }

  ///接收数据
  void _receiveValue(List<int> data) {
    _appProtocol.receive(
      data: data,
      packetsCallback: (packets) {
        _receivePacketsController.add(packets);
      },
    );
  }
}
