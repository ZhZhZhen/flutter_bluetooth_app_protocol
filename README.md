# flutter_bluetooth_app_protocol

用于封装蓝牙调用，并在此之上封装应用层协议

## 说明

- 外围设备使用bluetooth_low_energy实现，因为公司设备不支持多广播，所以修改了库的代码，改变了判断蓝牙是否可用的方式
- 中心设备使用flutter_blue_plus实现，因为公司另一个sdk使用此库做中心设备处理，所以同步使用该库
