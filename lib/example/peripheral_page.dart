import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_peripheral_manager.dart';
import 'package:bluetooth_p/util/no_use_util.dart';
import 'package:flutter/material.dart';

class PeripheralPage extends StatefulWidget {
  const PeripheralPage({super.key});

  @override
  State<PeripheralPage> createState() => _PeripheralPageState();
}

class _PeripheralPageState extends State<PeripheralPage> {
  final _pMgr = AppBluetoothPeripheralManager.instance;

  List<String> dataList = [];

  StreamSubscription? _advertisingSubs;

  BluetoothLowEnergyState? _bluetoothState;
  StreamSubscription? _bluetoothStateSubs;

  StreamSubscription? connectedCentralSubs;

  @override
  void initState() {
    super.initState();
    final aPMgr = _pMgr;
    final pMgr = aPMgr.peripheralManager;
    pMgr.requestPermission();
    _advertisingSubs?.cancel();
    _advertisingSubs = pMgr.advertisingStream.listen((advertising) {
      setState(() {});
    });

    _bluetoothStateSubs?.cancel();
    _bluetoothStateSubs = pMgr.bluetoothStateStream.listen((state) {
      _bluetoothState = state;
      setState(() {});
    });

    connectedCentralSubs?.cancel();
    connectedCentralSubs = pMgr.connectedCentralStream.listen((central) {
      setState(() {});
    });

    _pMgr.commandDispatcher.addListener(receiveData);
  }

  @override
  void dispose() {
    _advertisingSubs?.cancel();
    _bluetoothStateSubs?.cancel();
    connectedCentralSubs?.cancel();
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
                  Text('blueState: $_bluetoothState'),
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
