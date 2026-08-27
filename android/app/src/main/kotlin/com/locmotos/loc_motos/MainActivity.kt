package com.locmotos.loc_motos

import android.app.LocaleManager
import android.os.Build
import android.os.Bundle
import android.os.LocaleList
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Fuerza español para diálogos nativos (p. ej. permiso de notificaciones en Android 13+).
/// `MaterialApp.locale` solo afecta a Flutter; el prompt del sistema usa el idioma de la app.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        ensureSpanishAppLocales()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.locmotos.loc_motos/storage",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFreeBytesForPath" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    try {
                        val stat = StatFs(path)
                        val freeBytes = stat.availableBlocksLong * stat.blockSizeLong
                        result.success(freeBytes)
                    } catch (_: Exception) {
                        result.success(null)
                    }
                }
                "getGraphicsCompat" -> {
                    val fingerprint = Build.FINGERPRINT
                    val model = Build.MODEL
                    val product = Build.PRODUCT
                    val hardware = Build.HARDWARE
                    val isEmulator =
                        fingerprint.startsWith("generic") ||
                            fingerprint.contains("emulator", ignoreCase = true) ||
                            model.contains("Emulator", ignoreCase = true) ||
                            model.contains("Android SDK", ignoreCase = true) ||
                            product.contains("sdk", ignoreCase = true) ||
                            hardware.contains("goldfish", ignoreCase = true) ||
                            hardware.contains("ranchu", ignoreCase = true)
                    result.success(
                        mapOf(
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "isEmulator" to isEmulator,
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureSpanishAppLocales() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }
        val localeManager = getSystemService(LocaleManager::class.java) ?: return
        val desired = LocaleList.forLanguageTags("es")
        if (localeManager.applicationLocales.toLanguageTags() != desired.toLanguageTags()) {
            localeManager.applicationLocales = desired
        }
    }
}
