import 'package:flutter/cupertino.dart';

///用于屏幕设备的协议描述，包含解码和组码
class DisplayProtocol {
  DisplayProtocol._();

  ///协议版本号1，异或校验位1，标志位1（命令/文件/错误），总包数2
  static const int firstPacketProtocolLength = 5;

  ///异或校验位1，包索引2
  static const int laterPacketProtocolLength = 3;
  static const int firstPacketIndex = 2;

  ///协议头
  static const int protocolVersion = 1;
  static const int flagCommand = 1;

  ///分包
  static List<List<int>> convertPackets(
    List<int> data, {
    required int packetSize,
    required int flag,
  }) {
    final packetNum = calculatePacketNum(data, packetSize);
    if (packetNum == 1) {
      //单包
      return [_convertFirstPacket(data, flag: flag, packetNum: 1)];
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
            _convertFirstPacket(packetData, flag: flag, packetNum: packetNum),
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
    required int flag,
    required int packetNum,
  }) {
    List<int> resultNoCheck = [flag, ...intTo2Bytes(packetNum), ...packetData];
    return [
      protocolVersion,
      calculateChecksum(resultNoCheck),
      ...resultNoCheck,
    ];
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

  ///组包，校验出错时会抛出错误，
  ///外层需要拿到包总数，和包索引，才能生成map，并且知道要接受多少数据
  static List<int> mergePackets(
    List<List<int>> packets, {
    required int packetSize,
  }) {
    if (packets.isEmpty) return [];

    List<int> message = [];
    message.addAll(mergeFirstPacket(packets[0]));
    for (int i = 1; i < packets.length; i++) {
      message.addAll(mergeLaterPacket(packets[i]));
    }
    return message;
  }

  static List<int> mergeFirstPacket(List<int> packet) {
    return packet.sublist(5);
  }

  static List<int> mergeLaterPacket(List<int> packet) {
    return packet.sublist(3);
  }
}
