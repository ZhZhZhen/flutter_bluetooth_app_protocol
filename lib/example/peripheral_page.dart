import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_peripheral_manager.dart';
import 'package:bluetooth_p/util/no_use_util.dart';
import 'package:flutter/material.dart';

import '../bluetooth_manager/bluetooth_peripheral_manager.dart';

class PeripheralPage extends StatefulWidget {
  const PeripheralPage({super.key});

  @override
  State<PeripheralPage> createState() => _PeripheralPageState();
}

class _PeripheralPageState extends State<PeripheralPage> {
  final _pMgr = AppBluetoothPeripheralManager.instance;

  List<String> dataList = [];

  @override
  void initState() {
    super.initState();
    _pMgr.peripheralManager.addEventListener(
      BluetoothPeripheralManager.eventAdvertisingState,
      updateUI,
    );
    _pMgr.peripheralManager.addEventListener(
      BluetoothPeripheralManager.eventBlueState,
      updateUI,
    );
    _pMgr.peripheralManager.addEventListener(
      BluetoothPeripheralManager.eventCentralConnectState,
      updateUI,
    );
    _pMgr.commandDispatcher.addListener(receiveData);
  }

  @override
  void dispose() {
    _pMgr.peripheralManager.removeEventListener(
      BluetoothPeripheralManager.eventAdvertisingState,
      updateUI,
    );
    _pMgr.peripheralManager.removeEventListener(
      BluetoothPeripheralManager.eventBlueState,
      updateUI,
    );
    _pMgr.peripheralManager.removeEventListener(
      BluetoothPeripheralManager.eventCentralConnectState,
      updateUI,
    );
    _pMgr.commandDispatcher.removeListener(receiveData);
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('blueState: ${_pMgr.peripheralManager.blueState}'),
                  Text('advertising: ${_pMgr.peripheralManager.advertising}'),
                  Text(
                    'connectCentral: ${_pMgr.peripheralManager.connectedCentral}',
                  ),
                  TextButton(
                    onPressed: () {
                      _pMgr.startAdvertising();
                    },
                    child: Text('start Ad'),
                  ),
                  TextButton(
                    onPressed: () {
                      _pMgr.stopAdvertising();
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
          ),
        ],
      ),
    );
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

  void write() async {
    _pMgr.write('method1', NoUseUtil.testMessage);
  }
}
