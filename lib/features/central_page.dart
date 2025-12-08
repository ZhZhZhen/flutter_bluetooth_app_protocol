import 'dart:convert';

import 'package:bluetooth_p/bluetooth_manager/central_manager/app_central_manager.dart';
import 'package:bluetooth_p/display_client/display_client_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class CentralPage extends StatefulWidget {
  const CentralPage({super.key});

  @override
  State<CentralPage> createState() => _CentralPageState();
}

class _CentralPageState extends State<CentralPage> {
  final _cMgr = AppCentralManager.instance;

  List<ScanResult> _scanResultList = [];

  List<String> dataList = [];

  @override
  void initState() {
    super.initState();
    _cMgr.addEventListener(AppCentralManager.eventBlueState, updateUI);
    _cMgr.addEventListener(AppCentralManager.eventDeviceConnectState, updateUI);
    _cMgr.addEventListener(
      AppCentralManager.eventScanResult,
      updateScanResultList,
    );
    _cMgr.valueReceiveNotifier.addListener(receiveData);
  }

  @override
  void dispose() {
    _cMgr.removeEventListener(AppCentralManager.eventBlueState, updateUI);
    _cMgr.removeEventListener(
      AppCentralManager.eventDeviceConnectState,
      updateUI,
    );
    _cMgr.removeEventListener(
      AppCentralManager.eventScanResult,
      updateScanResultList,
    );
    _cMgr.valueReceiveNotifier.removeListener(receiveData);
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
                        Text('blueState: ${_cMgr.blueState}'),
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
        final result = list[index];
        final device = result.device;
        final mData = result.advertisementData.manufacturerData;
        final version = (mData[DisplayClientConstant.manufacturerDataVersion] ??
                [-1])
            .join('.');

        return TextButton(
          onPressed: () {
            connect(device);
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [Text(device.platformName), Text(version)]),
          ),
        );
      },
      itemCount: list.length,
    );
  }

  void connect(BluetoothDevice device) async {
    final connectResult = await _cMgr.connectDevice(device);
    if (!connectResult) return;
    print('zztest connect success');
  }

  void write() {
    print('maxPayloadSize: ${_cMgr.maxPayloadSize}');
    final content = 'hello world';
    final uint8ListContent = utf8.encode(content);
    _cMgr.write(uint8ListContent);
  }

  void updateUI() {
    setState(() {});
  }

  void updateScanResultList() {
    final result = _cMgr.scanResult;
    setState(() {
      _scanResultList = result;
    });
  }

  void receiveData() {
    final data = _cMgr.valueReceiveNotifier.value;
    final content = utf8.decode(data);
    setState(() {
      dataList.add(data.toString());
      dataList.add(content);
    });
  }

  void clearData() {
    setState(() {
      dataList.clear();
    });
  }
}
