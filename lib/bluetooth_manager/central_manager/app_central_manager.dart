import 'dart:async';

import 'package:bluetooth_p/bluetooth_manager/bluetooth_constant.dart';
import 'package:bluetooth_p/util/force_value_notifier.dart';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../util/event_notifier_mixin.dart';

///封装蓝牙中心设备的功能
class AppCentralManager with EventNotifierMixin {
  static final instance = AppCentralManager._();

  //外部监听事件
  static final eventBlueState = 'eventBlueState';
  static final eventScanResult = 'eventScanResult';
  static final eventDeviceConnectState = 'eventDeviceConnectState';

  //外部消息接受监听
  final ForceValueNotifier<List<int>> valueReceiveNotifier = ForceValueNotifier([]);

  //内部监听
  StreamSubscription? _blueStateSubs;
  StreamSubscription? _scanResultSubs;
  StreamSubscription? _deviceConnectStateSubs;
  StreamSubscription? _readCharacteristicValue;

  //内部值
  BluetoothAdapterState _blueState = BluetoothAdapterState.unknown;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _readChar; //读取蓝牙数据的特征值
  BluetoothCharacteristic? _writeChar; //写入蓝牙数据的特征值

  AppCentralManager._() {
    setupCentralListener();
  }

  ///蓝牙状态
  BluetoothAdapterState get blueState => _blueState;

  ///最近一次扫描结果
  List<ScanResult> get scanResult => FlutterBluePlus.lastScanResults;

  ///连接中的设备
  BluetoothDevice? get connectedDevice => _connectedDevice;

  ///协商的每包可写入大小
  int get maxPayloadSize {
    final device = connectedDevice;
    if (device == null) return -1;
    return device.mtuNow - 3;
  }

  bool get isConnectDevice {
    return connectedDevice?.isConnected ?? false;
  }

  Future<bool> requestPermission() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      return false;
    }

    return true;
  }

  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await FlutterBluePlus.startScan(
      withServices: [Guid.fromString(BluetoothConstant.serviceUuid)],
      timeout: timeout,
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> connectDevice(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await stopScan();
    if (device.isConnected) return true;

    try {
      _resetDeviceInfo();
      //mtu不是最终值，还需要调用方法获得双方设备的可支持最小值
      await device.connect(timeout: timeout, mtu: 512);
      if (!device.isConnected) {
        throw Exception('device connect failed');
      }
      _connectedDevice = device;
      _listenDevice(device);
      await _discoverDeviceServices(device);

      return true;
    } catch (_) {
      disconnectDevice();
    }

    return false;
  }

  void _listenDevice(BluetoothDevice device) {
    _deviceConnectStateSubs?.cancel();
    _deviceConnectStateSubs = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _resetDeviceInfo();
      }

      notifyEvent(eventDeviceConnectState);
    });
  }

  Future<void> _discoverDeviceServices(BluetoothDevice device) async {
    final serviceList = await device.discoverServices();
    final serviceUuid = Guid.fromString(BluetoothConstant.serviceUuid);
    final writeCharUuid = Guid.fromString(BluetoothConstant.writeCharUuid);
    final notifyCharUuid = Guid.fromString(BluetoothConstant.notifyCharUuid);
    //搜索目标服务
    final service = serviceList.firstWhereOrNull((service) {
      return service.uuid == serviceUuid;
    });
    if (service == null) {
      throw Exception('service not found');
    }
    //搜索读写特征值
    for (final characteristic in service.characteristics) {
      final charUuid = characteristic.uuid;
      if (charUuid == writeCharUuid) {
        _writeChar = characteristic;
      } else if (charUuid == notifyCharUuid) {
        _readChar = characteristic;
      }

      if (_writeChar != null && _readChar != null) {
        break;
      }
    }
    if (_writeChar == null || _readChar == null) {
      throw Exception('characteristic not found');
    }
    //设置读特征值监听
    final readChar = _readChar!;
    if (!readChar.properties.notify) {
      throw Exception('characteristic.notify is false');
    }
    await readChar.setNotifyValue(true);
    _readCharacteristicValue = readChar.onValueReceived.listen((value) {
      valueReceiveNotifier.value = value;
    });
  }

  void _resetDeviceInfo() {
    //读写特征值
    _writeChar = null;
    _readChar = null;
    _readCharacteristicValue?.cancel();
    _readCharacteristicValue = null;
    //连接设备
    _connectedDevice = null;
    _deviceConnectStateSubs?.cancel();
    _deviceConnectStateSubs = null;
  }

  Future<void> disconnectDevice() async {
    final device = _connectedDevice;
    if (device != null) {
      await device.disconnect();
    }
    _resetDeviceInfo();
  }

  Future<bool> write(List<int> data) async {
    final writeChar = _writeChar;
    if (writeChar == null) return false;

    try {
      await writeChar.write(data, withoutResponse: true);
      return true;
    } catch (_) {}
    return false;
  }

  void setupCentralListener() {
    //蓝牙状态
    _blueStateSubs?.cancel();
    _blueStateSubs = FlutterBluePlus.adapterState.listen((state) {
      _blueState = state;
      notifyEvent(eventBlueState);
    });
    //扫描结果
    _scanResultSubs?.cancel();
    _scanResultSubs = FlutterBluePlus.scanResults.listen((results) {
      notifyEvent(eventScanResult);
    });
  }

  void disposeCentralListener() {
    _blueStateSubs?.cancel();
    _scanResultSubs?.cancel();
  }
}
