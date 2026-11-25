package com.cashio.app.cash_io

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val OTA_CHANNEL = "com.cashio.app/ota_installer"
        private const val BIOMETRIC_CHANNEL = "com.cashio.app/biometrics"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Hardware Biometric / Fingerprint Authentication Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBiometricAvailable" -> {
                        try {
                            val manager = BiometricManager.from(this)
                            val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
                                BiometricManager.Authenticators.BIOMETRIC_WEAK
                            val canAuth = manager.canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS
                            result.success(canAuth)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }

                    "authenticate" -> {
                        val title = call.argument<String>("title") ?: "Unlock Cash-IO Vault"
                        val subtitle = call.argument<String>("subtitle") ?: "Touch the fingerprint sensor to sign in"
                        val cancelText = call.argument<String>("cancelText") ?: "Use 6-Digit PIN"
                        val responded = AtomicBoolean(false)

                        try {
                            val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
                                BiometricManager.Authenticators.BIOMETRIC_WEAK
                            val manager = BiometricManager.from(this)
                            if (manager.canAuthenticate(authenticators) != BiometricManager.BIOMETRIC_SUCCESS) {
                                if (responded.compareAndSet(false, true)) {
                                    result.success(false)
                                }
                                return@setMethodCallHandler
                            }

                            val executor = ContextCompat.getMainExecutor(this)
                            val biometricPrompt = BiometricPrompt(
                                this,
                                executor,
                                object : BiometricPrompt.AuthenticationCallback() {
                                    override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                        super.onAuthenticationSucceeded(authResult)
                                        if (responded.compareAndSet(false, true)) {
                                            result.success(true)
                                        }
                                    }

                                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                        super.onAuthenticationError(errorCode, errString)
                                        if (responded.compareAndSet(false, true)) {
                                            result.success(false)
                                        }
                                    }
                                }
                            )

                            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                                .setTitle(title)
                                .setSubtitle(subtitle)
                                .setNegativeButtonText(cancelText)
                                .setAllowedAuthenticators(authenticators)
                                .setConfirmationRequired(false)
                                .build()

                            biometricPrompt.authenticate(promptInfo)
                        } catch (_: Exception) {
                            if (responded.compareAndSet(false, true)) {
                                result.success(false)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // 2. GitHub Releases OTA System Updater Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
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
                                    "versionName" to (pInfo.versionName ?: "3.1.0"),
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
