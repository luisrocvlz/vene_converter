import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/formatters.dart'; // Importamos el formateador

class CurrencyInput extends StatelessWidget {
  final TextEditingController controller;
  final String label, currency;
  final IconData icon;
  final Color color;
  final Function(String) onChanged;
  final VoidCallback onCopy;
  final bool isBold;

  const CurrencyInput({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    required this.onChanged,
    required this.onCopy,
    this.isBold = false,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [LengthLimitingTextInputFormatter(18), CurrencyPtFormatter()],
      style: TextStyle(fontSize: isBold ? 26 : 18, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      cursorColor: color,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        suffixIcon: IconButton(icon: Icon(Icons.copy_rounded, size: 20), color: color.withOpacity(0.7), tooltip: "Copiar $currency", onPressed: onCopy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
        filled: true,
      ),
    );
  }
}