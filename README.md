# 🇻🇪 VeneConverter

Aplicación móvil desarrollada en Flutter para consultar y convertir tasas de cambio en Venezuela (BCV y Binance P2P) en tiempo real.

## ✨ Características

* **Tasas en Tiempo Real:** Consulta BCV (Dólar/Euro) y Binance USDT.
* **Modo Offline:** Guarda las últimas tasas conocidas para funcionar sin internet.
* **Gráficos Históricos:** Visualización de tendencias a 7 días, 1 mes, 6 meses y 1 año.
* **Calculadora Reactiva:** Conversión instantánea entre VES, USD, EUR y USDT.
* **Brecha Cambiaria:** Análisis porcentual de diferencia entre paralelo y oficial.
* **Tema Oscuro/Claro:** Adaptable al sistema.

## 🛠️ Tecnologías

* **Flutter & Dart**
* **HTTP:** Consumo de APIs REST.
* **Shared Preferences:** Persistencia de datos local.
* **FL Chart:** Gráficos interactivos.

## 🚀 Instalación

1. Clonar el repositorio.
2. Ejecutar `flutter pub get`.
3. Ejecutar `flutter run`.

## 📦 Ruta de las APKs

Si necesitas las APKs directamente, normalmente se generan en:

* **APK de Flutter (build local):** [build/app/outputs/flutter-apk](build/app/outputs/flutter-apk) — aquí encontrarás `app-debug.apk` y `app-release.apk`.
* **Módulo Android (Gradle):** [android/app/build/outputs/apk](android/app/build/outputs/apk) — APKs por variante (debug/release).
* **Rutas alternativas:** [build/app/outputs](build/app/outputs) — otras salidas según la configuración de compilación.

Para generar una APK localmente:

`flutter build apk --release`

---
Desarrollado con estilo por Luis Roca.
