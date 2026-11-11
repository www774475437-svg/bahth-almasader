package __PACKAGE__

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// ويدجت «فائدة اليوم» على الشاشة الرئيسية
class FawaidWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.fawaid_widget)
            views.setTextViewText(
                R.id.widget_text,
                widgetData.getString("fawaid_text", null) ?: "احفظ الفوائد بالنجمة ⭐ لتظهر هنا كل يوم"
            )
            views.setTextViewText(
                R.id.widget_source,
                widgetData.getString("fawaid_source", null) ?: "بحث المصادر"
            )
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
