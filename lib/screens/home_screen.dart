import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// --- IMPORTS DE TUS WIDGETS PROPIOS ---
import '../widgets/history_chart.dart'; // La gráfica
import '../widgets/currency_input.dart'; // Los inputs de texto
import '../widgets/currency_cards.dart'; // Las tarjetas de arriba
import '../widgets/common_widgets.dart'; // Reloj y otros

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final IconData currentThemeIcon;

  const MainScreen({
    super.key,
    required this.toggleTheme,
    required this.currentThemeIcon,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Variables de Estado
  double tasaBcvUsd = 0.0;
  double tasaBcvEur = 0.0;
  double tasaBinance = 0.0;

  double cambioBcvUsd = 0.0;
  double cambioBcvEur = 0.0;
  double cambioBinance = 0.0;

  String fechaBcv = "--:--";
  String fechaBinance = "--:--";
  bool isLoading = false;

  // --- API KEY & HEADERS (Tu llave maestra) ---
  final Map<String, String> headersCombinados = {
    'x-dolarvzla-key': dotenv.env['API_KEY_DOLARVZLA'] ?? '',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Referer': 'https://google.com',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
    _sincronizarHistorialRemoto();
  }

  // --- 1. Sincronización de Historial (Para la caché de la gráfica) ---
  Future<void> _sincronizarHistorialRemoto() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.dolarvzla.com/public/exchange-rate/list'),
        headers: headersCombinados,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List rates = data['rates'];
        final prefs = await SharedPreferences.getInstance();

        for (var item in rates) {
          String date = item['date'];
          double usdBCV = double.parse(item['usd'].toString());
          await prefs.setDouble('history_BCV_$date', usdBCV);
        }
        debugPrint(
          "Historial BCV sincronizado en background: ${rates.length} registros.",
        );
      }
    } catch (e) {
      debugPrint("Error sync background: $e");
    }
  }

  // --- 2. Descarga de Tasas Actuales (Calculadora) ---
  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      // PLAN A: API Principal (DolarVzla)
      try {
        final response = await http.get(
          Uri.parse('https://api.dolarvzla.com/public/exchange-rate'),
          headers: headersCombinados,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final current = data['current'];
          final change = data['changePercentage'];

          double tempBcvUsd = double.parse(current['usd'].toString());
          double tempBcvEur = double.parse(current['eur'].toString());

          cambioBcvUsd = double.parse(change['usd'].toString());
          cambioBcvEur = double.parse(change['eur'].toString());

          // Guardar respaldo
          await prefs.setDouble('last_val_bcv_usd', tempBcvUsd);
          await prefs.setDouble('last_val_bcv_eur', tempBcvEur);
          await prefs.setDouble('last_change_bcv_usd', cambioBcvUsd);
          await prefs.setDouble('last_change_bcv_eur', cambioBcvEur);

          String rawDate = current['date'];
          try {
            DateTime dateApi = DateTime.parse(rawDate);
            fechaBcv = DateFormat('dd/MM').format(dateApi);
            await prefs.setString('last_date_bcv', fechaBcv);
          } catch (e) {
            fechaBcv = rawDate;
          }

          tasaBcvUsd = tempBcvUsd;
          tasaBcvEur = tempBcvEur;
        } else {
          throw Exception("API Error: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("Fallo Plan A ($e). Ejecutando Plan B...");

        // PLAN B: DolarApi (Respaldo)
        try {
          final responseUSD = await http.get(
            Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'),
          );
          final responseEUR = await http.get(
            Uri.parse('https://ve.dolarapi.com/v1/euros/oficial'),
          );

          if (responseUSD.statusCode == 200) {
            final dataUSD = jsonDecode(responseUSD.body);
            double tempBcvUsd = double.parse(dataUSD['promedio'].toString());
            double tempBcvEur = (responseEUR.statusCode == 200)
                ? double.parse(
                    jsonDecode(responseEUR.body)['promedio'].toString(),
                  )
                : tempBcvUsd * 1.09;

            // Recálculo manual de cambios
            double lastUsd = prefs.getDouble('last_val_bcv_usd') ?? tempBcvUsd;
            if (lastUsd > 0 && tempBcvUsd != lastUsd) {
              cambioBcvUsd = ((tempBcvUsd - lastUsd) / lastUsd) * 100;
            } else {
              cambioBcvUsd = prefs.getDouble('last_change_bcv_usd') ?? 0.0;
            }
            // (Lógica similar para Euro omitida por brevedad, se asume 0 o previo)
            cambioBcvEur = prefs.getDouble('last_change_bcv_eur') ?? 0.0;

            tasaBcvUsd = tempBcvUsd;
            tasaBcvEur = tempBcvEur;
            fechaBcv = "BCV (Alt)";
          }
        } catch (e2) {
          // PLAN C: Offline
          tasaBcvUsd = prefs.getDouble('last_val_bcv_usd') ?? 0.0;
          tasaBcvEur = prefs.getDouble('last_val_bcv_eur') ?? 0.0;
          cambioBcvUsd = prefs.getDouble('last_change_bcv_usd') ?? 0.0;
          cambioBcvEur = prefs.getDouble('last_change_bcv_eur') ?? 0.0;
          fechaBcv = prefs.getString('last_date_bcv') ?? "--/--";
        }
      }

      // BINANCE (P2P)
      try {
        String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        final response = await http.post(
          Uri.parse(
            'https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search?timestamp=$cacheBuster',
          ),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Content-Type': 'application/json',
            'Origin': 'https://p2p.binance.com',
          },
          body: jsonEncode({
            "asset": "USDT",
            "fiat": "VES",
            "merchantCheck": true,
            "transAmount": 1500,
            "page": 1,
            "rows": 5,
            "payTypes": ["PagoMovil"],
            "tradeType": "BUY",
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['data'] != null && data['data'].isNotEmpty) {
            var lista = data['data'];
            double suma = 0;
            int count = 0;
            int maxItems = lista.length > 3 ? 3 : lista.length;
            for (int i = 0; i < maxItems; i++) {
              suma += double.parse(lista[i]['adv']['price']);
              count++;
            }
            double tempBinance = suma / count;

            double lastBinance =
                prefs.getDouble('last_val_binance') ?? tempBinance;
            if (lastBinance > 0 && tempBinance != lastBinance) {
              cambioBinance = ((tempBinance - lastBinance) / lastBinance) * 100;
            } else {
              cambioBinance = 0.0;
            }

            await prefs.setDouble('last_val_binance', tempBinance);
            tasaBinance = tempBinance;
            fechaBinance = DateFormat('HH:mm a').format(DateTime.now());

            // Guardar para historial local
            String hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
            await prefs.setDouble('history_Binance_$hoy', tasaBinance);
          }
        }
      } catch (e) {
        tasaBinance = prefs.getDouble('last_val_binance') ?? 0.0;
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      CalculatorView(
        tasaBcvUsd: tasaBcvUsd,
        tasaBcvEur: tasaBcvEur,
        tasaBinance: tasaBinance,
        cambioBcvUsd: cambioBcvUsd,
        cambioBcvEur: cambioBcvEur,
        cambioBinance: cambioBinance,
        fechaBcv: fechaBcv,
        fechaBinance: fechaBinance,
        onRefresh: _fetchData,
        isLoading: isLoading,
      ),
      const HistoryView(), // <--- Importado desde widgets/history_chart.dart
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 20),
            children: [
              TextSpan(
                text: "Vene",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).appBarTheme.foregroundColor,
                ),
              ),
              TextSpan(
                text: "Converter",
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).appBarTheme.foregroundColor,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.currentThemeIcon),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculadora',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            selectedIcon: Icon(Icons.ssid_chart),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}

// --- VISTA CALCULADORA (Lógica local de UI) ---
class CalculatorView extends StatefulWidget {
  final double tasaBcvUsd, tasaBcvEur, tasaBinance;
  final double cambioBcvUsd, cambioBcvEur, cambioBinance;
  final String fechaBcv, fechaBinance;
  final Future<void> Function() onRefresh;
  final bool isLoading;

  const CalculatorView({
    super.key,
    required this.tasaBcvUsd,
    required this.tasaBcvEur,
    required this.tasaBinance,
    required this.cambioBcvUsd,
    required this.cambioBcvEur,
    required this.cambioBinance,
    required this.fechaBcv,
    required this.fechaBinance,
    required this.onRefresh,
    required this.isLoading,
  });

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  final TextEditingController _bsController = TextEditingController();
  final TextEditingController _usdController = TextEditingController();
  final TextEditingController _eurController = TextEditingController();
  final TextEditingController _usdtController = TextEditingController();
  bool _isUpdating = false;
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'es_VE',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _usdController.text = "1,00";
  }

  @override
  void didUpdateWidget(CalculatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasaBcvUsd > 0 &&
        !widget.isLoading &&
        _usdController.text.isNotEmpty) {
      _calcularDesdeUsd(_usdController.text);
    }
  }

  double _parse(String v) =>
      (double.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0) / 100;
  String _fmt(double v) => _formatter.format(v).trim();

  void _calcularDesdeUsd(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double usd = _parse(v);
    double bs = usd * widget.tasaBcvUsd;
    _bsController.text = _fmt(bs);
    if (widget.tasaBcvEur > 0)
      _eurController.text = _fmt(bs / widget.tasaBcvEur);
    if (widget.tasaBinance > 0)
      _usdtController.text = _fmt(bs / widget.tasaBinance);
    _isUpdating = false;
  }

  void _calcularDesdeEur(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double eur = _parse(v);
    double bs = eur * widget.tasaBcvEur;
    _bsController.text = _fmt(bs);
    if (widget.tasaBcvUsd > 0)
      _usdController.text = _fmt(bs / widget.tasaBcvUsd);
    if (widget.tasaBinance > 0)
      _usdtController.text = _fmt(bs / widget.tasaBinance);
    _isUpdating = false;
  }

  void _calcularDesdeUsdt(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double usdt = _parse(v);
    double bs = usdt * widget.tasaBinance;
    _bsController.text = _fmt(bs);
    if (widget.tasaBcvUsd > 0)
      _usdController.text = _fmt(bs / widget.tasaBcvUsd);
    if (widget.tasaBcvEur > 0)
      _eurController.text = _fmt(bs / widget.tasaBcvEur);
    _isUpdating = false;
  }

  void _calcularDesdeBs(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double bs = _parse(v);
    if (widget.tasaBcvUsd > 0)
      _usdController.text = _fmt(bs / widget.tasaBcvUsd);
    if (widget.tasaBcvEur > 0)
      _eurController.text = _fmt(bs / widget.tasaBcvEur);
    if (widget.tasaBinance > 0)
      _usdtController.text = _fmt(bs / widget.tasaBinance);
    _isUpdating = false;
  }

  void _copiar(String txt, String coin) {
    String msg = "$txt $coin";
    if (coin != "Bs" && _bsController.text.isNotEmpty)
      msg += " = Bs. ${_bsController.text}";
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copiado: $msg"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _mostrarComparativa() {
    if (widget.tasaBcvUsd == 0 || widget.tasaBinance == 0) return;

    double diffBinanceBcv = widget.tasaBinance - widget.tasaBcvUsd;
    double porcBinanceBcv = (diffBinanceBcv / widget.tasaBcvUsd) * 100;
    double diffEuroUsd = widget.tasaBcvEur - widget.tasaBcvUsd;
    double porcEuroUsd = (diffEuroUsd / widget.tasaBcvUsd) * 100;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Brecha Cambiaria",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              // Usamos el widget importado de currency_cards.dart
              ComparativaItem(
                titulo: "Binance (P2P) vs BCV",
                valorBase: widget.tasaBcvUsd,
                valorAlto: widget.tasaBinance,
                diferenciaBs: diffBinanceBcv,
                diferenciaPorc: porcBinanceBcv,
              ),
              const Divider(height: 30),
              ComparativaItem(
                titulo: "Arbitraje Euro vs Dólar",
                valorBase: widget.tasaBcvUsd,
                valorAlto: widget.tasaBcvEur,
                diferenciaBs: diffEuroUsd,
                diferenciaPorc: porcEuroUsd,
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const RelojDigital(), // Importado de common_widgets.dart
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoTasa(
                    label: "BCV \$",
                    value: widget.tasaBcvUsd,
                    cambio: widget.cambioBcvUsd,
                    date: widget.fechaBcv,
                    color: Colors.blueAccent,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  InfoTasa(
                    label: "BCV €",
                    value: widget.tasaBcvEur,
                    cambio: widget.cambioBcvEur,
                    date: widget.fechaBcv,
                    color: Colors.orange,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  InfoTasa(
                    label: "USDT",
                    value: widget.tasaBinance,
                    cambio: widget.cambioBinance,
                    date: widget.fechaBinance,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          CurrencyInput(
            controller: _usdController,
            label: "Dólar BCV",
            icon: Icons.attach_money,
            color: Colors.blue,
            currency: "USD",
            onChanged: _calcularDesdeUsd,
            onCopy: () => _copiar(_usdController.text, "USD"),
          ),
          const SizedBox(height: 16),
          CurrencyInput(
            controller: _eurController,
            label: "Euro BCV",
            icon: Icons.euro,
            color: Colors.orange,
            currency: "EUR",
            onChanged: _calcularDesdeEur,
            onCopy: () => _copiar(_eurController.text, "EUR"),
          ),
          const SizedBox(height: 16),
          CurrencyInput(
            controller: _usdtController,
            label: "USDT Binance",
            icon: Icons.currency_bitcoin,
            color: Colors.green,
            currency: "USDT",
            onChanged: _calcularDesdeUsdt,
            onCopy: () => _copiar(_usdtController.text, "USDT"),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(),
          ),
          CurrencyInput(
            controller: _bsController,
            label: "Bolívares (VES)",
            icon: Icons.monetization_on,
            color: Colors.redAccent,
            currency: "Bs",
            isBold: true,
            onChanged: _calcularDesdeBs,
            onCopy: () => _copiar(_bsController.text, "Bs"),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isLoading ? null : widget.onRefresh,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    widget.isLoading ? "Actualizando..." : "Actualizar Tasas",
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _mostrarComparativa,
                icon: const Icon(Icons.compare_arrows),
                tooltip: "Ver Brecha Cambiaria",
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
