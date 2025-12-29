import 'dart:async';

import 'package:bluetooth_p/bluetooth_manager/bluetooth_constant.dart';
import 'package:bluetooth_p/bluetooth_manager/bluetooth_manager_util.dart';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

///封装蓝牙中心设备的功能，仅支持单设备连接
class BluetoothCentralManager {
  static final instance = BluetoothCentralManager._();

  //提供外部监听
  final _connectedDeviceController = StreamControllerReEmit<BluetoothDevice?>(
    initialValue: null,
  );
  final _receiveController = StreamController<List<int>>.broadcast();

  //内部值
  StreamSubscription? _deviceConnectStateSubs; //监听设备断连
  BluetoothCharacteristic? _writeChar; //写入数据
  StreamSubscription? _readCharacteristicValue; //监听读取

  BluetoothCentralManager._();

  ///蓝牙状态监听
  Stream<BluetoothAdapterState> get bluetoothState =>
      FlutterBluePlus.adapterState;

  ///蓝牙扫描结果监听
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  ///已连接设备监听
  Stream<BluetoothDevice?> get connectedDeviceStream =>
      _connectedDeviceController.stream.distinct();

  ///连接中的设备
  BluetoothDevice? get connectedDevice =>
      _connectedDeviceController.latestValue;

  ///是否连接
  bool get isConnectDevice => connectedDevice?.isConnected ?? false;

  ///接收数据监听
  Stream<List<int>> get receiveStream => _receiveController.stream;

  ///协商的每包可写入大小
  int get maxPayloadSize {
    final device = connectedDevice;
    if (device == null) return -1;
    return device.mtuNow - 3;
  }

  Future<bool> requestPermission() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      return false;
    }

    return true;
  }

  Future<bool> waitBluetoothOn({Duration? timeout}) async {
    try {
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
        return true;
      }

      final future = FlutterBluePlus.adapterState.firstWhere(
        (state) => state == BluetoothAdapterState.on,
      );

      if (timeout != null) {
        await future.timeout(timeout);
      } else {
        await future;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await FlutterBluePlus.startScan(
      withServices: [Guid.fromString(BluetoothConstant.serviceUuid)],
      timeout: timeout,
    );
    await FlutterBluePlus.isScanning.firstWhere((isScanning) => !isScanning);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> connectDevice(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (isConnectDevice) {
      if (device == connectedDevice) return true;
      throw Exception('Only supports single device connection');
    }

    try {
      //连接并协商mtu（确认双方接收的传输最大值）
      await device.connect(timeout: timeout, mtu: 512);
      if (!device.isConnected) {
        throw Exception('device connect failed');
      }
      //创建断连监听
      _deviceConnectStateSubs?.cancel();
      _deviceConnectStateSubs = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _resetDeviceInfo();
        }
      });
      //搜索服务
      await _discoverDeviceServices(device);
      _connectedDeviceController.add(device);
      return true;
    } catch (_) {
      //步骤执行出错，则断连
      await device.disconnect();
    }

    return false;
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
    BluetoothCharacteristic? writeChar;
    BluetoothCharacteristic? readChar;
    //搜索读写特征值
    for (final characteristic in service.characteristics) {
      final charUuid = characteristic.uuid;
      if (charUuid == writeCharUuid) {
        writeChar = characteristic;
      } else if (charUuid == notifyCharUuid) {
        readChar = characteristic;
      }

      if (writeChar != null && readChar != null) {
        break;
      }
    }
    if (writeChar == null || readChar == null) {
      throw Exception('characteristic not found');
    }
    //设置读特征值监听
    if (!readChar.properties.notify) {
      throw Exception('characteristic.notify is false');
    }
    await readChar.setNotifyValue(true);
    _readCharacteristicValue?.cancel();
    _readCharacteristicValue = readChar.onValueReceived.listen((value) {
      _receiveController.add(value);
    });
    _writeChar = writeChar;
  }

  void _resetDeviceInfo() {
    //读写特征值
    _readCharacteristicValue?.cancel();
    _readCharacteristicValue = null;
    _writeChar = null;
    //连接设备
    _deviceConnectStateSubs?.cancel();
    _deviceConnectStateSubs = null;
    _connectedDeviceController.add(null);
  }

  Future<void> disconnectDevice() async {
    final device = connectedDevice;
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
}
