import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cesta.dart';

/// Servicio de persistencia de cestas en `SharedPreferences`.
class CestaService {
  static const String _kCestasKey = 'cestas_v1';

  /// Carga todas las cestas guardadas.
  static Future<List<Cesta>> cargarCestas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCestasKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => Cesta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Persiste la lista completa de cestas.
  static Future<void> guardarCestas(List<Cesta> cestas) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(cestas.map((c) => c.toJson()).toList());
    await prefs.setString(_kCestasKey, raw);
  }

  /// Guarda (crea o actualiza) una cesta en la lista.
  static Future<void> guardarCesta(Cesta cesta) async {
    final cestas = await cargarCestas();
    final idx = cestas.indexWhere((c) => c.id == cesta.id);
    if (idx >= 0) {
      cestas[idx] = cesta;
    } else {
      cestas.add(cesta);
    }
    await guardarCestas(cestas);
  }

  /// Elimina una cesta por id.
  static Future<void> eliminarCesta(String id) async {
    final cestas = await cargarCestas();
    cestas.removeWhere((c) => c.id == id);
    await guardarCestas(cestas);
  }

  /// Renombra una cesta por id.
  static Future<void> renombrarCesta(String id, String nombre) async {
    final cestas = await cargarCestas();
    final idx = cestas.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      cestas[idx].nombre = nombre;
      await guardarCestas(cestas);
    }
  }
}
