import 'dart:convert';

import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_protocol.dart';
import 'package:bluetooth_p/bluetooth_manager/bluetooth_central_manager.dart';
import 'package:bluetooth_p/util/dispatcher.dart';
import 'package:bluetooth_p/util/event_notifier_mixin.dart';

import 'callback/command_callback.dart';
import 'app_bluetooth_constant.dart';
import 'model/command_message.dart';
import 'model/display_bluetooth_device.dart';
import 'model/packets.dart';

class AppBluetoothCentralManager with EventNotifierMixin {
  static final instance = AppBluetoothCentralManager._();

  final centralManager = BluetoothCentralManager.instance;

  //外部监听事件
  static final eventScanResult = 'eventScanResult';
  static final eventDeviceConnectState = 'eventDeviceConnectState';

  //写入监听
  final commandDispatcher = Dispatcher<CommandCallback>();

  //内部值
  Packets? _packets;
  List<DisplayBluetoothDevice>? _scanDeviceList;
  DisplayBluetoothDevice? _connectedDevice;

  AppBluetoothCentralManager._() {
    final cMgr = centralManager;
    //接收数据监听
    cMgr.receiveNotifier.addListener(_receiveValue);
    cMgr.addEventListener(BluetoothCentralManager.eventScanResult, _onDeviceScan);
    cMgr.addEventListener(
      BluetoothCentralManager.eventDeviceConnectState,
      _onDeviceConnectStateChange,
    );
  }

  ///最近一次的扫描结果
  List<DisplayBluetoothDevice> get scanDeviceList => _scanDeviceList ?? [];

  ///正在连接的设备
  DisplayBluetoothDevice? get connectedDevice => _connectedDevice;

  ///是否处于连接状态
  bool get isConnectDevice => centralManager.isConnectDevice;

  ///写入数据
  void write(String commandFlag, String value) async {
    final cMgr = centralManager;

    final packetSize = cMgr.maxPayloadSize;
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
      cMgr.write(packet);
      if (firstSend) {
        firstSend = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  ///扫描设备
  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cMgr = centralManager;

    final permissionResult = await cMgr.requestPermission();
    if (!permissionResult) return;

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
    final connectResult = await cMgr.connectDevice(
      displayDevice.device,
      timeout: timeout,
    );

    if (connectResult) {
      _connectedDevice = displayDevice;
    }

    return connectResult;
  }

  ///断连设备
  Future<void> disconnectDevice() async {
    final cMgr = centralManager;
    await cMgr.disconnectDevice();
  }

  void _receiveValue() {
    final cMgr = centralManager;
    final data = cMgr.receiveNotifier.value;

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

  void _onDeviceScan() {
    final cMgr = centralManager;
    final resultList = cMgr.scanResult;
    final deviceList =
        resultList.map((scanResult) {
          final device = scanResult.device;
          final mData = scanResult.advertisementData.manufacturerData;
          final version = (mData[AppBluetoothConstant
                      .manufacturerDataVersion] ??
                  [0, 0, 0])
              .join('.');

          return DisplayBluetoothDevice(device: device, version: version);
        }).toList();
    _scanDeviceList = deviceList;
    notifyEvent(eventScanResult);
  }

  void _onDeviceConnectStateChange() {
    final cMgr = centralManager;
    final isConnect = cMgr.isConnectDevice;
    if (!isConnect) {
      _connectedDevice = null;
    }

    notifyEvent(eventDeviceConnectState);
  }
}
