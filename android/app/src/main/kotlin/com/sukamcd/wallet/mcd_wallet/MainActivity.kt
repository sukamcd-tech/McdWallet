package com.sukamcd.wallet.mcd_wallet

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.sukamcd.wallet/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val sharedPref = getSharedPreferences("widget_data", Context.MODE_PRIVATE)

            when (call.method) {
                "updateTodayExpense" -> {
                    val amount = call.argument<Double>("amount") ?: 0.0
                    val date = call.argument<String>("date") ?: ""

                    // Simpan ke SharedPreferences sebagai cache
                    with(sharedPref.edit()) {
                        putFloat("today_expense_amount", amount.toFloat())
                        putString("today_expense_date", date)
                        apply()
                    }

                    // Trigger update widget
                    triggerWidgetUpdate()
                    result.success(null)
                }

                "saveUserId" -> {
                    val userId = call.argument<String>("userId") ?: ""
                    with(sharedPref.edit()) {
                        putString("user_id", userId)
                        apply()
                    }
                    // Langsung trigger update widget dengan Supabase query
                    triggerWidgetUpdate()
                    result.success(null)
                }

                "clearUserId" -> {
                    with(sharedPref.edit()) {
                        remove("user_id")
                        remove("today_expense_amount")
                        remove("today_expense_date")
                        apply()
                    }
                    triggerWidgetUpdate()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun triggerWidgetUpdate() {
        val intent = Intent(this, TodayExpenseWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(application).getAppWidgetIds(
                ComponentName(application, TodayExpenseWidgetProvider::class.java)
            )
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
    }
}

