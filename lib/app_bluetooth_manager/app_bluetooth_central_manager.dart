import 'dart:async';

import 'package:bluetooth_p/app_bluetooth_manager/model/packets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../bluetooth_manager/bluetooth_central_manager.dart';
import 'app_bluetooth_protocol.dart';
import 'app_bluetooth_constant.dart';
import 'model/display_bluetooth_device.dart';

class AppBluetoothCentralManager {
  static final instance = AppBluetoothCentralManager._();

  final centralManager = BluetoothCentralManager.instance;

  final _receivePacketsController = StreamController<Packets>.broadcast();
  final _appProtocol = AppBluetoothProtocol();
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

  ///接收包监听
  Stream<Packets> get receivePacketsStream => _receivePacketsController.stream;

  ///带返回写入数据
  Future<List<int>> write(
    List<int> data, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final cMgr = centralManager;

    final packetSize = cMgr.maxPayloadSize;
    return _appProtocol.write(
      data: data,
      maxPacketSize: packetSize,
      onWrite: (packet) async {
        await cMgr.write(packet);
      },
      timeout: timeout,
    );
  }

  ///无返回写入数据
  Future<void> writeWithoutResponse(List<int> data) async {
    final cMgr = centralManager;

    final packetSize = cMgr.maxPayloadSize;
    await _appProtocol.writeWithoutResponse(
      data: data,
      maxPacketSize: packetSize,
      opFlag: AppBluetoothProtocol.opFlagRequestWithoutResponse,
      onWrite: (packet) async {
        await cMgr.write(packet);
      },
    );
  }

  ///应答，需要请求的消息序号
  Future<void> respond(List<int> data, int messageIndex) async {
    final cMgr = centralManager;

    final packetSize = cMgr.maxPayloadSize;
    await _appProtocol.writeWithoutResponse(
      data: data,
      maxPacketSize: packetSize,
      opFlag: AppBluetoothProtocol.opFlagResponse,
      messageIndex: messageIndex,
      onWrite: (packet) async {
        await cMgr.write(packet);
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
