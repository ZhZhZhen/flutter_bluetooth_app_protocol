import 'dart:convert';

import 'package:bluetooth_p/display_client/display_protocol.dart';
import 'package:bluetooth_p/features/central_page.dart';
import 'package:bluetooth_p/features/peripheral_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TextButton(
              onPressed: () {
                print('zztest');
                test();
              },
              child: Text('test'),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                children: [CentralPage(), PeripheralPage()],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          _controller.jumpToPage(index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Central'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Peripheral',
          ),
        ],
      ),
    );
  }

  void test() {
    final testStr =
        '1、只有Android支持长读取，iOS不行。所以需要自定义数据协议，并校验收发完整。一般自定义最前几位的数据，然后校验接受流的前几位和长度';
    final packetSize = 20;
    final packets = DisplayProtocol.convertPackets(
      utf8.encode(testStr),
      packetSize: packetSize,
      flag: 1,
    );
    print(packets);
    final message = DisplayProtocol.mergePackets(
      packets,
      packetSize: packetSize,
    );
    final result = utf8.decode(message);
    print('zztest: $result');
  }
}
