import 'dart:async';
import 'dart:convert';

import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_central_manager.dart';
import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_protocol.dart';
import 'package:bluetooth_p/app_bluetooth_manager/model/packets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_bluetooth_manager/model/display_bluetooth_device.dart';
import '../util/system_info_util.dart';

class CentralPage extends StatefulWidget {
  const CentralPage({super.key});

  @override
  State<CentralPage> createState() => _CentralPageState();
}

class _CentralPageState extends State<CentralPage> {
  final _cMgr = AppBluetoothCentralManager.instance;

  List<String> dataList = [];

  StreamSubscription? _bluetoothStateSubs;
  BluetoothAdapterState? blueState;

  StreamSubscription? _scanDeviceSubs;
  List<DisplayBluetoothDevice> _scanResultList = [];

  StreamSubscription? _connectedDeviceSubs;

  StreamSubscription? _receivePacketsSubs;

  @override
  void initState() {
    super.initState();
    requestPermission();
    _bluetoothStateSubs?.cancel();
    _bluetoothStateSubs = _cMgr.centralManager.bluetoothState.listen((state) {
      blueState = state;
      setState(() {});
    });

    _scanDeviceSubs?.cancel();
    _scanDeviceSubs = _cMgr.scanDevices.listen((deviceList) {
      _scanResultList = deviceList;
      setState(() {});
    });

    _connectedDeviceSubs?.cancel();
    _connectedDeviceSubs = _cMgr.connectedDeviceStream.listen((device) {
      setState(() {});
    });

    _receivePacketsSubs?.cancel();
    _receivePacketsSubs = _cMgr.receivePacketsStream.listen((packets) {
      receivePackets(packets);
    });
  }

  @override
  void dispose() {
    _bluetoothStateSubs?.cancel();
    _scanDeviceSubs?.cancel();
    _connectedDeviceSubs?.cancel();
    _receivePacketsSubs?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('central')),
      body: Row(
        children: [
          Expanded(
            child: ListView.builder(
              itemBuilder: (context, index) {
                final data = dataList[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(data.toString()),
                );
              },
              itemCount: dataList.length,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('blueState: $blueState'),
                        Text('connectedDevice: ${_cMgr.connectedDevice}'),
                        TextButton(
                          onPressed: () {
                            _cMgr.scanDevice();
                          },
                          child: Text('scan device'),
                        ),
                        TextButton(
                          onPressed: () {
                            _cMgr.stopScan();
                          },
                          child: Text('stop scan'),
                        ),
                        TextButton(
                          onPressed: () {
                            _cMgr.disconnectDevice();
                          },
                          child: Text('disconnectDevice'),
                        ),
                        TextButton(
                          onPressed: writeNoResp,
                          child: Text('writeNoResp'),
                        ),
                        TextButton(onPressed: write, child: Text('write')),
                        TextButton(
                          onPressed: clearData,
                          child: Text('clear data'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _wScanDeviceList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wScanDeviceList() {
    final list = _scanResultList;
    return ListView.builder(
      itemBuilder: (context, index) {
        final displayDevice = list[index];
        return TextButton(
          onPressed: () {
            connect(displayDevice);
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(displayDevice.device.platformName),
                Text(displayDevice.version),
              ],
            ),
          ),
        );
      },
      itemCount: list.length,
    );
  }

  void connect(DisplayBluetoothDevice device) async {
    final connectResult = await _cMgr.connectDevice(device);
    if (!connectResult) return;
    print('connect success');
  }

  void writeNoResp() async {
    final test = 'helloWorld';
    final byteData = utf8.encode(test);
    setState(() {
      dataList.add('writeNoResp: $test');
    });
    await _cMgr.writeWithoutResponse(byteData);
  }

  Future<void> write() async {
    final test = 'helloWorld, plz resp me';
    final byteData = utf8.encode(test);
    setState(() {
      dataList.add('write: $test');
    });
    final respByteData = await _cMgr.write(byteData);

    final resp = utf8.decode(respByteData);
    setState(() {
      dataList.add('write receive: $resp');
    });
  }

  void receivePackets(Packets packets) {
    if (packets.opFlag == AppBluetoothProtocol.opFlagRequest) {
      final messageIndex = packets.messageIndex;
      _cMgr.respond(utf8.encode('hello this is world'), messageIndex);
    } else {
      final data = packets.getData();
      final resp = utf8.decode(data);
      setState(() {
        dataList.add('receive: $resp');
      });
    }
  }

  void clearData() {
    setState(() {
      dataList.clear();
    });
  }

  void requestPermission()async{
    List<Permission> permissions = [];
    if (SystemInfoUtil.isAndroid()) {
      permissions.addAll([Permission.location]);
    }

    await permissions.request();

    _cMgr.centralManager.requestPermission();
  }
}
