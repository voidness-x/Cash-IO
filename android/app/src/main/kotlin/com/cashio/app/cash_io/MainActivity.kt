package com.cashio.app.cash_io

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val OTA_CHANNEL = "com.cashio.app/ota_installer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        // System browser / DownloadManager handles Play-Protect-safe APK installation
                        result.success(true)
                    }

                    "openExternalUrl" -> {
                        val rawUrl = call.argument<String>("url")
                        if (rawUrl.isNullOrBlank()) {
                            result.error("ERR_INVALID_URL", "URL is empty", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = Uri.parse(rawUrl)
                            if (uri.scheme?.lowercase() != "https") {
                                result.error("ERR_INSECURE_SCHEME", "Only HTTPS URLs are permitted", null)
                                return@setMethodCallHandler
                            }
                            val browserIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                                addCategory(Intent.CATEGORY_BROWSABLE)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(browserIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERR_OPEN_URL", e.message, null)
                        }
                    }

                    "getInstalledPackageInfo" -> {
                        try {
                            val pInfo = packageManager.getPackageInfo(packageName, 0)
                            val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                pInfo.longVersionCode.toInt()
                            } else {
                                @Suppress("DEPRECATION")
                                pInfo.versionCode
                            }
                            result.success(
                                mapOf(
                                    "versionName" to (pInfo.versionName ?: "3.0.1"),
                                    "versionCode" to vCode
                                )
                            )
                        } catch (e: Exception) {
                            result.error("ERR_PKG_INFO", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
