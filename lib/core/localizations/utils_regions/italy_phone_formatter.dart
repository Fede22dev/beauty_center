import 'package:flutter/services.dart';

class ItalyPhoneFormatter extends TextInputFormatter {
  static const prefix = '+39 ';
  static const maxDigits = 10;

  @override
  TextEditingValue formatEditUpdate(
    final TextEditingValue oldValue,
    final TextEditingValue newValue,
  ) {
    var text = newValue.text;

    text = text.replaceAll(RegExp('[^0-9]'), '');

    if (text.startsWith('39')) {
      text = text.substring(2);
    }

    if (text.length > maxDigits) {
      text = text.substring(0, maxDigits);
    }

    final formatted = '$prefix$text';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
