import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyPtFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    if (n.text.isEmpty) return n;
    double val = (double.tryParse(n.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0) / 100;
    String newText = NumberFormat.currency(locale: 'es_VE', symbol: '').format(val).trim();
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}