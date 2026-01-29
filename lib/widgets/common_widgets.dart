import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// El Reloj
class RelojDigital extends StatelessWidget {
  const RelojDigital({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final nowLocal = DateTime.now();
        final nowVzla = nowLocal.toUtc().subtract(const Duration(hours: 4));
        final formatoFecha = DateFormat('EEEE, d MMMM', 'es_VE');
        final formatoHora = DateFormat('hh:mm:ss a');
        String textoHoraVzla = formatoHora.format(nowVzla);
        String textoHoraLocal = formatoHora.format(nowLocal);
        final bool mostrarLocal = (textoHoraVzla != textoHoraLocal);

        return Column(
          children: [
            Text(
              formatoFecha.format(nowVzla).toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.outline),
            ),
            Text(
              textoHoraVzla,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Theme.of(context).colorScheme.primary),
            ),
            if (mostrarLocal) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public, size: 10, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    Text("Tu hora local: $textoHoraLocal", style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              )
            ]
          ],
        );
      },
    );
  }
}

// La Leyenda del gráfico (Puntitos de colores)
class Leyenda extends StatelessWidget {
  final Color color;
  final String text;
  const Leyenda({super.key, required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}