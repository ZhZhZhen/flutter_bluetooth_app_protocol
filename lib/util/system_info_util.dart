import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SystemInfoUtil {
  SystemInfoUtil._();

  static String? _deviceVersion;
  static String? _appVersion;
  static String? _appBuildNumber;

  static const String systemTypeHTML5 = 'HTML5';
  static const String systemTypeAndroid = 'Android';
  static const String systemTypeIOS = 'iOS';
  static const String systemTypeUnknown = 'Unknown';

  static String getDeviceType() {
    if (kIsWeb) {
      return systemTypeHTML5;
    } else if (Platform.isAndroid) {
      return systemTypeAndroid;
    } else if (Platform.isIOS) {
      return systemTypeIOS;
    } else {
      return systemTypeUnknown;
    }
  }

  static bool isAndroid() {
    return getDeviceType() == systemTypeAndroid;
  }

  static bool isIOS() {
    return getDeviceType() == systemTypeIOS;
  }

  static bool isHTML5() {
    return getDeviceType() == systemTypeHTML5;
  }

  static Future<String> getDeviceVersion() async {
    var deviceVersion = _deviceVersion;
    if (deviceVersion != null && deviceVersion.isNotEmpty) {
      return deviceVersion;
    }

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String version = '';
    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      version = webInfo.userAgent ?? '';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      version = "Android ${androidInfo.version.release}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      version = "iOS ${iosInfo.systemVersion}";
    }
    deviceVersion = _deviceVersion = version;
    return deviceVersion;
  }

  static Future<String> getAppVersion() async {
    var appVersion = _appVersion;
    if (appVersion != null && appVersion.isNotEmpty) {
      return appVersion;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = _appVersion = packageInfo.version;
    return appVersion;
  }

  static Future<List<int>> getAppVersionNumber({bool fix3Size = true}) async {
    final appVersion = await getAppVersion();
    final strList = appVersion.split('.');
    final numList = strList.map((str) => int.tryParse(str) ?? 0).toList();

    if (fix3Size) {
      final num3SizeList = [0, 0, 0];
      for (int i = 0; i < min(numList.length, 3); i++) {
        num3SizeList[i] = numList[i];
      }
      return num3SizeList;
    }

    return numList;
  }

  static Future<String> getAppBuildNumber() async {
    var appBuildNumber = _appBuildNumber;
    if (appBuildNumber != null && appBuildNumber.isNotEmpty) {
      return appBuildNumber;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appBuildNumber = _appBuildNumber = packageInfo.buildNumber;
    return appBuildNumber;
  }

  static bool isNeedUpdate(String? currentVersion, String? newVersion) {
    if (newVersion == null) {
      return false;
    }
    if (currentVersion == null) {
      return true;
    }
    try {
      List<int> currentParts =
          currentVersion.split('.').map(int.parse).toList();
      List<int> newParts = newVersion.split('.').map(int.parse).toList();
      while (currentParts.length < newParts.length) {
        currentParts.add(0);
      }
      while (newParts.length < currentParts.length) {
        newParts.add(0);
      }

      // 逐级比较版本号
      for (int i = 0; i < currentParts.length; i++) {
        if (newParts[i] > currentParts[i]) {
          return true;
        } else if (newParts[i] < currentParts[i]) {
          return false;
        }
      }
    } catch (e) {
      //ignored
    }

    return false;
  }
}
