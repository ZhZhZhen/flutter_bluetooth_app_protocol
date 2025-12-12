import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_p/util/system_info_util.dart';
import 'package:flutter/foundation.dart';

import '../util/event_notifier_mixin.dart';
import '../util/force_value_notifier.dart';
import 'bluetooth_constant.dart';

///封装蓝牙外围设备的功能
class BluetoothPeripheralManager with EventNotifierMixin {
  static final instance = BluetoothPeripheralManager._();

  final _peripheralManager = PeripheralManager();

  //外部监听事件
  static final eventAdvertisingState = 'eventAdvertisingState';
  static final eventBlueState = 'eventBlueState';
  static final eventCentralConnectState = 'eventCentralConnectState';

  final ForceValueNotifier<List<int>> onWriteNotifier = ForceValueNotifier([]);

  //内部监听
  StreamSubscription? _blueStateSubs;
  StreamSubscription? _centralConnectSubs;
  StreamSubscription? _charWriteSubs;
  StreamSubscription? _notifyStateSubs;

  //内部值
  GATTCharacteristic? _notifyChar;
  Central? _connectedCentral;

  bool _advertising = false;

  BluetoothPeripheralManager._() {
    setupPeripheralListener();
  }

  ///蓝牙状态
  BluetoothLowEnergyState get blueState => _peripheralManager.state;

  ///广播状态
  bool get advertising => _advertising;

  ///连接中的中心设备
  Central? get connectedCentral => _connectedCentral;

  bool get isConnectDevice {
    return connectedCentral != null;
  }

  ///协商的每包可写入大小
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
    if (_advertising) {
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
    _advertising = true;
    notifyEvent(eventAdvertisingState);
  }

  Future<void> stopAdvertising() async {
    if (!_advertising) {
      return;
    }

    await _peripheralManager.stopAdvertising();
    _advertising = false;
    notifyEvent(eventAdvertisingState);
  }

  Future<bool> notify(List<int> data) async {
    final peripheralMgr = _peripheralManager;
    final central = _connectedCentral;
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
  void setupPeripheralListener() {
    final peripheralMgr = _peripheralManager;
    //蓝牙状态
    _blueStateSubs?.cancel();
    _blueStateSubs = peripheralMgr.stateChanged.listen((event) {
      notifyEvent(eventBlueState);
    });
    //连接监听
    _centralConnectSubs?.cancel();
    _centralConnectSubs = peripheralMgr.connectionStateChanged.listen((event) {
      final connectState = event.state;
      final central = event.central;
      if (connectState == ConnectionState.connected) {
        _connectedCentral = central;
      } else {
        _connectedCentral = null;
      }
      notifyEvent(eventCentralConnectState);
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
        onWriteNotifier.value = value;
      }

      await peripheralMgr.respondWriteRequest(request);
    });
    //notify状态改变监听
    _notifyStateSubs?.cancel();
    _notifyStateSubs = peripheralMgr.characteristicNotifyStateChanged.listen((
      event,
    ) {
      final notifyState = event.state;
      final notifyChar = event.characteristic;
      if (notifyState) {
        _notifyChar = notifyChar;
      } else {
        _notifyChar = null;
      }
    });
  }

  ///清除监听
  void disposePeripheralListener() {
    _blueStateSubs?.cancel();
    _centralConnectSubs?.cancel();
    _charWriteSubs?.cancel();
    _notifyStateSubs?.cancel();
  }
}
