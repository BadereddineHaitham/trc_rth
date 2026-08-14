import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _timer;
  String _deviceId = '';
  String _role = 'Admin';
  String _userName = 'Utilisateur';

  Future<void> startPresence({required String role, String userName = 'Utilisateur'}) async {
    _role = role;
    _userName = userName;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('app_device_presence_id') ?? '';
    if (_deviceId.isEmpty) {
      _deviceId =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}';
      await prefs.setString('app_device_presence_id', _deviceId);
    }

    _ping();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _ping());
  }

  void _ping() {
    if (_deviceId.isEmpty) return;
    SupabaseService.instance.pingPresence(
      deviceId: _deviceId,
      role: _role,
      userName: _userName,
    );
  }

  void stopPresence() {
    _timer?.cancel();
    _timer = null;
  }
}
