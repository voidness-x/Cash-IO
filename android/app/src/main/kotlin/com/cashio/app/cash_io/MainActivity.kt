package com.cashio.app.cash_io

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }

                    "openInstallPermissionSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERR_SETTINGS", e.message, null)
                        }
                    }

                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("ERR_INVALID_PATH", "APK file path is empty", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val apkFile = File(filePath).canonicalFile
                            val cacheRoot = cacheDir.canonicalFile
                            val filesRoot = filesDir.canonicalFile

                            // Security boundary: only install verified APKs inside app sandbox ota_updates
                            val insideSandbox = apkFile.toPath().startsWith(cacheRoot.toPath()) ||
                                apkFile.toPath().startsWith(filesRoot.toPath())
                            if (!insideSandbox || !apkFile.exists() || !apkFile.name.endsWith(".apk")) {
                                result.error(
                                    "ERR_SANDBOX_VIOLATION",
                                    "APK path outside verified application sandbox",
                                    null
                                )
                                return@setMethodCallHandler
                            }

                            val contentUri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.ota_provider",
                                apkFile
                            )

                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(contentUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(installIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERR_INSTALL_FAILED", e.message, null)
                        }
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
                                    "versionName" to (pInfo.versionName ?: "3.0.0"),
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
