import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Importamos tus widgets comunes para reusar la Leyenda
import 'common_widgets.dart'; 

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String periodo = "7D";
  List<FlSpot> puntosBcv = [];
  List<FlSpot> puntosBinance = [];
  double minY = 0, maxY = 100;
  
  bool insuficientesDatos = false;
  int diasFaltantes = 0;
  int diasRegistrados = 0;

  // --- API KEY (Necesaria para refrescar historial si el usuario cambia de pestaña) ---
  final Map<String, String> headersCombinados = {
    'x-dolarvzla-key': 'eb37767e041d65828b6d824b2e91983acb15bb9200fc3e50200efd55b6b56deb',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Referer': 'https://google.com',
  };

  @override
  void initState() { 
    super.initState(); 
    _cargarDatosReales(); 
  }

  // Carga los datos guardados en SharedPreferences para pintar la gráfica
  Future<void> _cargarDatosReales() async {
    final prefs = await SharedPreferences.getInstance();
    
    int diasTotal = periodo == "7D" ? 7 : (periodo == "30D" ? 30 : (periodo == "6M" ? 180 : 365));
    DateTime hoy = DateTime.now();

    List<FlSpot> tempBcv = [];
    List<FlSpot> tempBinance = [];
    
    double minVal = 999999, maxVal = 0;
    int encontrados = 0;

    for (int i = 0; i < diasTotal; i++) {
      DateTime fechaTarget = hoy.subtract(Duration(days: diasTotal - 1 - i));
      String fechaKey = DateFormat('yyyy-MM-dd').format(fechaTarget);
      
      String keyBcv = 'history_BCV_$fechaKey';
      String keyBinance = 'history_Binance_$fechaKey';

      if (prefs.containsKey(keyBcv)) {
        double valBcv = prefs.getDouble(keyBcv) ?? 0;
        if (valBcv > 0) {
          tempBcv.add(FlSpot(i.toDouble(), valBcv));
          if (valBcv < minVal) minVal = valBcv;
          if (valBcv > maxVal) maxVal = valBcv;
          encontrados++;
        }
      }

      if (prefs.containsKey(keyBinance)) {
        double valBinance = prefs.getDouble(keyBinance) ?? 0;
        if (valBinance > 0) {
          tempBinance.add(FlSpot(i.toDouble(), valBinance));
          if (valBinance < minVal) minVal = valBinance;
          if (valBinance > maxVal) maxVal = valBinance;
        }
      }
    }

    // Si no hay datos, intentamos descargarlos una vez más en segundo plano
    if (encontrados < 2) {
      _intentarDescargaEmergencia(); 
      setState(() {
        insuficientesDatos = true;
        diasRegistrados = encontrados;
        diasFaltantes = 2 - encontrados;
      });
    } else {
      setState(() {
        insuficientesDatos = false;
        puntosBcv = tempBcv;
        puntosBinance = tempBinance;
        diasRegistrados = encontrados;
        minY = (minVal - 2).floorToDouble(); if (minY<0) minY=0;
        maxY = (maxVal + 2).ceilToDouble();
      });
    }
  }

  // Función auxiliar por si entramos al historial y está vacío
  Future<void> _intentarDescargaEmergencia() async {
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
        if(mounted) _cargarDatosReales(); // Recargamos al terminar
      }
    } catch (e) {
      debugPrint("Error descarga emergencia: $e");
    }
  }

  Widget getBottomTitle(double value, TitleMeta meta) {
    int index = value.toInt();
    int diasTotal = periodo == "7D" ? 7 : (periodo == "30D" ? 30 : (periodo == "6M" ? 180 : 365));
    DateTime fechaPunto = DateTime.now().subtract(Duration(days: diasTotal - 1 - index));
    
    int intervalo;
    if (periodo == "7D") intervalo = 1;
    else if (periodo == "30D") intervalo = 5;
    else if (periodo == "6M") intervalo = 30; 
    else intervalo = 60; 

    if (index % intervalo != 0 && index != diasTotal - 1) return const SizedBox.shrink();

    String texto = periodo == "7D" 
        ? DateFormat('E', 'es_VE').format(fechaPunto) 
        : (periodo == "6M" || periodo == "1Y" 
            ? DateFormat('MMM', 'es_VE').format(fechaPunto)
            : DateFormat('d/M').format(fechaPunto)); 

    return SideTitleWidget(axisSide: meta.axisSide, child: Text(texto, style: const TextStyle(fontSize: 10, color: Colors.grey)));
  }

  void _mostrarInfoBinance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.info_outline, color: Colors.green), SizedBox(width: 10), Text("Historial de Tasas")]),
        content: const Text(
          "🔵 BCV: Los datos históricos se descargan de fuentes oficiales.\n\n"
          "🟢 Binance: Esta tasa depende de la oferta y demanda en tiempo real. Su historial es local y se empezará a guardar en tu teléfono a partir de hoy.\n\n"
          "Con el uso diario, verás cómo se construye la línea verde.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Entendido"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double maxXVal = (periodo == "7D" ? 6 : (periodo == "30D" ? 29 : (periodo == "6M" ? 179 : 364))).toDouble();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "7D", label: Text("7D")),
              ButtonSegment(value: "30D", label: Text("1M")),
              ButtonSegment(value: "6M", label: Text("6M")),
              ButtonSegment(value: "1Y", label: Text("1A")),
            ],
            selected: {periodo}, onSelectionChanged: (Set<String> newSelection) { setState(() { periodo = newSelection.first; _cargarDatosReales(); }); },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: insuficientesDatos
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_graph, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text("Cargando Historial...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                )
              : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      // Reutilizamos el widget Leyenda que movimos a common_widgets.dart
                      Leyenda(color: Colors.blue, text: "BCV"), 
                      const SizedBox(width: 20), 
                      Leyenda(color: Colors.green, text: "Binance"),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _mostrarInfoBinance,
                        child: Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                      )
                    ]
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LineChart(LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(fontSize: 10)))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: getBottomTitle, interval: 1)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0, 
                      maxX: maxXVal, 
                      minY: minY, maxY: maxY,
                      clipData: FlClipData.all(), 
                      lineBarsData: [
                        LineChartBarData(spots: puntosBcv, isCurved: true, color: Colors.blue, barWidth: 3, dotData: FlDotData(show: periodo == "7D" || periodo == "30D")),
                        LineChartBarData(spots: puntosBinance, isCurved: true, color: Colors.green, barWidth: 3, dotData: FlDotData(show: periodo == "7D" || periodo == "30D")),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              int index = spot.x.toInt();
                              int diasTotal = periodo == "7D" ? 7 : (periodo == "30D" ? 30 : (periodo == "6M" ? 180 : 365));
                              DateTime fechaPunto = DateTime.now().subtract(Duration(days: diasTotal - 1 - index));
                              String fechaStr = DateFormat('dd/MM/yy').format(fechaPunto);
                              return LineTooltipItem(
                                "$fechaStr\n", 
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                children: [TextSpan(text: "${spot.y.toStringAsFixed(2)} Bs", style: TextStyle(color: spot.bar.color, fontWeight: FontWeight.bold, fontSize: 14))],
                              );
                            }).toList();
                          },
                          tooltipRoundedRadius: 8, tooltipPadding: const EdgeInsets.all(8), fitInsideHorizontally: true, fitInsideVertically: true,
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  Text("Toca el ícono (i) para saber más sobre los datos.", style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                ],
              ),
          ),
        ],
      ),
    );
  }
}