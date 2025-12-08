import 'dart:convert';

import 'package:bluetooth_p/bluetooth_manager/peripheral_manager/app_peripheral_manager.dart';
import 'package:bluetooth_p/display_client/display_peripheral_manager.dart';
import 'package:flutter/material.dart';

class PeripheralPage extends StatefulWidget {
  const PeripheralPage({super.key});

  @override
  State<PeripheralPage> createState() => _PeripheralPageState();
}

class _PeripheralPageState extends State<PeripheralPage> {
  final _dPMgr = DisplayPeripheralManager.instance;
  final _pMgr = AppPeripheralManager.instance;

  List<String> dataList = [];

  @override
  void initState() {
    super.initState();
    _pMgr.addEventListener(
      AppPeripheralManager.eventAdvertisingState,
      updateUI,
    );
    _pMgr.addEventListener(AppPeripheralManager.eventBlueState, updateUI);
    _pMgr.addEventListener(
      AppPeripheralManager.eventCentralConnectState,
      updateUI,
    );
    _pMgr.valueWriteNotifier.addListener(receiveData);
  }

  @override
  void dispose() {
    _pMgr.removeEventListener(
      AppPeripheralManager.eventAdvertisingState,
      updateUI,
    );
    _pMgr.removeEventListener(AppPeripheralManager.eventBlueState, updateUI);
    _pMgr.removeEventListener(
      AppPeripheralManager.eventCentralConnectState,
      updateUI,
    );
    _pMgr.valueWriteNotifier.removeListener(receiveData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('peripheral')),
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
                Text('blueState: ${_pMgr.blueState}'),
                Text('advertising: ${_pMgr.advertising}'),
                Text('connectCentral: ${_pMgr.connectedCentral}'),
                TextButton(
                  onPressed: () {
                    _dPMgr.startAdvertising();
                  },
                  child: Text('start Ad'),
                ),
                TextButton(
                  onPressed: () {
                    _dPMgr.stopAdvertising();
                  },
                  child: Text('stop Ad'),
                ),
                TextButton(
                  onPressed: () {
                    clearData();
                  },
                  child: Text('clear data'),
                ),
                TextButton(onPressed: write, child: Text('write something')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void updateUI() {
    setState(() {});
  }

  void receiveData() {
    final data = _pMgr.valueWriteNotifier.value;
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

  void write() async {
    final mtu = await _pMgr.maxPayloadSize;
    print('maxPayloadSize: $mtu');
    final content = 'yes i \'m world';
    final uint8ListContent = utf8.encode(content);
    _pMgr.notify(uint8ListContent);
  }
}
