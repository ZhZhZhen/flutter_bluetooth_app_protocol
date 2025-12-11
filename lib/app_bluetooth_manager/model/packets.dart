import 'dart:collection';

import 'package:bluetooth_p/app_bluetooth_manager/app_bluetooth_protocol.dart';
import 'package:flutter/cupertino.dart';

///描述分包信息
class Packets {
  //<包序号,包数据>，因为不确定蓝牙是否会串行接收，所以使用TreeMap
  final rawDataMap = SplayTreeMap<int, List<int>>();
  final int packSize;

  Packets({required this.packSize});

  bool isComplete() {
    return rawDataMap.length >= packSize;
  }

  void add(List<int> data) {
    final packetIndex = AppBluetoothProtocol.getPacketIndex(data);
    debugPrint('Packets.add() packetIndex:$packetIndex');
    if (packetIndex == -1) return;

    rawDataMap[packetIndex] = data;
  }

  List<int> getData() {
    final rawDataList = <List<int>>[];

    for (final data in rawDataMap.values) {
      rawDataList.add(data);
    }

    return AppBluetoothProtocol.mergePackets(rawDataList);
  }
}
