import 'package:flutter/material.dart';

/// Monedas soportadas en una cesta.
enum Moneda {
  usdBcv('USD (BCV)', 'USD', Icons.attach_money, Colors.blue),
  eurBcv('EUR (BCV)', 'EUR', Icons.euro, Colors.orange),
  usdtBinance('USDT (Binance)', 'USDT', Icons.currency_bitcoin, Colors.green),
  ves('Bolívares (VES)', 'Bs', Icons.monetization_on, Colors.redAccent);

  const Moneda(this.label, this.simbolo, this.icono, this.color);

  final String label;
  final String simbolo;
  final IconData icono;
  final Color color;

  static Moneda fromName(String name) =>
      Moneda.values.firstWhere((m) => m.name == name, orElse: () => Moneda.ves);
}

/// Un producto dentro de una cesta.
class Producto {
  final String id;
  String nombre;
  double precio;
  Moneda moneda;
  double cantidad;

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.moneda,
    this.cantidad = 1,
  });

  /// Valor del producto en bolívares según las tasas dadas.
  double valorEnBs({
    required double tasaBcvUsd,
    required double tasaBcvEur,
    required double tasaBinance,
  }) {
    final double precioBs = switch (moneda) {
      Moneda.usdBcv => precio * tasaBcvUsd,
      Moneda.eurBcv => precio * tasaBcvEur,
      Moneda.usdtBinance => precio * tasaBinance,
      Moneda.ves => precio,
    };
    return precioBs * cantidad;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'moneda': moneda.name,
        'cantidad': cantidad,
      };

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        precio: (json['precio'] as num).toDouble(),
        moneda: Moneda.fromName(json['moneda'] as String),
        cantidad: (json['cantidad'] as num).toDouble(),
      );
}

/// Una cesta de compra. Al guardarse congela las tasas del momento.
class Cesta {
  final String id;
  String nombre;
  List<Producto> productos;

  /// Tasas congeladas al guardar (0 si aún no se ha guardado).
  double tasaBcvUsd;
  double tasaBcvEur;
  double tasaBinance;

  /// Fecha y hora exactas en que se guardó la cesta (null si es de trabajo).
  DateTime? fechaGuardado;

  Cesta({
    required this.id,
    required this.nombre,
    List<Producto>? productos,
    this.tasaBcvUsd = 0,
    this.tasaBcvEur = 0,
    this.tasaBinance = 0,
    this.fechaGuardado,
  }) : productos = productos ?? [];

  bool get esGuardada => fechaGuardado != null;

  /// Total de la compra en bolívares.
  double totalEnBs() {
    double total = 0;
    for (final p in productos) {
      total += p.valorEnBs(
        tasaBcvUsd: tasaBcvUsd,
        tasaBcvEur: tasaBcvEur,
        tasaBinance: tasaBinance,
      );
    }
    return total;
  }

  /// Total en una moneda específica.
  double totalEn(Moneda moneda) {
    final double bs = totalEnBs();
    return switch (moneda) {
      Moneda.usdBcv => tasaBcvUsd > 0 ? bs / tasaBcvUsd : 0,
      Moneda.eurBcv => tasaBcvEur > 0 ? bs / tasaBcvEur : 0,
      Moneda.usdtBinance => tasaBinance > 0 ? bs / tasaBinance : 0,
      Moneda.ves => bs,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'productos': productos.map((p) => p.toJson()).toList(),
        'tasaBcvUsd': tasaBcvUsd,
        'tasaBcvEur': tasaBcvEur,
        'tasaBinance': tasaBinance,
        'fechaGuardado': fechaGuardado?.toIso8601String(),
      };

  factory Cesta.fromJson(Map<String, dynamic> json) => Cesta(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        productos: (json['productos'] as List)
            .map((e) => Producto.fromJson(e as Map<String, dynamic>))
            .toList(),
        tasaBcvUsd: (json['tasaBcvUsd'] as num).toDouble(),
        tasaBcvEur: (json['tasaBcvEur'] as num).toDouble(),
        tasaBinance: (json['tasaBinance'] as num).toDouble(),
        fechaGuardado: json['fechaGuardado'] != null
            ? DateTime.tryParse(json['fechaGuardado'] as String)
            : null,
      );
}
