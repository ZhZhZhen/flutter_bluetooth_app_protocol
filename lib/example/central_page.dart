import 'dart:async';

import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_central_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_bluetooth_manager/model/display_bluetooth_device.dart';

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

  @override
  void initState() {
    super.initState();
    _cMgr.centralManager.requestPermission();
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

    _cMgr.commandDispatcher.addListener(receiveData);
  }

  @override
  void dispose() {
    _bluetoothStateSubs?.cancel();
    _scanDeviceSubs?.cancel();
    _connectedDeviceSubs?.cancel();
    _cMgr.commandDispatcher.removeListener(receiveData);
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
                          onPressed: write,
                          child: Text('write something'),
                        ),
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

  void write() {
    _cMgr.write(commandFlag: 'method1', value: 'value1');
  }

  void updateUI() {
    setState(() {});
  }

  void receiveData(String commandFlag, String value) {
    print('zztest commandFlag:$commandFlag value:$value');
  }

  void clearData() {
    setState(() {
      dataList.clear();
    });
  }
}
