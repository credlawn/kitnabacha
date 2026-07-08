import 'package:flutter/services.dart';

class ContactPicker {
  static const _channel = MethodChannel('com.credlawn.ledgeo/contact_picker');

  static Future<({String name, String phone})?> pickContact() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickContact');
      if (result == null) return null;
      final digits = (result['phone'] as String? ?? '').replaceAll(RegExp(r'[^\d]'), '');
      final phone = digits.length <= 10 ? digits : digits.substring(digits.length - 10);
      return (name: result['name'] as String? ?? '', phone: phone);
    } on PlatformException catch (_) {
      return null;
    }
  }
}
