import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importamos tus widgets comunes para reusar la Leyenda
import '../services/rates_service.dart';
import 'common_widgets.dart';

const double _kBrechaCasiNulaBs = 0.01;
const int _kDiasBusquedaAnterior = 45;

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryDayPoint {
  final int index;
  final DateTime fecha;
  final double? bcv;
  final double? binance;
  final bool bcvHeredado;
  final bool binanceHeredado;
  final double? cambioBcv;
  final double? cambioBinance;

  const _HistoryDayPoint({
    required this.index,
    required this.fecha,
    required this.bcv,
    required this.binance,
    required this.bcvHeredado,
    required this.binanceHeredado,
    required this.cambioBcv,
    required this.cambioBinance,
  });

  double? get brechaBs {
    final bcvValue = bcv;
    final binanceValue = binance;
    if (bcvValue == null || binanceValue == null) return null;
    if (bcvValue <= 0 || binanceValue <= 0) return null;
    return binanceValue - bcvValue;
  }

  double? get brechaPorcentaje {
    final bcvValue = bcv;
    final binanceValue = binance;
    if (bcvValue == null || binanceValue == null) return null;
    if (bcvValue <= 0 || binanceValue <= 0) return null;
    return ((binanceValue / bcvValue) - 1) * 100;
  }
}

class _GapSummary {
  final double brechaInicialBs;
  final double brechaFinalBs;
  final double brechaInicialPorcentaje;
  final double brechaFinalPorcentaje;

  const _GapSummary({
    required this.brechaInicialBs,
    required this.brechaFinalBs,
    required this.brechaInicialPorcentaje,
    required this.brechaFinalPorcentaje,
  });

  double get separacionInicialBs => brechaInicialBs.abs();
  double get separacionFinalBs => brechaFinalBs.abs();
  double get cambioSeparacionBs => separacionFinalBs - separacionInicialBs;
  bool get inicioCasiNulo => separacionInicialBs < _kBrechaCasiNulaBs;
  bool get estable => cambioSeparacionBs.abs() < _kBrechaCasiNulaBs;
  bool get aumento => cambioSeparacionBs > 0;

  double? get cambioSeparacionPorcentaje {
    if (inicioCasiNulo) return null;
    return (cambioSeparacionBs / separacionInicialBs) * 100;
  }

  String get direccion =>
      estable ? 'estable' : (aumento ? 'aumentó' : 'se redujo');
  String get relacionActual => brechaFinalBs >= 0
      ? 'Binance está por encima de BCV.'
      : 'Binance está por debajo de BCV.';
}

class _HistoryViewState extends State<HistoryView> {
  String periodo = "7D";
  List<FlSpot> puntosBcv = [];
  List<FlSpot> puntosBinance = [];
  List<_HistoryDayPoint> historialDias = [];
  _GapSummary? resumenBrecha;
  double minY = 0, maxY = 100;

  bool insuficientesDatos = false;
  int diasFaltantes = 0;
  int diasRegistrados = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosReales();
  }

  // Carga los datos guardados en SharedPreferences para pintar la gráfica
  Future<void> _cargarDatosReales() async {
    final prefs = await SharedPreferences.getInstance();

    final int diasTotal = _diasTotal();
    final DateTime hoy = DateTime.now();
    final DateTime primeraFecha = _fechaParaIndice(0, diasTotal, hoy);

    final List<FlSpot> tempBcv = [];
    final List<FlSpot> tempBinance = [];
    final List<_HistoryDayPoint> tempHistorial = [];

    double minVal = 999999, maxVal = 0;
    int encontrados = 0;
    double? ultimoValBcv;
    double? ultimoValBinance;
    double? baseCambioBcv = _buscarValorAnterior(
      prefs,
      'history_BCV_',
      primeraFecha,
    );
    double? baseCambioBinance = _buscarValorAnterior(
      prefs,
      'history_Binance_',
      primeraFecha,
    );

    for (int dayIndex = 0; dayIndex < diasTotal; dayIndex++) {
      final DateTime fechaTarget = _fechaParaIndice(dayIndex, diasTotal, hoy);
      final String fechaKey = _fechaKey(fechaTarget);

      final String keyBcv = 'history_BCV_$fechaKey';
      final String keyBinance = 'history_Binance_$fechaKey';

      final double? valorBcvGuardado = prefs.getDouble(keyBcv);
      final bool tieneBcvDelDia =
          valorBcvGuardado != null && valorBcvGuardado > 0;
      double? valorBcv;
      bool bcvHeredado = false;
      double? cambioBcv;
      if (tieneBcvDelDia) {
        valorBcv = valorBcvGuardado;
        cambioBcv = _calcularCambio(valorBcv, baseCambioBcv);
        baseCambioBcv = valorBcv;
        ultimoValBcv = valorBcv;
        encontrados++;
      } else if (ultimoValBcv != null) {
        valorBcv = ultimoValBcv;
        bcvHeredado = true;
        cambioBcv = _calcularCambio(valorBcv, baseCambioBcv);
        baseCambioBcv = valorBcv;
      }

      if (valorBcv != null && valorBcv > 0) {
        tempBcv.add(FlSpot(dayIndex.toDouble(), valorBcv));
        if (valorBcv < minVal) minVal = valorBcv;
        if (valorBcv > maxVal) maxVal = valorBcv;
      }

      final double? valorBinanceGuardado = prefs.getDouble(keyBinance);
      final bool tieneBinanceDelDia =
          valorBinanceGuardado != null && valorBinanceGuardado > 0;
      double? valorBinance;
      bool binanceHeredado = false;
      double? cambioBinance;
      if (tieneBinanceDelDia) {
        valorBinance = valorBinanceGuardado;
        cambioBinance = _calcularCambio(valorBinance, baseCambioBinance);
        baseCambioBinance = valorBinance;
        ultimoValBinance = valorBinance;
      } else if (ultimoValBinance != null) {
        valorBinance = ultimoValBinance;
        binanceHeredado = true;
        cambioBinance = _calcularCambio(valorBinance, baseCambioBinance);
        baseCambioBinance = valorBinance;
      }

      if (valorBinance != null && valorBinance > 0) {
        tempBinance.add(FlSpot(dayIndex.toDouble(), valorBinance));
        if (valorBinance < minVal) minVal = valorBinance;
        if (valorBinance > maxVal) maxVal = valorBinance;
      }

      tempHistorial.add(
        _HistoryDayPoint(
          index: dayIndex,
          fecha: fechaTarget,
          bcv: valorBcv,
          binance: valorBinance,
          bcvHeredado: bcvHeredado,
          binanceHeredado: binanceHeredado,
          cambioBcv: cambioBcv,
          cambioBinance: cambioBinance,
        ),
      );
    }

    if (!mounted) return;

    // Si no hay datos, intentamos descargarlos una vez más en segundo plano
    if (encontrados < 2) {
      _intentarDescargaEmergencia();
      setState(() {
        insuficientesDatos = true;
        puntosBcv = tempBcv;
        puntosBinance = tempBinance;
        historialDias = tempHistorial;
        resumenBrecha = _crearResumenBrecha(tempHistorial);
        diasRegistrados = encontrados;
        diasFaltantes = 2 - encontrados;
      });
    } else {
      setState(() {
        insuficientesDatos = false;
        puntosBcv = tempBcv;
        puntosBinance = tempBinance;
        historialDias = tempHistorial;
        resumenBrecha = _crearResumenBrecha(tempHistorial);
        diasRegistrados = encontrados;
        minY = (minVal - 2).floorToDouble();
        if (minY < 0) minY = 0;
        maxY = (maxVal + 2).ceilToDouble();
      });
    }
  }

  int _diasTotal() {
    return periodo == "7D"
        ? 7
        : (periodo == "30D" ? 30 : (periodo == "6M" ? 180 : 365));
  }

  DateTime _fechaParaIndice(int index, int diasTotal, DateTime hoy) {
    return hoy.subtract(Duration(days: diasTotal - 1 - index));
  }

  String _fechaKey(DateTime fecha) {
    return DateFormat('yyyy-MM-dd').format(fecha);
  }

  double? _buscarValorAnterior(
    SharedPreferences prefs,
    String keyPrefix,
    DateTime fechaInicio,
  ) {
    for (int daysBack = 1; daysBack <= _kDiasBusquedaAnterior; daysBack++) {
      final String key =
          '$keyPrefix${_fechaKey(fechaInicio.subtract(Duration(days: daysBack)))}';
      final double? value = prefs.getDouble(key);
      if (value != null && value > 0) return value;
    }
    return null;
  }

  double? _calcularCambio(double? valorActual, double? valorAnterior) {
    if (valorActual == null || valorAnterior == null) return null;
    if (valorAnterior <= 0) return null;
    return ((valorActual - valorAnterior) / valorAnterior) * 100;
  }

  _GapSummary? _crearResumenBrecha(List<_HistoryDayPoint> puntos) {
    final puntosConBrecha = puntos
        .where(
          (point) => point.brechaBs != null && point.brechaPorcentaje != null,
        )
        .toList();
    if (puntosConBrecha.length < 2) return null;

    final _HistoryDayPoint inicial = puntosConBrecha.first;
    final _HistoryDayPoint finalPoint = puntosConBrecha.last;
    return _GapSummary(
      brechaInicialBs: inicial.brechaBs!,
      brechaFinalBs: finalPoint.brechaBs!,
      brechaInicialPorcentaje: inicial.brechaPorcentaje!,
      brechaFinalPorcentaje: finalPoint.brechaPorcentaje!,
    );
  }

  _HistoryDayPoint? _puntoPorIndice(int index) {
    if (index < 0 || index >= historialDias.length) return null;
    return historialDias[index];
  }

  String _formatearBs(double value, {bool signed = false}) {
    if (value.abs() < _kBrechaCasiNulaBs) return '0.00';
    final sign = signed && value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }

  String _formatearPorcentaje(double? value, {bool signed = true}) {
    if (value == null) return 's/d';
    if (value.abs() < 0.005) return '0.00%';
    final sign = signed && value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  String _textoCambioDiario(double? value, bool heredado) {
    final suffix = heredado ? ' (sin dato nuevo)' : '';
    return 'Día: ${_formatearPorcentaje(value)}$suffix';
  }

  String _textoPeriodoBrecha(_GapSummary summary) {
    if (summary.inicioCasiNulo) {
      return 'desde casi 0 Bs hasta ${summary.separacionFinalBs.toStringAsFixed(2)} Bs';
    }
    if (summary.estable) return 'estable';

    final double cambioAbs = summary.cambioSeparacionBs.abs();
    return '${summary.direccion} ${cambioAbs.toStringAsFixed(2)} Bs (${_formatearPorcentaje(summary.cambioSeparacionPorcentaje)})';
  }

  Color _colorCambioBrecha(BuildContext context, _GapSummary summary) {
    if (summary.estable) return Theme.of(context).colorScheme.outline;
    return summary.aumento ? Colors.orange.shade700 : Colors.green.shade700;
  }

  Widget _metricChip(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colorScheme.outline),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brechaResumen(BuildContext context) {
    final summary = resumenBrecha;
    if (summary == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final Color cambioColor = _colorCambioBrecha(context, summary);
    final String brechaActual =
        '${summary.separacionFinalBs.toStringAsFixed(2)} Bs (${summary.brechaFinalPorcentaje.abs().toStringAsFixed(2)}%)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 18, color: cambioColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Brecha BCV vs Binance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(
                context,
                label: 'Brecha actual',
                value: brechaActual,
                color: Colors.orange.shade700,
              ),
              _metricChip(
                context,
                label: 'Cambio del periodo',
                value: _textoPeriodoBrecha(summary),
                color: cambioColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Diferencia entre las tasas. ${summary.relacionActual}',
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  // Función auxiliar por si entramos al historial y está vacío
  Future<void> _intentarDescargaEmergencia() async {
    final bool updated = await RatesService.syncHistory(force: true);
    if (updated && mounted) _cargarDatosReales();
  }

  Widget getBottomTitle(double value, TitleMeta meta) {
    final int index = value.toInt();
    final int diasTotal = _diasTotal();
    final DateTime fechaPunto = _fechaParaIndice(
      index,
      diasTotal,
      DateTime.now(),
    );

    int intervalo;
    if (periodo == "7D") {
      intervalo = 1;
    } else if (periodo == "30D") {
      intervalo = 5;
    } else if (periodo == "6M") {
      intervalo = 30;
    } else {
      intervalo = 60;
    }

    if (index % intervalo != 0 && index != diasTotal - 1) {
      return const SizedBox.shrink();
    }

    final String texto = periodo == "7D"
        ? DateFormat('E', 'es_VE').format(fechaPunto)
        : (periodo == "6M" || periodo == "1Y"
              ? DateFormat('MMM', 'es_VE').format(fechaPunto)
              : DateFormat('d/M').format(fechaPunto));

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        texto,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  List<LineTooltipItem?> _buildTooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.asMap().entries.map<LineTooltipItem?>((entry) {
      final LineBarSpot spot = entry.value;
      final int index = spot.x.toInt();
      final _HistoryDayPoint? point = _puntoPorIndice(index);
      final DateTime fechaPunto =
          point?.fecha ?? _fechaParaIndice(index, _diasTotal(), DateTime.now());
      final String fechaStr = DateFormat('dd/MM/yy').format(fechaPunto);
      final bool esBcv = spot.bar.color == Colors.blue;
      final String label = esBcv ? 'BCV' : 'Binance';
      final double? cambio = esBcv ? point?.cambioBcv : point?.cambioBinance;
      final bool heredado = esBcv
          ? (point?.bcvHeredado ?? false)
          : (point?.binanceHeredado ?? false);

      final children = <TextSpan>[
        TextSpan(
          text: '$label: ${spot.y.toStringAsFixed(2)} Bs\n',
          style: TextStyle(
            color: spot.bar.color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        TextSpan(
          text: _textoCambioDiario(cambio, heredado),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ];

      if (entry.key == 0 && point?.brechaBs != null) {
        final double brechaBs = point!.brechaBs!;
        final String relacion = brechaBs >= 0
            ? 'Binance sobre BCV'
            : 'Binance bajo BCV';
        children.add(
          TextSpan(
            text:
                '\nBrecha: ${_formatearBs(brechaBs, signed: true)} Bs (${_formatearPorcentaje(point.brechaPorcentaje)})\n$relacion',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      return LineTooltipItem(
        entry.key == 0 ? '$fechaStr\n' : '',
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        children: children,
      );
    }).toList();
  }

  void _mostrarInfoBinance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green),
            SizedBox(width: 10),
            Text("Historial de Tasas"),
          ],
        ),
        content: const Text(
          "🔵 BCV: Los datos históricos se descargan de fuentes oficiales.\n\n"
          "🟢 Binance (USDT): Al igual que la tasa oficial, el histórico se obtiene de la API de DolarVzla.\n\n"
          "Los valores actuales y futuros que se guarden en tu teléfono se optimizarán combinando el histórico remoto con tus consultas locales en tiempo real.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxXVal = (_diasTotal() - 1).toDouble();

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
            selected: {periodo},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => periodo = newSelection.first);
              _cargarDatosReales();
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: insuficientesDatos
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_graph,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Cargando Historial...",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
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
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (resumenBrecha != null) ...[
                        _brechaResumen(context),
                        const SizedBox(height: 10),
                      ],
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) => Text(
                                    value.toInt().toString(),
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: getBottomTitle,
                                  interval: 1,
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: maxXVal,
                            minY: minY,
                            maxY: maxY,
                            clipData: FlClipData.all(),
                            lineBarsData: [
                              LineChartBarData(
                                spots: puntosBcv,
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 3,
                                dotData: FlDotData(
                                  show: periodo == "7D" || periodo == "30D",
                                ),
                              ),
                              LineChartBarData(
                                spots: puntosBinance,
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 3,
                                dotData: FlDotData(
                                  show: periodo == "7D" || periodo == "30D",
                                ),
                              ),
                            ],
                            betweenBarsData:
                                puntosBcv.isNotEmpty && puntosBinance.isNotEmpty
                                ? [
                                    BetweenBarsData(
                                      fromIndex: 0,
                                      toIndex: 1,
                                      color: Colors.orange.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ]
                                : [],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: _buildTooltipItems,
                                tooltipRoundedRadius: 8,
                                tooltipPadding: const EdgeInsets.all(8),
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Toca el ícono (i) para saber más sobre los datos.",
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
