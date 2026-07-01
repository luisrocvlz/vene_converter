package com.example.vene_converter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RatesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.rates_widget).apply {
                setTextViewText(R.id.bcv_usd_value, widgetData.getString("bcv_usd", "--"))
                setTextViewText(R.id.bcv_usd_cambio, widgetData.getString("cambio_bcv_usd", "-"))
                setTextViewText(R.id.bcv_eur_value, widgetData.getString("bcv_eur", "--"))
                setTextViewText(R.id.bcv_eur_cambio, widgetData.getString("cambio_bcv_eur", "-"))
                setTextViewText(R.id.usdt_value, widgetData.getString("usdt", "--"))
                setTextViewText(R.id.usdt_cambio, widgetData.getString("cambio_binance", "-"))
                setTextViewText(
                    R.id.fecha_bcv,
                    widgetData.getString("fecha_bcv", "--:--")
                )
                setTextViewText(
                    R.id.fecha_binance,
                    widgetData.getString("fecha_binance", "--:--")
                )

                // Tap en cualquier parte del widget abre la app.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
