import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_p/util/system_info_util.dart';

import '../bluetooth_manager/bluetooth_peripheral_manager.dart';
import 'app_bluetooth_constant.dart';
import 'callback/command_callback.dart';
import '../util/dispatcher.dart';
import 'app_bluetooth_protocol.dart';
import 'model/command_message.dart';
import 'model/packets.dart';

///封装屏幕蓝牙的应用层协议
class AppBluetoothPeripheralManager {
  static final instance = AppBluetoothPeripheralManager._();

  final peripheralManager = BluetoothPeripheralManager.instance;

  //写入监听
  final commandDispatcher = Dispatcher<CommandCallback>();

  //内布值
  Packets? _packets;

  AppBluetoothPeripheralManager._() {
    final pMgr = peripheralManager;
    pMgr.onWriteNotifier.addListener(_receiveValue);
  }

  ///开启广播
  Future<void> startAdvertising() async {
    final pMgr = peripheralManager;

    final permissionResult = await pMgr.requestPermission();
    if (!permissionResult) return;

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

  ///写入数据
  void write(String commandFlag, String value) async {
    final pMgr = peripheralManager;

    final packetSize = await pMgr.maxPayloadSize;
    final data = utf8.encode(
      CommandMessage(commandFlag: commandFlag, value: value).toString(),
    );
    final packets = AppBluetoothProtocol.convertPackets(
      data,
      packetSize: packetSize,
      opFlag: AppBluetoothProtocol.opFlagCommand,
    );
    //首包后延时确保第一包能首先收到，整个命令发送后延时确保不和下一个命令重叠，虽然不知道这样做有没有用
    bool firstSend = true;
    for (final packet in packets) {
      pMgr.notify(packet);
      if (firstSend) {
        firstSend = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _receiveValue() {
    final pMgr = peripheralManager;
    final data = pMgr.onWriteNotifier.value;

    //校验包
    if (!AppBluetoothProtocol.validatePacket(data)) return;

    //组合包
    final isFirstPacket = AppBluetoothProtocol.isFirstPacket(data);
    if (isFirstPacket) {
      final packetsNum = AppBluetoothProtocol.getPacketsNum(data);
      final packets = Packets(packSize: packetsNum);
      packets.add(data);
      _packets = packets;
    } else {
      final packets = _packets;
      if (packets == null) return;
      packets.add(data);
    }

    //检查包是否组合完成
    final packets = _packets;
    if (packets == null) return;
    if (packets.isComplete()) {
      try {
        final finalData = packets.getData();
        final jsonStr = utf8.decode(finalData);
        final commandMsg = CommandMessage.fromJson(jsonDecode(jsonStr));
        commandDispatcher.dispatch([commandMsg.commandFlag, commandMsg.value]);
      } catch (_) {}
    }
  }
}
