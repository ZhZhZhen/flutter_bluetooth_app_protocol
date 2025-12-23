import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_p/util/system_info_util.dart';
import 'package:flutter/foundation.dart';

import 'bluetooth_constant.dart';
import 'bluetooth_manager_utils.dart';

///封装蓝牙外围设备的功能，仅支持单设备连接
class BluetoothPeripheralManager {
  static final instance = BluetoothPeripheralManager._();

  final _peripheralManager = PeripheralManager();

  //提供外部监听
  final _advertisingController = StreamControllerReEmit<bool>(
    initialValue: false,
  );
  final _connectedCentralController = StreamControllerReEmit<Central?>(
    initialValue: null,
  );
  final _receiveController = StreamController<List<int>>.broadcast();

  //内部监听
  StreamSubscription? _centralConnectSubs;
  StreamSubscription? _charWriteSubs;
  StreamSubscription? _notifyStateSubs;

  //内部值
  GATTCharacteristic? _notifyChar;

  BluetoothPeripheralManager._() {
    _setupPeripheralListener();
  }

  ///蓝牙状态监听
  Stream<BluetoothLowEnergyState> get bluetoothStateStream {
    final peripheralManager = _peripheralManager;
    final stateNow = peripheralManager.state;
    return _peripheralManager.stateChanged
        .map((e) => e.state)
        .transform(NewStreamWithInitialValueTransformer(stateNow));
  }

  ///广播状态监听
  Stream<bool> get advertisingStream => _advertisingController.stream;

  ///广播状态
  bool get advertising => _advertisingController.latestValue;

  ///已连接设备监听
  Stream<Central?> get connectedCentralStream =>
      _connectedCentralController.stream.distinct();

  ///连接中的设备
  Central? get connectedCentral => _connectedCentralController.latestValue;

  ///是否连接
  bool get isConnectDevice => connectedCentral != null;

  ///接收数据监听
  Stream<List<int>> get receiveStream => _receiveController.stream;

  ///协商的每包可写入大小v
  Future<int> get maxPayloadSize async {
    final central = connectedCentral;
    if (central == null) return -1;
    return await _peripheralManager.getMaximumNotifyLength(central);
  }

  Future<bool> requestPermission() async {
    if (!SystemInfoUtil.isAndroid()) return true;

    try {
      final peripheralMgr = _peripheralManager;
      //Android端manager创建后立刻调用authorize()，会导致callback置空无法回传结果。查看代码得知完成初始化后会发射第一个状态，所以等待第一个状态到来
      if (peripheralMgr.state == BluetoothLowEnergyState.unknown) {
        await peripheralMgr.stateChanged.first;
      }
      return await peripheralMgr.authorize();
    } catch (_) {}
    return false;
  }

  Future<bool> waitBluetoothOn({Duration? timeout}) async {
    try {
      final peripheralMgr = _peripheralManager;
      if (peripheralMgr.state == BluetoothLowEnergyState.poweredOn) {
        return true;
      }

      final future = peripheralMgr.stateChanged.firstWhere(
        (event) => event.state == BluetoothLowEnergyState.poweredOn,
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

  Future<void> startAdvertising({
    String? advertisementName,
    Map<int, Uint8List>? manufacturerSpecificData,
  }) async {
    if (advertising) {
      return;
    }

    final peripheralMgr = _peripheralManager;
    //移除所有已有服务
    peripheralMgr.removeAllServices();
    //创建服务
    final service = GATTService(
      uuid: UUID.fromString(BluetoothConstant.serviceUuid),
      isPrimary: true,
      includedServices: [],
      characteristics: [
        //接受写入
        GATTCharacteristic.mutable(
          uuid: UUID.fromString(BluetoothConstant.writeCharUuid),
          properties: [
            GATTCharacteristicProperty.write,
            GATTCharacteristicProperty.writeWithoutResponse,
          ],
          permissions: [GATTCharacteristicPermission.write],
          descriptors: [],
        ),
        //返回数据
        GATTCharacteristic.mutable(
          uuid: UUID.fromString(BluetoothConstant.notifyCharUuid),
          properties: [GATTCharacteristicProperty.notify],
          permissions: [],
          descriptors: [],
        ),
      ],
    );
    //添加服务
    await peripheralMgr.addService(service);
    //开始广播
    await peripheralMgr.startAdvertising(
      Advertisement(
        name: advertisementName,
        serviceUUIDs: [UUID.fromString(BluetoothConstant.serviceUuid)],
        manufacturerSpecificData: [
          if (manufacturerSpecificData != null)
            ...manufacturerSpecificData.entries.map((entry) {
              return ManufacturerSpecificData(id: entry.key, data: entry.value);
            }),
        ],
      ),
    );
    //通知完成
    _advertisingController.add(true);
  }

  Future<void> stopAdvertising() async {
    if (!advertising) {
      return;
    }

    await _peripheralManager.stopAdvertising();
    _advertisingController.add(false);
  }

  Future<bool> notify(List<int> data) async {
    final peripheralMgr = _peripheralManager;
    final central = connectedCentral;
    final notifyChar = _notifyChar;
    if (central == null || notifyChar == null) {
      return false;
    }

    try {
      await peripheralMgr.notifyCharacteristic(
        central,
        notifyChar,
        value: Uint8List.fromList(data),
      );
      return true;
    } catch (_) {}
    return false;
  }

  ///设置监听
  void _setupPeripheralListener() {
    final peripheralMgr = _peripheralManager;
    //连接监听
    _centralConnectSubs?.cancel();
    _centralConnectSubs = peripheralMgr.connectionStateChanged.listen((event) {
      final connectState = event.state;
      final central = event.central;
      final connectedCentral = this.connectedCentral;
      //只允许最先连接的设备进行判定
      if (connectState == ConnectionState.connected) {
        if (connectedCentral != null) return;
        _connectedCentralController.add(central);
      } else {
        if (connectedCentral != central) return;
        _connectedCentralController.add(null);
      }
    });
    //写入监听
    final writeUuid = UUID.fromString(BluetoothConstant.writeCharUuid);
    _charWriteSubs?.cancel();
    _charWriteSubs = peripheralMgr.characteristicWriteRequested.listen((
      event,
    ) async {
      final characteristic = event.characteristic;
      final request = event.request;
      final value = request.value;

      if (characteristic.uuid == writeUuid) {
        _receiveController.add(value);
      }

      await peripheralMgr.respondWriteRequest(request);
    });
    //notify状态改变监听
    final notifyUuid = UUID.fromString(BluetoothConstant.notifyCharUuid);
    _notifyStateSubs?.cancel();
    _notifyStateSubs = peripheralMgr.characteristicNotifyStateChanged.listen((
      event,
    ) {
      final notifyState = event.state;
      final central = event.central;
      final notifyChar = event.characteristic;
      if (central == connectedCentral && notifyChar.uuid == notifyUuid) {
        if (notifyState) {
          _notifyChar = notifyChar;
        } else {
          _notifyChar = null;
        }
      }
    });
  }
}
