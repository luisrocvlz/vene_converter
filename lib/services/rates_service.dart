import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

/// Fecha a partir de la cual la tasa USDT histórica se toma de
/// `ve.dolarapi.com/v1/historicos/dolares` (fuente "paralelo") en lugar del
/// `assets/history.json` local.
final DateTime kUsdtCutover = DateTime(2026, 3, 1);

/// Claves versionadas para forzar re-sincronización al actualizar la app.
const String _kBcvSyncKey = 'last_sync_bcv_history_v7';
const String _kUsdtSyncKey = 'last_sync_usdt_history_v7';

const String _kAndroidWidgetName = 'RatesWidgetProvider';

class RatesSnapshot {
  double tasaBcvUsd;
  double tasaBcvEur;
  double tasaBinance;
  double cambioBcvUsd;
  double cambioBcvEur;
  double cambioBinance;
  String fechaBcv;
  String fechaBinance;

  RatesSnapshot({
    this.tasaBcvUsd = 0,
    this.tasaBcvEur = 0,
    this.tasaBinance = 0,
    this.cambioBcvUsd = 0,
    this.cambioBcvEur = 0,
    this.cambioBinance = 0,
    this.fechaBcv = '--:--',
    this.fechaBinance = '--:--',
  });

  factory RatesSnapshot.fromCache(SharedPreferences prefs) => RatesSnapshot(
    tasaBcvUsd: prefs.getDouble('last_val_bcv_usd') ?? 0,
    tasaBcvEur: prefs.getDouble('last_val_bcv_eur') ?? 0,
    tasaBinance: prefs.getDouble('last_val_binance') ?? 0,
    cambioBcvUsd: prefs.getDouble('last_change_bcv_usd') ?? 0,
    cambioBcvEur: prefs.getDouble('last_change_bcv_eur') ?? 0,
    cambioBinance: prefs.getDouble('last_change_binance') ?? 0,
    fechaBcv: prefs.getString('last_date_bcv') ?? '--/--',
    fechaBinance: prefs.getString('last_date_binance') ?? '--:--',
  );
}

class RatesService {
  static const Map<String, String> _commonHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  /// Obtiene las tasas en vivo (BCV vía dolarapi, USDT vía Binance P2P con
  /// fallback a dolarapi/paralelo). Persiste resultados en `SharedPreferences`.
  static Future<RatesSnapshot> fetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    final snap = RatesSnapshot.fromCache(prefs);

    await _fetchBcv(prefs, snap);
    await _fetchUsdt(prefs, snap);

    return snap;
  }

  // ── BCV (Plan A: dolarapi, Plan B: cache) ─────────────────────────────────
  static Future<void> _fetchBcv(
    SharedPreferences prefs,
    RatesSnapshot snap,
  ) async {
    try {
      final respUsd = await http
          .get(
            Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'),
            headers: _commonHeaders,
          )
          .timeout(const Duration(seconds: 15));
      final respEur = await http
          .get(
            Uri.parse('https://ve.dolarapi.com/v1/euros/oficial'),
            headers: _commonHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (respUsd.statusCode != 200) {
        throw Exception('BCV USD HTTP ${respUsd.statusCode}');
      }

      final dataUsd = jsonDecode(respUsd.body);
      final double tempBcvUsd = double.parse(dataUsd['promedio'].toString());
      final double tempBcvEur = (respEur.statusCode == 200)
          ? double.parse(jsonDecode(respEur.body)['promedio'].toString())
          : tempBcvUsd * 1.09;

      // Recalcular % cambio contra el último valor cacheado.
      final double lastUsd = prefs.getDouble('last_val_bcv_usd') ?? tempBcvUsd;
      final double lastEur = prefs.getDouble('last_val_bcv_eur') ?? tempBcvEur;
      double cambioUsd = 0;
      double cambioEur = 0;
      if (lastUsd > 0 && tempBcvUsd != lastUsd) {
        cambioUsd = ((tempBcvUsd - lastUsd) / lastUsd) * 100;
      } else {
        cambioUsd = prefs.getDouble('last_change_bcv_usd') ?? 0;
      }
      if (lastEur > 0 && tempBcvEur != lastEur) {
        cambioEur = ((tempBcvEur - lastEur) / lastEur) * 100;
      } else {
        cambioEur = prefs.getDouble('last_change_bcv_eur') ?? 0;
      }

      // Formato fecha.
      String fechaBcv;
      try {
        final raw = (dataUsd['fechaActualizacion'] ?? '').toString();
        if (raw.isEmpty) {
          fechaBcv = DateFormat('dd/MM').format(DateTime.now());
        } else {
          final dateApi = DateTime.parse(raw).toLocal();
          fechaBcv = DateFormat('dd/MM HH:mm').format(dateApi);
        }
      } catch (_) {
        fechaBcv = DateFormat('dd/MM').format(DateTime.now());
      }

      snap
        ..tasaBcvUsd = tempBcvUsd
        ..tasaBcvEur = tempBcvEur
        ..cambioBcvUsd = cambioUsd
        ..cambioBcvEur = cambioEur
        ..fechaBcv = fechaBcv;

      // Persistir.
      await prefs.setDouble('last_val_bcv_usd', tempBcvUsd);
      await prefs.setDouble('last_val_bcv_eur', tempBcvEur);
      await prefs.setDouble('last_change_bcv_usd', cambioUsd);
      await prefs.setDouble('last_change_bcv_eur', cambioEur);
      await prefs.setString('last_date_bcv', fechaBcv);

      // Guardar también en el historial local del día.
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setDouble('history_BCV_$hoy', tempBcvUsd);
    } catch (e) {
      debugPrint('[BCV] Fallo Plan A, usando cache: $e');
      snap
        ..tasaBcvUsd = prefs.getDouble('last_val_bcv_usd') ?? 0
        ..tasaBcvEur = prefs.getDouble('last_val_bcv_eur') ?? 0
        ..cambioBcvUsd = prefs.getDouble('last_change_bcv_usd') ?? 0
        ..cambioBcvEur = prefs.getDouble('last_change_bcv_eur') ?? 0
        ..fechaBcv = prefs.getString('last_date_bcv') ?? '--/--';
    }
  }

  /// Promedio robusto de precios USDT (Binance P2P).
  ///
  /// Los anuncios "trampa"/scam suelen colocarse en las primeras posiciones
  /// con precios artificialmente alterados (muy baratos para parecer
  /// atractivos, o muy caros) para distorsionar el mercado. Este método usa la
  /// mediana como referencia de precio "real" y descarta los anuncios cuyo
  /// precio se aleje demasiado de ella por cualquiera de los dos lados
  /// (outliers), luego promedia los 3 anuncios legítimos más baratos restantes.
  static double? _promedioUsdtRobusto(List<double> precios) {
    if (precios.isEmpty) return null;

    // Ordenar ascendente (los más baratos primero, como los devuelve Binance).
    final sorted = List<double>.from(precios)..sort();

    // Mediana como referencia de precio "real".
    final n = sorted.length;
    final double mediana = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;

    // Banda de tolerancia alrededor de la mediana (±2%): se descartan los
    // anuncios demasiado baratos (scam) y los demasiado caros (trampa).
    const double banda = 0.02;
    final double umbralInferior = mediana * (1 - banda);
    final double umbralSuperior = mediana * (1 + banda);

    final legitimos = sorted
        .where((p) => p >= umbralInferior && p <= umbralSuperior)
        .toList();

    // Si el filtrado dejó la lista vacía (caso raro), usar los originales.
    final base = legitimos.isNotEmpty ? legitimos : sorted;

    final maxItems = base.length > 3 ? 3 : base.length;
    double suma = 0;
    for (int i = 0; i < maxItems; i++) {
      suma += base[i];
    }
    return suma / maxItems;
  }

  // ── USDT (Plan A: Binance P2P, Plan B: dolarapi/paralelo, Plan C: cache) ─
  static Future<void> _fetchUsdt(
    SharedPreferences prefs,
    RatesSnapshot snap,
  ) async {
    double? tempBinance;

    // Plan A: Binance P2P (PagoMovil, top‑3).
    try {
      // Monto mínimo del anuncio: equivalente en Bs a 10 USD a tasa BCV.
      // Se descartan así los anuncios de montos muy pequeños. Si aún no hay
      // tasa BCV disponible, se usa un fallback razonable.
      final double bcvUsd = snap.tasaBcvUsd > 0
          ? snap.tasaBcvUsd
          : (prefs.getDouble('last_val_bcv_usd') ?? 0);
      final int transAmount = bcvUsd > 0 ? (bcvUsd * 10).round() : 10000;

      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await http
          .post(
            Uri.parse(
              'https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search?timestamp=$cacheBuster',
            ),
            headers: {
              'User-Agent': _commonHeaders['User-Agent']!,
              'Content-Type': 'application/json',
              'Origin': 'https://p2p.binance.com',
            },
            body: jsonEncode({
              'fiat': 'VES',
              'page': 1,
              'rows': 20,
              'tradeType': 'BUY',
              'asset': 'USDT',
              'countries': [],
              'transAmount': transAmount,
              'proMerchantAds': false,
              'shieldMerchantAds': false,
              'publisherType': 'merchant',
              'payTypes': ['PagoMovil', 'BancoDeVenezuela', 'Banesco'],
              'classifies': ['mass', 'profession', 'router'],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          final lista = data['data'] as List;
          final precios = <double>[];
          for (final item in lista) {
            final p = double.tryParse(item['adv']['price'].toString());
            if (p != null && p > 0) precios.add(p);
          }
          tempBinance = _promedioUsdtRobusto(precios);
        }
      }
    } catch (e) {
      debugPrint('[USDT] Fallo Plan A (Binance): $e');
    }

    // Plan B: dolarapi paralelo.
    if (tempBinance == null) {
      try {
        final resp = await http
            .get(
              Uri.parse('https://ve.dolarapi.com/v1/dolares/paralelo'),
              headers: _commonHeaders,
            )
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          tempBinance = double.parse(data['promedio'].toString());
        }
      } catch (e) {
        debugPrint('[USDT] Fallo Plan B (dolarapi/paralelo): $e');
      }
    }

    if (tempBinance != null) {
      final lastBinance =
          prefs.getDouble('last_val_binance') ?? tempBinance;
      double cambio = prefs.getDouble('last_change_binance') ?? 0;
      if (lastBinance > 0 && tempBinance != lastBinance) {
        cambio = ((tempBinance - lastBinance) / lastBinance) * 100;
      }
      final fechaBinance = DateFormat('HH:mm').format(DateTime.now());

      snap
        ..tasaBinance = tempBinance
        ..cambioBinance = cambio
        ..fechaBinance = fechaBinance;

      await prefs.setDouble('last_val_binance', tempBinance);
      await prefs.setDouble('last_change_binance', cambio);
      await prefs.setString('last_date_binance', fechaBinance);

      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setDouble('history_Binance_$hoy', tempBinance);
    } else {
      // Plan C: cache.
      snap
        ..tasaBinance = prefs.getDouble('last_val_binance') ?? 0
        ..cambioBinance = prefs.getDouble('last_change_binance') ?? 0
        ..fechaBinance = prefs.getString('last_date_binance') ?? '--:--';
    }
  }

  // ── Sincronización de Historial ──────────────────────────────────────────

  /// Descarga y persiste el histórico BCV desde `dolarapi /v1/historicos/dolares`
  /// y el histórico USDT (paralelo) de la misma respuesta para fechas
  /// `>= kUsdtCutover`. Devuelve `true` si se realizó alguna actualización.
  static Future<bool> syncHistory({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final bool needsBcv =
        force || prefs.getString(_kBcvSyncKey) != hoy;
    final bool needsUsdt =
        force || prefs.getString(_kUsdtSyncKey) != hoy;

    if (!needsBcv && !needsUsdt) return false;

    bool updated = false;

    // Una sola llamada a /historicos/dolares (trae oficial + paralelo).
    try {
      final resp = await http
          .get(
            Uri.parse('https://ve.dolarapi.com/v1/historicos/dolares'),
            headers: _commonHeaders,
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final List items = jsonDecode(resp.body) as List;

        if (needsBcv) {
          for (final item in items) {
            if (item['fuente'] != 'oficial') continue;
            final raw = item['promedio'];
            if (raw == null) continue;
            final fecha = item['fecha'].toString().substring(0, 10);
            await prefs.setDouble(
              'history_BCV_$fecha',
              double.parse(raw.toString()),
            );
          }
          await prefs.setString(_kBcvSyncKey, hoy);
          updated = true;
          debugPrint('[Sync BCV] historial actualizado.');
        }

        if (needsUsdt) {
          // 1) Seed local desde history.json (sólo fechas < cutover).
          await _seedUsdtFromAsset(prefs);

          // 2) Sobrescribir/llenar desde paralelo para fechas >= cutover.
          for (final item in items) {
            if (item['fuente'] != 'paralelo') continue;
            final raw = item['promedio'];
            if (raw == null) continue;
            final fecha = item['fecha'].toString().substring(0, 10);
            final d = DateTime.tryParse(fecha);
            if (d == null || d.isBefore(kUsdtCutover)) continue;
            await prefs.setDouble(
              'history_Binance_$fecha',
              double.parse(raw.toString()),
            );
          }
          await prefs.setString(_kUsdtSyncKey, hoy);
          updated = true;
          debugPrint('[Sync USDT] historial actualizado.');
        }
      } else {
        debugPrint('[Sync] dolarapi histórico HTTP ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[Sync] error: $e');
    }

    return updated;
  }

  static Future<void> _seedUsdtFromAsset(SharedPreferences prefs) async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/history.json');
      final data = jsonDecode(jsonString);
      final List categories = data['categories'];
      final List items = data['items'];

      List values = const [];
      for (final item in items) {
        if (item['tm'] == 'Binance P2P: PagoMovil SELL') {
          values = item['values'];
          break;
        }
      }
      if (categories.length != values.length) return;

      for (int i = 0; i < categories.length; i++) {
        final fecha = categories[i].toString().substring(0, 10);
        final d = DateTime.tryParse(fecha);
        if (d == null || !d.isBefore(kUsdtCutover)) continue;
        final key = 'history_Binance_$fecha';
        if (prefs.containsKey(key)) continue; // no sobrescribir
        await prefs.setDouble(
          key,
          double.parse(values[i].toString()),
        );
      }
    } catch (e) {
      debugPrint('[Seed USDT] error: $e');
    }
  }

  // ── Home‑screen widget (Android) ─────────────────────────────────────────

  /// Empuja la última snapshot al widget Android (no-op si la plataforma
  /// no es soportada por `home_widget`).
  static Future<void> pushToWidget(RatesSnapshot snap) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'bcv_usd',
        snap.tasaBcvUsd > 0 ? snap.tasaBcvUsd.toStringAsFixed(2) : '--',
      );
      await HomeWidget.saveWidgetData<String>(
        'bcv_eur',
        snap.tasaBcvEur > 0 ? snap.tasaBcvEur.toStringAsFixed(2) : '--',
      );
      await HomeWidget.saveWidgetData<String>(
        'usdt',
        snap.tasaBinance > 0 ? snap.tasaBinance.toStringAsFixed(2) : '--',
      );
      await HomeWidget.saveWidgetData<String>(
        'cambio_bcv_usd',
        _formatCambio(snap.cambioBcvUsd),
      );
      await HomeWidget.saveWidgetData<String>(
        'cambio_bcv_eur',
        _formatCambio(snap.cambioBcvEur),
      );
      await HomeWidget.saveWidgetData<String>(
        'cambio_binance',
        _formatCambio(snap.cambioBinance),
      );
      await HomeWidget.saveWidgetData<String>('fecha_bcv', snap.fechaBcv);
      await HomeWidget.saveWidgetData<String>(
        'fecha_binance',
        snap.fechaBinance,
      );
      await HomeWidget.updateWidget(
        name: _kAndroidWidgetName,
        androidName: _kAndroidWidgetName,
      );
    } catch (e) {
      debugPrint('[Widget] no se pudo actualizar: $e');
    }
  }

  static String _formatCambio(double c) {
    if (c == 0) return '-';
    final sign = c > 0 ? '+' : '-';
    return '$sign${c.abs().toStringAsFixed(2)}%';
  }
}
