import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:synchronized/synchronized.dart';

import '../bluetooth_manager/bluetooth_central_manager.dart';
import '../util/dispatcher.dart';
import 'app_bluetooth_protocol.dart';
import 'callback/command_callback.dart';
import 'app_bluetooth_constant.dart';
import 'model/command_message.dart';
import 'model/display_bluetooth_device.dart';
import 'model/packets.dart';

class AppBluetoothCentralManager {
  static final instance = AppBluetoothCentralManager._();

  final centralManager = BluetoothCentralManager.instance;

  //写入监听
  final commandDispatcher = Dispatcher<CommandCallback>();
  final _writeLock = Lock(); //用于串行写入

  //内部值
  Packets? _packets;
  DisplayBluetoothDevice? _pendingDevice;

  AppBluetoothCentralManager._() {
    final cMgr = centralManager;
    cMgr.receiveStream.listen((data) {
      _receiveValue(data);
    });
  }

  ///蓝牙扫描结果监听
  Stream<List<DisplayBluetoothDevice>> get scanDevices =>
      centralManager.scanResults.map((scanResultList) {
        final deviceList =
            scanResultList.map(_tranScanResultToDisplayDevice).toList();
        return deviceList;
      });

  ///已连接设备监听
  Stream<DisplayBluetoothDevice?> get connectedDeviceStream => centralManager
      .connectedDeviceStream
      .map((device) => _checkAndReturnPendingDevice(_pendingDevice, device));

  ///连接中的设备
  DisplayBluetoothDevice? get connectedDevice => _checkAndReturnPendingDevice(
    _pendingDevice,
    centralManager.connectedDevice,
  );

  ///是否连接
  bool get isConnectDevice => centralManager.isConnectDevice;

  ///写入数据
  Future<void> write({required String commandFlag, String? value}) async {
    await _writeLock.synchronized(() async {
      final cMgr = centralManager;

      final packetSize = cMgr.maxPayloadSize;
      final data = utf8.encode(
        CommandMessage(commandFlag: commandFlag, value: value ?? '').toString(),
      );
      final packets = AppBluetoothProtocol.convertPackets(
        data,
        packetSize: packetSize,
        opFlag: AppBluetoothProtocol.opFlagCommand,
      );
      //首包后延时确保第一包能首先收到，整个命令发送后延时确保不和下一个命令重叠，虽然不知道这样做有没有用
      bool firstSend = true;
      for (final packet in packets) {
        cMgr.write(packet);
        if (firstSend) {
          firstSend = false;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    });
  }

  ///扫描设备
  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cMgr = centralManager;
    await cMgr.scanDevice(timeout: timeout);
  }

  ///取消扫描
  Future<void> stopScan() async {
    final cMgr = centralManager;
    await cMgr.stopScan();
  }

  ///连接设备
  Future<bool> connectDevice(
    DisplayBluetoothDevice displayDevice, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final cMgr = centralManager;

    _pendingDevice = displayDevice;
    final connectResult = await cMgr.connectDevice(
      displayDevice.device,
      timeout: timeout,
    );

    return connectResult;
  }

  ///断连设备
  Future<void> disconnectDevice() async {
    final cMgr = centralManager;
    await cMgr.disconnectDevice();
  }

  void _receiveValue(List<int> data) {
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

  DisplayBluetoothDevice _tranScanResultToDisplayDevice(ScanResult scanResult) {
    final device = scanResult.device;
    final mData = scanResult.advertisementData.manufacturerData;
    final version = (mData[AppBluetoothConstant.manufacturerDataVersion] ??
            [0, 0, 0])
        .join('.');

    return DisplayBluetoothDevice(device: device, version: version);
  }

  DisplayBluetoothDevice? _checkAndReturnPendingDevice(
    DisplayBluetoothDevice? pendingDevice,
    BluetoothDevice? device,
  ) {
    if (device == null || pendingDevice == null) return null;

    if (device.remoteId != pendingDevice.device.remoteId) {
      return null;
    }

    return pendingDevice;
  }
}
