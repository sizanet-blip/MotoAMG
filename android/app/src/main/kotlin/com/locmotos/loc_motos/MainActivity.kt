package com.locmotos.loc_motos

import android.app.LocaleManager
import android.os.Build
import android.os.Bundle
import android.os.LocaleList
import io.flutter.embedding.android.FlutterActivity

/// Fuerza español para diálogos nativos (p. ej. permiso de notificaciones en Android 13+).
/// `MaterialApp.locale` solo afecta a Flutter; el prompt del sistema usa el idioma de la app.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        ensureSpanishAppLocales()
        super.onCreate(savedInstanceState)
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
