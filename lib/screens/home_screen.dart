import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// --- IMPORTS DE TUS WIDGETS PROPIOS ---
import '../services/rates_service.dart';
import '../widgets/history_chart.dart'; // La gráfica
import '../widgets/currency_input.dart'; // Los inputs de texto
import '../widgets/currency_cards.dart'; // Las tarjetas de arriba
import '../widgets/common_widgets.dart'; // Reloj y otros
import '../widgets/cesta_view.dart'; // La vista de cesta

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

  @override
  void initState() {
    super.initState();
    _fetchData();
    RatesService.syncHistory();
  }

  // --- Descarga de tasas actuales y refresco del widget Android ---
  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final snap = await RatesService.fetchAll();
      if (!mounted) return;
      setState(() {
        tasaBcvUsd = snap.tasaBcvUsd;
        tasaBcvEur = snap.tasaBcvEur;
        tasaBinance = snap.tasaBinance;
        cambioBcvUsd = snap.cambioBcvUsd;
        cambioBcvEur = snap.cambioBcvEur;
        cambioBinance = snap.cambioBinance;
        fechaBcv = snap.fechaBcv;
        fechaBinance = snap.fechaBinance;
        isLoading = false;
      });
      // Empujar la snapshot al widget de la pantalla de inicio.
      unawaited(RatesService.pushToWidget(snap));
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
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
      CestaView(
        tasaBcvUsd: tasaBcvUsd,
        tasaBcvEur: tasaBcvEur,
        tasaBinance: tasaBinance,
      ),
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
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket),
            label: 'Cesta',
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
    if (widget.tasaBcvEur > 0) {
      _eurController.text = _fmt(bs / widget.tasaBcvEur);
    }
    if (widget.tasaBinance > 0) {
      _usdtController.text = _fmt(bs / widget.tasaBinance);
    }
    _isUpdating = false;
  }

  void _calcularDesdeEur(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double eur = _parse(v);
    double bs = eur * widget.tasaBcvEur;
    _bsController.text = _fmt(bs);
    if (widget.tasaBcvUsd > 0) {
      _usdController.text = _fmt(bs / widget.tasaBcvUsd);
    }
    if (widget.tasaBinance > 0) {
      _usdtController.text = _fmt(bs / widget.tasaBinance);
    }
    _isUpdating = false;
  }

  void _calcularDesdeUsdt(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double usdt = _parse(v);
    double bs = usdt * widget.tasaBinance;
    _bsController.text = _fmt(bs);
    if (widget.tasaBcvUsd > 0) {
      _usdController.text = _fmt(bs / widget.tasaBcvUsd);
    }
    if (widget.tasaBcvEur > 0) {
      _eurController.text = _fmt(bs / widget.tasaBcvEur);
    }
    _isUpdating = false;
  }

  void _calcularDesdeBs(String v) {
    if (_isUpdating) return;
    _isUpdating = true;
    double bs = _parse(v);
    if (widget.tasaBcvUsd > 0) {
      _usdController.text = _fmt(bs / widget.tasaBcvUsd);
    }
    if (widget.tasaBcvEur > 0) {
      _eurController.text = _fmt(bs / widget.tasaBcvEur);
    }
    if (widget.tasaBinance > 0) {
      _usdtController.text = _fmt(bs / widget.tasaBinance);
    }
    _isUpdating = false;
  }

  void _copiar(String txt, String coin) {
    String msg = "$txt $coin";
    if (coin != "Bs" && _bsController.text.isNotEmpty) {
      msg += " = Bs. ${_bsController.text}";
    }
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copiado: $msg"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _limpiarCampos() {
    setState(() {
      _bsController.clear();
      _usdController.clear();
      _eurController.clear();
      _usdtController.clear();
      _isUpdating = false;
    });
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
                onPressed: _limpiarCampos,
                icon: const Icon(Icons.backspace_outlined),
                tooltip: "Limpiar Campos",
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
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
