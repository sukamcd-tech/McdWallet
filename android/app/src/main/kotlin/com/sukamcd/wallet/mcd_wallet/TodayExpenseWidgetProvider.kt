package com.sukamcd.wallet.mcd_wallet

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.os.Bundle
import android.widget.RemoteViews
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray

class TodayExpenseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, appWidgetManager: AppWidgetManager,
        appWidgetId: Int, newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val sharedPref = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val userId = sharedPref.getString("user_id", null)

        // Setup click intent (buka app)
        val launchIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (userId.isNullOrBlank()) {
            // Belum login — tampilkan data dari cache
            showCachedData(context, appWidgetManager, appWidgetId, pendingIntent, sharedPref)
            return
        }

        // Fetch dari Supabase secara async
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val total = fetchTodayExpenseFromSupabase(userId)

                // Simpan ke cache SharedPreferences
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                with(sharedPref.edit()) {
                    putFloat("today_expense_amount", total.toFloat())
                    putString("today_expense_date", todayStr)
                    apply()
                }

                withContext(Dispatchers.Main) {
                    val views = buildViews(context, total, pendingIntent)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            } catch (e: Exception) {
                // Jika gagal (offline), tampilkan data cache
                withContext(Dispatchers.Main) {
                    showCachedData(context, appWidgetManager, appWidgetId, pendingIntent, sharedPref)
                }
            }
        }
    }

    private fun fetchTodayExpenseFromSupabase(userId: String): Double {
        val supabaseUrl = "https://lvjuyzemouqryeucznof.supabase.co"
        val anonKey = "sb_publishable_OybqH6e8p_tIPUqVOAk6ag_XCgyuBlU"

        // Hitung rentang hari ini (UTC offset +07:00)
        val tz = java.util.TimeZone.getTimeZone("Asia/Jakarta")
        val cal = java.util.Calendar.getInstance(tz)
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        val startOfDay = cal.time
        cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
        val endOfDay = cal.time

        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        val startStr = sdf.format(startOfDay)
        val endStr = sdf.format(endOfDay)

        val endpoint = "$supabaseUrl/rest/v1/transactions" +
            "?select=amount,type,date" +
            "&user_id=eq.$userId" +
            "&type=eq.expense" +
            "&date=gte.$startStr" +
            "&date=lt.$endStr"

        val url = URL(endpoint)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.setRequestProperty("apikey", anonKey)
        conn.setRequestProperty("Authorization", "Bearer $anonKey")
        conn.setRequestProperty("Accept", "application/json")
        conn.connectTimeout = 8000
        conn.readTimeout = 8000

        return try {
            val responseCode = conn.responseCode
            if (responseCode == 200) {
                val body = conn.inputStream.bufferedReader().readText()
                val arr = JSONArray(body)
                var total = 0.0
                for (i in 0 until arr.length()) {
                    total += arr.getJSONObject(i).optDouble("amount", 0.0)
                }
                total
            } else {
                throw Exception("HTTP $responseCode")
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun showCachedData(
        context: Context, appWidgetManager: AppWidgetManager,
        appWidgetId: Int, pendingIntent: PendingIntent,
        sharedPref: android.content.SharedPreferences
    ) {
        val storedDate = sharedPref.getString("today_expense_date", "") ?: ""
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val amount = if (todayStr == storedDate) sharedPref.getFloat("today_expense_amount", 0.0f).toDouble() else 0.0
        val views = buildViews(context, amount, pendingIntent)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun buildViews(context: Context, amount: Double, pendingIntent: PendingIntent): RemoteViews {
        val format = NumberFormat.getCurrencyInstance(Locale("id", "ID")).apply {
            maximumFractionDigits = 0
        }
        val formattedAmount = format.format(amount).replace("Rp", "Rp ")
        val dateStr = SimpleDateFormat("dd MMM yyyy", Locale("id", "ID")).format(Date())

        return RemoteViews(context.packageName, R.layout.today_expense_widget_2x1).apply {
            setTextViewText(R.id.widget_amount, formattedAmount)
            setTextViewText(R.id.widget_date, dateStr)
            setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }
    }
}
