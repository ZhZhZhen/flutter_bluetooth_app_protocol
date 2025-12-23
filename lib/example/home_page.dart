import 'package:bluetooth_p/example/peripheral_page.dart';
import 'package:flutter/material.dart';
import 'package:synchronized/synchronized.dart';

import 'central_page.dart';

///TODO 请求权限，出错校验回复，由应用层来处理
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
            Row(
              children: [
                TextButton(onPressed: test1, child: Text('test1')),
                TextButton(onPressed: test2, child: Text('test2')),
              ],
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

  //所以要实现严格的重入锁，必须等待执行
  Future<void> test1() async {
    await _testLock.synchronized(() async {
      print('zztest 11');
       _testLock.synchronized(() async {
        print('zztest 21');
        await Future.delayed(Duration(seconds: 1));
        print('zztest 22');
      });
      print('zztest 12');
    });

    _testLock.synchronized(() async {
      print('zztest 3');
    });
  }

  Future<void> test2() async {
    print('zztest 3');
    print('${_testLock.locked} ${_testLock.canLock} ${_testLock.inLock}');

    _testLock.synchronized(() async {
      print('zztest 4');
      print('${_testLock.locked} ${_testLock.canLock} ${_testLock.inLock}');
    });
  }
}
