import 'package:bluetooth_p/example/peripheral_page.dart';
import 'package:flutter/material.dart';
import 'package:synchronized/synchronized.dart';

import 'central_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _controller = PageController();

  final _testLock = Lock(reentrant: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
}
