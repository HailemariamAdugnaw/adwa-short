import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/device.dart';

enum DeviceStatus { idle, loading, success, error }

class DeviceProvider extends ChangeNotifier {
  DeviceProvider(this._api, this.currentDeviceId);

  final ApiClient _api;
  final String? currentDeviceId;

  DeviceStatus _status = DeviceStatus.idle;
  List<Device> _devices = [];
  String? _errorMessage;

  DeviceStatus get status => _status;
  List<Device> get devices => _devices;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _status = DeviceStatus.loading;
    notifyListeners();
    try {
      final List<Device> list = await _api.get<List<Device>>(
        ApiConstants.devices,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => Device.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['items'] is List) {
            return (json['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => Device.fromJson(e))
                .toList();
          }
          return <Device>[];
        },
      );
      _devices = list.map((Device d) {
        if (currentDeviceId != null && d.id == currentDeviceId) {
          return Device(
            id: d.id,
            name: d.name,
            platform: d.platform,
            lastActiveAt: d.lastActiveAt,
            isCurrent: true,
            location: d.location,
          );
        }
        return d;
      }).toList();
      _status = DeviceStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = DeviceStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DeviceStatus.error;
    }
    notifyListeners();
  }

  Future<bool> revoke(String id) async {
    try {
      await _api.delete(
        ApiConstants.deviceById(id),
        parser: (j) => j,
      );
      _devices = _devices.where((d) => d.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('revoke failed: $e');
      return false;
    }
  }
}
