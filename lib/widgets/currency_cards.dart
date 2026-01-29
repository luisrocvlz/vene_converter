import 'package:flutter/material.dart';

class InfoTasa extends StatelessWidget {
  final String label, date;
  final double value, cambio;
  final Color color;

  const InfoTasa({super.key, required this.label, required this.value, required this.cambio, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    Color colorCambio = Colors.grey;
    IconData iconoCambio = Icons.remove;

    if (cambio > 0) {
      colorCambio = Colors.green;
      iconoCambio = Icons.arrow_upward_rounded;
    } else if (cambio < 0) {
      colorCambio = Colors.red;
      iconoCambio = Icons.arrow_downward_rounded;
    }

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value > 0 ? value.toStringAsFixed(2) : "--", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cambio != 0) Icon(iconoCambio, size: 12, color: colorCambio),
            Text(cambio == 0 ? "-" : "${cambio.abs().toStringAsFixed(2)}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorCambio)),
          ],
        ),
        Text(date, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

class ComparativaItem extends StatelessWidget {
  final String titulo;
  final double valorBase, valorAlto, diferenciaBs, diferenciaPorc;

  const ComparativaItem({super.key, required this.titulo, required this.valorBase, required this.valorAlto, required this.diferenciaBs, required this.diferenciaPorc});

  @override
  Widget build(BuildContext context) {
    bool isPositive = diferenciaBs >= 0;
    Color color = isPositive ? Colors.redAccent : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Diferencia en Bs", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                Text("${isPositive ? '+' : ''}${diferenciaBs.toStringAsFixed(2)} Bs", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
              child: Text("${diferenciaPorc.toStringAsFixed(2)}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            )
          ],
        ),
      ],
    );
  }
}