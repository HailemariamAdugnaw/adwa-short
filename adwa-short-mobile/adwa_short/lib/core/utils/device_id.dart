import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

class DeviceIdProvider {
  DeviceIdProvider(this._prefs);

  final SharedPreferences _prefs;

  Future<String> getDeviceId() async {
    final existing = _prefs.getString(ApiConstants.storageDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = await _generateId();
    await _prefs.setString(ApiConstants.storageDeviceId, id);
    return id;
  }

  Future<String> _generateId() async {
    final info = DeviceInfoPlugin();
    String seed;
    try {
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        seed = '${d.brand}-${d.model}-${d.id}-${d.manufacturer}';
      } else if (Platform.isIOS) {
        final d = await info.iosInfo;
        seed = '${d.name}-${d.systemName}-${d.systemVersion}';
      } else if (Platform.isLinux) {
        final d = await info.linuxInfo;
        seed = '${d.name}-${d.version}-${d.prettyName}';
      } else if (Platform.isMacOS) {
        final d = await info.macOsInfo;
        seed = '${d.model}-${d.hostName}-${d.osRelease}';
      } else if (Platform.isWindows) {
        final d = await info.windowsInfo;
        seed = 'windows-${d.deviceId}';
      } else {
        seed = 'unknown-${DateTime.now().microsecondsSinceEpoch}';
      }
    } catch (_) {
      seed = 'fallback-${DateTime.now().microsecondsSinceEpoch}';
    }

    final random = Random.secure();
    final randomPart = base64Url
        .encode(List<int>.generate(12, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    return 'adwa-${seed.hashCode.toRadixString(16)}-$randomPart';
  }
}
