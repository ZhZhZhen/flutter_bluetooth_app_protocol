import 'dart:async';
import 'dart:convert';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_peripheral_manager.dart';
import 'package:flutter/material.dart';

import '../app_bluetooth_manager/app_bluetooth_protocol.dart';
import '../app_bluetooth_manager/model/packets.dart';

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

  StreamSubscription? _receivePacketsSubs;

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

    _receivePacketsSubs?.cancel();
    _receivePacketsSubs = aPMgr.receivePacketsStream.listen((packets) {
      receivePackets(packets);
    });
  }

  @override
  void dispose() {
    _advertisingSubs?.cancel();
    _bluetoothStateSubs?.cancel();
    connectedCentralSubs?.cancel();
    _receivePacketsSubs?.cancel();
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
                  TextButton(
                    onPressed: writeNoResp,
                    child: Text('writeNoResp'),
                  ),
                  TextButton(onPressed: write, child: Text('write')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void clearData() {
    setState(() {
      dataList.clear();
    });
  }

  void writeNoResp() async{
    final test = 'helloWorld';
    final byteData = utf8.encode(test);
    setState(() {
      dataList.add('writeNoResp: $test');
    });
    await _pMgr.writeWithoutResponse(byteData);
  }

  Future<void> write() async {
    final test = 'helloWorld, plz resp me';
    final byteData = utf8.encode(test);
    setState(() {
      dataList.add('write: $test');
    });
    final respByteData = await _pMgr.write(byteData);

    final resp = utf8.decode(respByteData);
    setState(() {
      dataList.add('write receive: $resp');
    });
  }

  void receivePackets(Packets packets) {
    if (packets.opFlag == AppBluetoothProtocol.opFlagRequest) {
      final messageIndex = packets.messageIndex;
      _pMgr.respond(utf8.encode('hello this is world'), messageIndex);
    } else {
      final data = packets.getData();
      final resp = utf8.decode(data);
      setState(() {
        dataList.add('receive: $resp');
      });
    }
  }
}
