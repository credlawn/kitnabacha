import 'package:flutter/services.dart';

class ContactPicker {
  static const _channel = MethodChannel('com.ledgeo.app/contact_picker');

  static Future<({String name, String phone})?> pickContact() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickContact');
      if (result == null) return null;
      return (name: result['name'] as String? ?? '', phone: result['phone'] as String? ?? '');
    } on PlatformException catch (_) {
      return null;
    }
  }
}
