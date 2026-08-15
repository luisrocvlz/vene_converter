import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/cesta.dart';
import '../services/cesta_service.dart';
import '../services/ocr_service.dart';
import '../utils/formatters.dart';

/// Vista "Cesta": permite registrar productos de una compra, ver su valor en
/// cada moneda y el total, y guardar cestas con nombre congelando las tasas.
class CestaView extends StatefulWidget {
  final double tasaBcvUsd;
  final double tasaBcvEur;
  final double tasaBinance;

  const CestaView({
    super.key,
    required this.tasaBcvUsd,
    required this.tasaBcvEur,
    required this.tasaBinance,
  });

  @override
  State<CestaView> createState() => _CestaViewState();
}

class _CestaViewState extends State<CestaView> {
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'es_VE',
    symbol: '',
    decimalDigits: 2,
  );

  List<Cesta> _cestas = [];

  /// Cesta abierta en detalle (null = mostrar listado).
  Cesta? _cestaAbierta;

  // Controladores del formulario de producto.
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _precioCtrl = TextEditingController();
  final TextEditingController _cantidadCtrl = TextEditingController();
  Moneda _monedaSeleccionada = Moneda.usdBcv;

  // Id del producto en edición (null = agregar nuevo).
  String? _editandoId;

  bool _cargando = true;
  bool _procesandoFoto = false;

  /// Si es true, la vista de detalle muestra las conversiones con las tasas
  /// actuales (en vivo) en lugar de las congeladas al guardar la cesta.
  bool _mostrarTasasActuales = false;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl.text = '1';
    _cargar();
  }

  Future<void> _cargar() async {
    final cestas = await CestaService.cargarCestas();
    if (!mounted) return;
    setState(() {
      _cestas = cestas;
      _cargando = false;
    });
  }

  String _fmt(double v) => _formatter.format(v).trim();

  double _parse(String v) =>
      (double.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0) / 100;

  double _parseDecimal(String v) =>
      double.tryParse(v.replaceAll(',', '.').trim()) ?? 0;

  // ── Acciones sobre productos ──────────────────────────────────────────────

  void _agregarOEditarProducto() {
    final cesta = _cestaAbierta;
    if (cesta == null) return;

    final nombre = _nombreCtrl.text.trim();
    final precio = _parse(_precioCtrl.text);
    final cantidad = _parseDecimal(_cantidadCtrl.text);
    if (nombre.isEmpty || precio <= 0 || cantidad <= 0) {
      _mostrarSnack('Completa nombre, precio y cantidad válidos.');
      return;
    }

    setState(() {
      if (_editandoId != null) {
        final idx = cesta.productos.indexWhere((p) => p.id == _editandoId);
        if (idx >= 0) {
          cesta.productos[idx]
            ..nombre = nombre
            ..precio = precio
            ..moneda = _monedaSeleccionada
            ..cantidad = cantidad;
        }
      } else {
        cesta.productos.add(
          Producto(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            nombre: nombre,
            precio: precio,
            moneda: _monedaSeleccionada,
            cantidad: cantidad,
          ),
        );
      }
      _limpiarFormulario();
    });
    CestaService.guardarCesta(cesta);
  }

  void _editarProducto(Producto p) {
    setState(() {
      _editandoId = p.id;
      _nombreCtrl.text = p.nombre;
      _precioCtrl.text = _fmt(p.precio);
      _cantidadCtrl.text = p.cantidad.toString().replaceAll('.', ',');
      _monedaSeleccionada = p.moneda;
    });
  }

  void _eliminarProducto(Producto p) {
    final cesta = _cestaAbierta;
    if (cesta == null) return;
    setState(() {
      cesta.productos.removeWhere((x) => x.id == p.id);
      if (_editandoId == p.id) _limpiarFormulario();
    });
    CestaService.guardarCesta(cesta);
  }

  void _limpiarFormulario() {
    _editandoId = null;
    _nombreCtrl.clear();
    _precioCtrl.clear();
    _cantidadCtrl.text = '1';
    _monedaSeleccionada = Moneda.usdBcv;
  }

  /// Toma una foto con la cámara, aplica OCR y llena los campos del
  /// formulario con el nombre, precio y moneda detectados.
  Future<void> _tomarFotoYProcesar() async {
    if (_procesandoFoto) return;
    setState(() => _procesandoFoto = true);

    try {
      final XFile? foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (foto == null) {
        // Usuario canceló la cámara.
        return;
      }

      final resultado = await OcrService.procesarImagen(foto.path);
      if (!mounted) return;

      if (resultado == null) {
        _mostrarSnack('No se pudo leer el texto de la imagen.');
        return;
      }

      setState(() {
        _nombreCtrl.text = resultado.nombre;
        _precioCtrl.text = _fmt(resultado.precio);
        _monedaSeleccionada = resultado.moneda;
      });
      _mostrarSnack('Producto detectado. Revisa los campos antes de agregar.');
    } catch (_) {
      if (mounted) _mostrarSnack('Error al procesar la imagen.');
    } finally {
      if (mounted) setState(() => _procesandoFoto = false);
    }
  }

  // ── Acciones sobre cestas ─────────────────────────────────────────────────

  Future<void> _crearCesta() async {
    final nombre = await _pedirNombre(titulo: 'Nueva cesta', valorInicial: '');
    if (nombre == null || nombre.trim().isEmpty) return;

    final nueva = Cesta(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre.trim(),
      tasaBcvUsd: widget.tasaBcvUsd,
      tasaBcvEur: widget.tasaBcvEur,
      tasaBinance: widget.tasaBinance,
      fechaGuardado: DateTime.now(),
    );

    await CestaService.guardarCesta(nueva);
    if (!mounted) return;
    setState(() {
      _cestas.add(nueva);
      _cestaAbierta = nueva;
    });
  }

  void _abrirCesta(Cesta cesta) {
    setState(() {
      _cestaAbierta = cesta;
      _mostrarTasasActuales = false;
      _limpiarFormulario();
    });
  }

  void _cerrarCesta() {
    setState(() {
      _cestaAbierta = null;
      _mostrarTasasActuales = false;
      _limpiarFormulario();
    });
  }

  Future<void> _renombrarCesta() async {
    final cesta = _cestaAbierta;
    if (cesta == null) return;
    final nombre = await _pedirNombre(
      titulo: 'Renombrar cesta',
      valorInicial: cesta.nombre,
    );
    if (nombre == null || nombre.trim().isEmpty) return;
    await CestaService.renombrarCesta(cesta.id, nombre.trim());
    if (!mounted) return;
    setState(() => cesta.nombre = nombre.trim());
  }

  Future<void> _eliminarCesta() async {
    final cesta = _cestaAbierta;
    if (cesta == null) return;
    final confirmar = await _confirmar(
      'Eliminar cesta',
      '¿Eliminar la cesta "${cesta.nombre}"?',
    );
    if (confirmar != true) return;
    await CestaService.eliminarCesta(cesta.id);
    if (!mounted) return;
    setState(() {
      _cestas.removeWhere((c) => c.id == cesta.id);
      _cestaAbierta = null;
    });
  }

  // ── Diálogos ──────────────────────────────────────────────────────────────

  Future<String?> _pedirNombre({
    required String titulo,
    required String valorInicial,
  }) {
    final controller = TextEditingController(text: valorInicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmar(String titulo, String mensaje) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cestaAbierta != null) {
      return _vistaDetalle(_cestaAbierta!);
    }
    return _vistaListado();
  }

  // ── Vista de listado ──────────────────────────────────────────────────────

  Widget _vistaListado() {
    return Stack(
      children: [
        if (_cestas.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_basket_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'No tienes cestas todavía',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca "+" para crear una nueva',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _cestas.length,
            itemBuilder: (context, index) {
              final cesta = _cestas[index];
              return _tarjetaCesta(cesta);
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _crearCesta,
            tooltip: 'Nueva cesta',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaCesta(Cesta cesta) {
    final totalBs = cesta.totalEnBs();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirCesta(cesta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_basket,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cesta.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cesta.productos.length} producto(s) · '
                      '${DateFormat('dd/MM/yyyy HH:mm').format(cesta.fechaGuardado!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bs ${_fmt(totalBs)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vista de detalle ──────────────────────────────────────────────────────

  Widget _vistaDetalle(Cesta cesta) {
    final tasas = _mostrarTasasActuales
        ? (
            usd: widget.tasaBcvUsd,
            eur: widget.tasaBcvEur,
            usdt: widget.tasaBinance,
          )
        : (
            usd: cesta.tasaBcvUsd,
            eur: cesta.tasaBcvEur,
            usdt: cesta.tasaBinance,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _cerrarCesta,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cesta.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _renombrarCesta,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Renombrar',
              ),
              IconButton(
                onPressed: _eliminarCesta,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar cesta',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _formularioProducto(),
          const SizedBox(height: 16),
          _botonCompararTasas(),
          const SizedBox(height: 16),
          _listaProductos(cesta, tasas),
          const SizedBox(height: 16),
          _totalCompra(cesta, tasas),
        ],
      ),
    );
  }

  /// Botón para alternar entre las tasas congeladas (registro) y las tasas
  /// actuales (en vivo), sin modificar la cesta guardada.
  Widget _botonCompararTasas() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            setState(() => _mostrarTasasActuales = !_mostrarTasasActuales),
        icon: Icon(
          _mostrarTasasActuales
              ? Icons.history
              : Icons.update,
        ),
        label: Text(
          _mostrarTasasActuales
              ? 'Ver tasas del registro'
              : 'Ver tasas actuales',
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _formularioProducto() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editandoId != null
                        ? 'Editar producto'
                        : 'Agregar producto',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _procesandoFoto ? null : _tomarFotoYProcesar,
                  icon: _procesandoFoto
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Leer producto desde foto',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(18),
                CurrencyPtFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Moneda>(
                    initialValue: _monedaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      border: OutlineInputBorder(),
                    ),
                    items: Moneda.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Row(
                              children: [
                                Icon(m.icono, size: 18, color: m.color),
                                const SizedBox(width: 8),
                                Text(m.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (m) =>
                        setState(() => _monedaSeleccionada = m ?? Moneda.usdBcv),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _agregarOEditarProducto,
                    icon: Icon(
                      _editandoId != null
                          ? Icons.check
                          : Icons.add_circle_outline,
                    ),
                    label: Text(
                      _editandoId != null ? 'Guardar cambios' : 'Agregar',
                    ),
                  ),
                ),
                if (_editandoId != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _limpiarFormulario,
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancelar edición',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaProductos(Cesta cesta, tasas) {
    if (cesta.productos.isEmpty) {
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No hay productos. Agrega el primero arriba.'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Productos',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        for (final p in cesta.productos) _tarjetaProducto(p, tasas),
      ],
    );
  }

  Widget _tarjetaProducto(Producto p, tasas) {
    final bs = p.valorEnBs(
      tasaBcvUsd: tasas.usd,
      tasaBcvEur: tasas.eur,
      tasaBinance: tasas.usdt,
    );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(p.moneda.icono, color: p.moneda.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_fmt(p.precio)} ${p.moneda.simbolo} × ${p.cantidad}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Bs ${_fmt(bs)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'USD ${_fmt(tasas.usd > 0 ? bs / tasas.usd : 0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                Text(
                  'USDT ${_fmt(tasas.usdt > 0 ? bs / tasas.usdt : 0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _editarProducto(p),
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Editar',
            ),
            IconButton(
              onPressed: () => _eliminarProducto(p),
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalCompra(Cesta cesta, tasas) {
    final bs = cesta.totalEnBs();
    final usd = tasas.usd > 0 ? bs / tasas.usd : 0.0;
    final eur = tasas.eur > 0 ? bs / tasas.eur : 0.0;
    final usdt = tasas.usdt > 0 ? bs / tasas.usdt : 0.0;

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_basket, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Total de la compra',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _filaTotal('Bolívares (VES)', 'Bs ${_fmt(bs)}', Moneda.ves),
          _filaTotal('Dólar (BCV)', 'USD ${_fmt(usd)}', Moneda.usdBcv),
          _filaTotal('Euro (BCV)', 'EUR ${_fmt(eur)}', Moneda.eurBcv),
          _filaTotal('USDT (Binance)', 'USDT ${_fmt(usdt)}', Moneda.usdtBinance),
          const SizedBox(height: 8),
          Text(
            _mostrarTasasActuales
                ? 'Conversión con tasas actuales'
                : 'Conversión con tasas del registro',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          if (cesta.fechaGuardado != null) ...[
            const SizedBox(height: 4),
            Text(
              'Guardada el ${DateFormat('dd/MM/yyyy HH:mm').format(cesta.fechaGuardado!)}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaTotal(String label, String valor, Moneda moneda) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(moneda.icono, size: 16, color: moneda.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
