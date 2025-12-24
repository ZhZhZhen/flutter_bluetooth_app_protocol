import 'dart:async';

import 'package:bluetooth_p/app_bluetooth_manager/model/packets.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronized/synchronized.dart';

///用于屏幕设备的协议描述，包含解码和组码
class AppBluetoothProtocol {
  ///协议版本号1，异或校验位1，头标识符2，动作标志位1，消息序号1，总包数2
  static const int firstPacketProtocolLength = 8;

  ///异或校验位1，包索引2
  static const int laterPacketProtocolLength = 3;

  ///协议头
  static const int protocolVersion = 1;
  static const List<int> firstPacketFlag = [0xAA, 0xAA];

  ///协议头中的动作标识符
  static const int opFlagRequestWithoutResponse = 1;
  static const int opFlagRequest = 2;
  static const int opFlagResponse = 3;
  static const int opFlagError = 4;

  final _writeLock = Lock(); //用于串行写入
  int circleMessageIndex = 0; //消息序号，0~255循环使用

  //请求的消息序号是递增的，
  Packets? _packets;
  final Map<int, Completer<Packets>> _respCompleterByMsgIndex = {};

  int _getSendMessageIndex() {
    return (circleMessageIndex++) % 256;
  }

  ///带返回写入，用于带返回请求
  Future<List<int>> writeWithResponse({
    required List<int> data,
    required int maxPacketSize,
    required Function(List<int> packet) onWrite,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return await _writeLock.synchronized(() async {
      final messageIndex = _getSendMessageIndex();
      //发送
      final respCompleter = Completer<Packets>();
      _respCompleterByMsgIndex[messageIndex] = respCompleter;
      final packets = convertPackets(
        data,
        packetSize: maxPacketSize,
        opFlag: opFlagRequest,
        messageIndex: messageIndex,
      );
      await _write(packets: packets, onWrite: onWrite);

      //等待结果
      try {
        final responsePackets = await respCompleter.future.timeout(timeout);
        return responsePackets.getData();
      } catch (e) {
        if (!respCompleter.isCompleted) {
          respCompleter.completeError(e);
        }
        rethrow;
      } finally {
        _respCompleterByMsgIndex.remove(messageIndex);
      }
    });
  }

  ///无返回写入，用于无返回请求/响应成功/响应错误，响应时需传入收到请求的序号
  Future<void> writeWithoutResponse({
    required List<int> data,
    required int maxPacketSize,
    int opFlag = opFlagRequestWithoutResponse,
    int? messageIndex,
    required Function(List<int> packet) onWrite,
  }) async {
    await _writeLock.synchronized(() async {
      final packets = convertPackets(
        data,
        packetSize: maxPacketSize,
        opFlag: opFlag,
        messageIndex: messageIndex ?? _getSendMessageIndex(),
      );
      await _write(packets: packets, onWrite: onWrite);
    });
  }

  Future<void> _write({
    required List<List<int>> packets,
    required Function(List<int> packet) onWrite,
  }) async {
    //首包后延时确保第一包能首先收到，整个命令发送后延时确保不和下一个命令重叠，虽然不知道这样做有没有用
    bool firstSend = true;
    for (final packet in packets) {
      await onWrite(packet);
      if (firstSend) {
        firstSend = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  ///处理接收
  Future<void> receive({
    required List<int> data,
    required PacketsCallback packetsCallback,
  }) async {
    //校验包
    if (!validatePacket(data)) return;

    //组合包
    final isFirstPacket = AppBluetoothProtocol.isFirstPacket(data);
    if (isFirstPacket) {
      final packets = Packets(
        opFlag: getOpFlag(data),
        messageIndex: getMessageIndex(data),
        packSize: getPacketsNum(data),
      );
      packets.add(data);
      _packets = packets;
    } else {
      final packets = _packets;
      if (packets == null) return;
      packets.add(data);
    }

    //检查包是否组合完成
    final packets = _packets;
    if (packets == null) return;
    if (packets.isComplete()) {
      try {
        int opFlag = packets.opFlag;
        switch (opFlag) {
          case opFlagResponse:
            {
              final respCompleter =
                  _respCompleterByMsgIndex[packets.messageIndex];
              if (respCompleter != null && !respCompleter.isCompleted) {
                respCompleter.complete(packets);
              }
              break;
            }
          case opFlagError:
            {
              final respCompleter =
                  _respCompleterByMsgIndex[packets.messageIndex];
              if (respCompleter != null && !respCompleter.isCompleted) {
                respCompleter.completeError(Exception('error'));
              }
              break;
            }
          case opFlagRequest:
          case opFlagRequestWithoutResponse:
            {
              packetsCallback.call(packets);
              break;
            }
        }
      } catch (_) {}
    }
  }

  ///分包
  static List<List<int>> convertPackets(
    List<int> data, {
    required int packetSize,
    required int opFlag,
    required int messageIndex,
  }) {
    final packetNum = calculatePacketNum(data, packetSize);
    if (packetNum == 1) {
      //单包
      return [
        _convertFirstPacket(
          data,
          opFlag: opFlag,
          messageIndex: messageIndex,
          packetNum: 1,
        ),
      ];
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
              messageIndex: messageIndex,
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
    required int messageIndex,
    required int packetNum,
  }) {
    List<int> resultNoCheck = [
      protocolVersion,
      ...firstPacketFlag,
      opFlag,
      messageIndex,
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

  ///协议版本号位于第[1]位
  static int getProtocolVersion(List<int> data) {
    if (!isFirstPacket(data)) return -1;
    if (data.length < 2) return -1;
    return data[1];
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

  ///消息序号位于首包的第[5]位
  static int getMessageIndex(List<int> data) {
    if (!isFirstPacket(data)) return -1;
    if (data.length < 6) return -1;
    return data[5];
  }

  ///包总数位于首包的[6,8)位置
  static int getPacketsNum(List<int> data) {
    if (!isFirstPacket(data)) return -1;
    if (data.length < 8) return -1;
    return bytes2ToInt(data.sublist(6, 8));
  }

  ///包索引位于后续包的[1,3)位置
  static int getPacketIndex(List<int> data) {
    if (isFirstPacket(data)) return 0;
    if (data.length < 3) return -1;
    return bytes2ToInt(data.sublist(1, 3));
  }
}

typedef PacketsCallback = void Function(Packets packets);
