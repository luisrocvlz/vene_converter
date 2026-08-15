import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/cesta.dart';

/// Resultado del OCR de una etiqueta de producto.
class OcrResultado {
  final String nombre;
  final double precio;
  final Moneda moneda;

  const OcrResultado({
    required this.nombre,
    required this.precio,
    required this.moneda,
  });
}

/// Servicio de OCR on-device (Google ML Kit) para leer etiquetas de productos.
class OcrService {
  /// Procesa la imagen en [path] y devuelve el nombre, precio y moneda
  /// detectados, o `null` si no se pudo extraer información útil.
  static Future<OcrResultado?> procesarImagen(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText =
          await recognizer.processImage(inputImage);

      final String texto = recognizedText.text;
      if (texto.trim().isEmpty) return null;

      return _parsear(texto);
    } catch (_) {
      return null;
    } finally {
      recognizer.close();
    }
  }

  /// Parsea el texto OCR para extraer nombre, precio y moneda.
  static OcrResultado? _parsear(String texto) {
    // Detectar moneda: "REF" (case-insensitive) → USD BCV, si no → VES.
    final bool esRef = RegExp(r'\bREF\b', caseSensitive: false).hasMatch(texto);
    final Moneda moneda = esRef ? Moneda.usdBcv : Moneda.ves;

    // Extraer el precio: número (con decimales) cercano a "REF" o a un símbolo
    // de moneda ($, Bs, Bs., BsF, etc.).
    final double? precio = _extraerPrecio(texto);

    // Nombre: texto restante sin el precio ni la palabra REF.
    final String nombre = _extraerNombre(texto, precio);

    if (precio == null && nombre.trim().isEmpty) return null;

    return OcrResultado(
      nombre: nombre.trim().isEmpty ? 'Producto' : nombre.trim(),
      precio: precio ?? 0,
      moneda: moneda,
    );
  }

  /// Busca el número que representa el precio: el más cercano a "REF" o a un
  /// símbolo de moneda. Admite decimales con coma o punto.
  static double? _extraerPrecio(String texto) {
    // Patrón de número con decimales opcionales (coma o punto) y separador de
    // miles opcional.
    final RegExp numRe = RegExp(
      r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+',
    );

    // Posiciones de los "anclas" (REF o símbolos de moneda).
    final RegExp anclaRe = RegExp(
      r'REF|Bs\.?|BsF|B\.S\.|\$|USD|US\$',
      caseSensitive: false,
    );

    final List<RegExpMatch> anclas = anclaRe.allMatches(texto).toList();
    final List<RegExpMatch> numeros = numRe.allMatches(texto).toList();

    if (numeros.isEmpty) return null;

    // Si no hay anclas, devolver el número mayor (heurística de respaldo).
    if (anclas.isEmpty) {
      double mayor = 0;
      for (final n in numeros) {
        final v = _aDouble(n.group(0)!);
        if (v != null && v > mayor) mayor = v;
      }
      return mayor > 0 ? mayor : null;
    }

    // Para cada número, calcular la distancia mínima a un ancla.
    double? mejorValor;
    int mejorDistancia = 1 << 30;
    for (final n in numeros) {
      final int posNum = n.start;
      for (final a in anclas) {
        final int dist = (posNum - a.start).abs();
        if (dist < mejorDistancia) {
          mejorDistancia = dist;
          mejorValor = _aDouble(n.group(0)!);
        }
      }
    }
    return mejorValor;
  }

  /// Convierte una cadena numérica (con coma/punto decimal) a double.
  static double? _aDouble(String s) {
    // Normalizar: quitar separadores de miles y convertir coma decimal a punto.
    String limpio = s.replaceAll(RegExp(r'[^\d,.]'), '');
    // Si tiene coma y punto, asumir que la coma es separador de miles.
    if (limpio.contains(',') && limpio.contains('.')) {
      limpio = limpio.replaceAll(',', '');
    } else if (limpio.contains(',')) {
      limpio = limpio.replaceAll(',', '.');
    }
    return double.tryParse(limpio);
  }

  /// Extrae el nombre: todo el texto menos el precio y la palabra REF.
  static String _extraerNombre(String texto, double? precio) {
    String nombre = texto;

    // Quitar la palabra REF.
    nombre = nombre.replaceAll(RegExp(r'\bREF\b', caseSensitive: false), ' ');

    // Quitar el precio detectado (en sus posibles formatos).
    if (precio != null) {
      final String precioStr = precio.toString();
      nombre = nombre.replaceAll(precioStr, ' ');
      // También quitar variantes con coma decimal.
      final String precioComa = precioStr.replaceAll('.', ',');
      if (precioComa != precioStr) {
        nombre = nombre.replaceAll(precioComa, ' ');
      }
    }

    // Quitar símbolos de moneda y caracteres sobrantes.
    nombre = nombre.replaceAll(
      RegExp(r'Bs\.?|BsF|B\.S\.|\$|USD|US\$', caseSensitive: false),
      ' ',
    );

    // Colapsar espacios y saltos de línea.
    nombre = nombre.replaceAll(RegExp(r'\s+'), ' ').trim();

    return nombre;
  }
}
