import 'package:flutter/cupertino.dart';

///用于屏幕设备的协议描述，包含解码和组码
class AppBluetoothProtocol {
  AppBluetoothProtocol._();

  ///协议版本号1，异或校验位1，头标识符2，行为标志位1（命令/文件/错误），总包数2
  static const int firstPacketProtocolLength = 7;

  ///异或校验位1，包索引2
  static const int laterPacketProtocolLength = 3;

  ///协议头
  static const int protocolVersion = 1;
  static const List<int> firstPacketFlag = [0xAA, 0xAA];
  static const int opFlagCommand = 1;
  static const int opFlagError = 3;

  ///分包
  static List<List<int>> convertPackets(
    List<int> data, {
    required int packetSize,
    required int opFlag,
  }) {
    final packetNum = calculatePacketNum(data, packetSize);
    if (packetNum == 1) {
      //单包
      return [_convertFirstPacket(data, opFlag: opFlag, packetNum: 1)];
    } else {
      //多包
      List<List<int>> message = [];
      final maxFirstPacketLength = packetSize - firstPacketProtocolLength;
      final maxLaterPacketLength = packetSize - laterPacketProtocolLength;
      final totalLength = data.length;
      int curByteIndex = 0;
      int curPacketIndex = 0;

      while (curByteIndex < totalLength) {
        int nextByteIndex =
            curByteIndex +
            (curPacketIndex == 0 ? maxFirstPacketLength : maxLaterPacketLength);
        if (nextByteIndex > totalLength) {
          nextByteIndex = totalLength;
        }
        debugPrint('convertPackets: $nextByteIndex / $totalLength');
        final packetData = data.sublist(curByteIndex, nextByteIndex);
        if (curPacketIndex == 0) {
          //首包
          message.add(
            _convertFirstPacket(
              packetData,
              opFlag: opFlag,
              packetNum: packetNum,
            ),
          );
          curPacketIndex++;
        } else {
          //后续包
          message.add(
            _convertLaterPacket(packetData, packetIndex: curPacketIndex++),
          );
        }
        curByteIndex = nextByteIndex;
      }
      return message;
    }
  }

  ///生成首包
  static List<int> _convertFirstPacket(
    List<int> packetData, {
    required int opFlag,
    required int packetNum,
  }) {
    List<int> resultNoCheck = [
      protocolVersion,
      ...firstPacketFlag,
      opFlag,
      ...intTo2Bytes(packetNum),
      ...packetData,
    ];
    return [calculateChecksum(resultNoCheck), ...resultNoCheck];
  }

  ///生成后续包
  static List<int> _convertLaterPacket(
    List<int> packetData, {
    required int packetIndex,
  }) {
    List<int> resultNoCheck = [...intTo2Bytes(packetIndex), ...packetData];
    return [calculateChecksum(resultNoCheck), ...resultNoCheck];
  }

  ///大端序，int和bytes(长度2)互相转换
  static List<int> intTo2Bytes(int value) {
    return [(value >> 8) & 0xFF, value & 0xFF];
  }

  static int bytes2ToInt(List<int> bytes) {
    return (bytes[0] << 8) | bytes[1];
  }

  ///异或求校验位
  static int calculateChecksum(List<int> data) {
    int checksum = 0;
    for (var byte in data) {
      checksum ^= byte;
    }
    return checksum & 0xFF;
  }

  ///求包数
  static int calculatePacketNum(List<int> data, int packetSize) {
    final totalLength = data.length;
    final maxFirstPacketLength = packetSize - firstPacketProtocolLength;
    final maxLaterPacketLength = packetSize - laterPacketProtocolLength;

    if (totalLength <= maxFirstPacketLength) {
      //单包
      return 1;
    } else {
      //多包
      final leftLength = totalLength - maxFirstPacketLength;
      final leftPacketNum =
          (leftLength + maxLaterPacketLength - 1) ~/ maxLaterPacketLength;
      return leftPacketNum + 1;
    }
  }

  static List<int> mergePackets(List<List<int>> packets) {
    if (packets.isEmpty) return [];

    List<int> message = [];
    message.addAll(mergeFirstPacket(packets[0]));
    for (int i = 1; i < packets.length; i++) {
      message.addAll(mergeLaterPacket(packets[i]));
    }
    return message;
  }

  static List<int> mergeFirstPacket(List<int> packet) {
    return packet.sublist(firstPacketProtocolLength);
  }

  static List<int> mergeLaterPacket(List<int> packet) {
    return packet.sublist(laterPacketProtocolLength);
  }

  ///验证包的有效性，校验位位于第[0]位
  static bool validatePacket(List<int> data) {
    if (data.length < 2) return false; //至少有两位才有校验位，和可校验内容
    final checksum = data[0];
    final message = data.sublist(1);
    return checksum == calculateChecksum(message);
  }

  ///firstPacketFlag位于首包的[2,4)位置
  static bool isFirstPacket(List<int> data) {
    if (data.length < 4) return false;
    final maybeFlag = data.sublist(2, 4);
    return maybeFlag[0] == firstPacketFlag[0] &&
        maybeFlag[1] == firstPacketFlag[1];
  }

  ///动作标志位位于首包的第[4]位
  static int getOpFlag(List<int> data) {
    if (!isFirstPacket(data)) return -1;
    if (data.length < 5) return -1;
    return data[4];
  }

  ///包总数位于首包的[5,7)位置
  static int getPacketsNum(List<int> data) {
    if (!isFirstPacket(data)) return -1;
    final packetsNumBytes = data.sublist(5, 7);
    return bytes2ToInt(packetsNumBytes);
  }

  ///包索引位于后续包的[1,3)位置
  static int getPacketIndex(List<int> data) {
    if (isFirstPacket(data)) return 0;
    if (data.length < 4) return -1;
    return bytes2ToInt(data.sublist(1, 3));
  }
}
