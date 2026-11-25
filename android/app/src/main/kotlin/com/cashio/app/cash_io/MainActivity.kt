package com.cashio.app.cash_io

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val OTA_CHANNEL = "com.cashio.app/ota_installer"
        private const val BIOMETRIC_CHANNEL = "com.cashio.app/biometrics"
        private val SAFE_FILENAME_REGEX = Regex("^[A-Za-z0-9._-]+\\.apk$")
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

        // 2. GitHub Releases OTA Verified System DownloadManager Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        result.success(true)
                    }

                    "enqueueApkDownload" -> {
                        val rawUrl = call.argument<String>("url")
                        val rawFilename = call.argument<String>("filename") ?: "Cash-IO-update.apk"
                        val title = call.argument<String>("title") ?: "Cash-IO Update"

                        if (rawUrl.isNullOrBlank()) {
                            result.error("ERR_INVALID_URL", "URL is empty", null)
                            return@setMethodCallHandler
                        }
                        if (!SAFE_FILENAME_REGEX.matches(rawFilename) || rawFilename.contains("..")) {
                            result.error("ERR_INVALID_FILENAME", "Invalid APK filename", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val uri = Uri.parse(rawUrl)
                            if (uri.scheme?.lowercase() != "https") {
                                result.error("ERR_INSECURE_SCHEME", "Only HTTPS URLs are permitted", null)
                                return@setMethodCallHandler
                            }

                            // Remove any stale partial APK with the same filename when accessible
                            try {
                                val downloadsDir = Environment.getExternalStoragePublicDirectory(
                                    Environment.DIRECTORY_DOWNLOADS
                                )
                                val existing = File(downloadsDir, rawFilename)
                                if (existing.exists()) {
                                    existing.delete()
                                }
                            } catch (_: Exception) {
                                // Scoped storage handles deduplication automatically if not owned
                            }

                            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                            val request = DownloadManager.Request(uri)
                                .setTitle(title)
                                .setDescription("Verifying SHA-256 integrity after download")
                                .setMimeType("application/vnd.android.package-archive")
                                .setNotificationVisibility(
                                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                                )
                                .setDestinationInExternalPublicDir(
                                    Environment.DIRECTORY_DOWNLOADS,
                                    rawFilename
                                )
                                .setAllowedOverMetered(true)
                                .setAllowedOverRoaming(true)

                            val downloadId = dm.enqueue(request)
                            result.success(downloadId)
                        } catch (e: Exception) {
                            result.error("ERR_ENQUEUE_FAILED", e.message, null)
                        }
                    }

                    "queryApkDownload" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null || downloadId <= 0L) {
                            result.error("ERR_INVALID_ID", "Invalid downloadId", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                                val query = DownloadManager.Query().setFilterById(downloadId)
                                dm.query(query).use { cursor ->
                                    if (cursor == null || !cursor.moveToFirst()) {
                                        runOnUiThread {
                                            result.success(mapOf("status" to "failed"))
                                        }
                                        return@Thread
                                    }

                                    val statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                                    val soFarIdx = cursor.getColumnIndex(
                                        DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR
                                    )
                                    val totalIdx = cursor.getColumnIndex(
                                        DownloadManager.COLUMN_TOTAL_SIZE_BYTES
                                    )

                                    val rawStatus = if (statusIdx >= 0) cursor.getInt(statusIdx) else 0
                                    val bytesSoFar = if (soFarIdx >= 0) cursor.getLong(soFarIdx) else 0L
                                    val totalBytes = if (totalIdx >= 0) cursor.getLong(totalIdx) else -1L

                                    when (rawStatus) {
                                        DownloadManager.STATUS_SUCCESSFUL -> {
                                            val fileUri = dm.getUriForDownloadedFile(downloadId)
                                            val sha256Hex = if (fileUri != null) {
                                                computeUriSha256Hex(fileUri)
                                            } else {
                                                ""
                                            }
                                            runOnUiThread {
                                                result.success(
                                                    mapOf(
                                                        "status" to "completed",
                                                        "bytesDownloaded" to bytesSoFar,
                                                        "totalBytes" to totalBytes,
                                                        "sha256" to sha256Hex
                                                    )
                                                )
                                            }
                                        }

                                        DownloadManager.STATUS_FAILED -> {
                                            runOnUiThread {
                                                result.success(
                                                    mapOf(
                                                        "status" to "failed",
                                                        "bytesDownloaded" to bytesSoFar,
                                                        "totalBytes" to totalBytes
                                                    )
                                                )
                                            }
                                        }

                                        else -> {
                                            runOnUiThread {
                                                result.success(
                                                    mapOf(
                                                        "status" to "running",
                                                        "bytesDownloaded" to bytesSoFar,
                                                        "totalBytes" to totalBytes
                                                    )
                                                )
                                            }
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("ERR_QUERY_DOWNLOAD", e.message, null)
                                }
                            }
                        }.start()
                    }

                    "removeApkDownload" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null || downloadId <= 0L) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                            val removed = dm.remove(downloadId)
                            result.success(removed > 0)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }

                    "openVerifiedApkInstaller" -> {
                        try {
                            val downloadsIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(downloadsIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERR_OPEN_DOWNLOADS", e.message, null)
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
                                    "versionName" to (pInfo.versionName ?: "3.1.1"),
                                    "versionCode" to vCode,
                                    "supportedAbis" to Build.SUPPORTED_ABIS.toList()
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

    private fun computeUriSha256Hex(uri: Uri): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val inputStream = contentResolver.openInputStream(uri) ?: return ""
        inputStream.use { stream ->
            val buffer = ByteArray(65536)
            var read = stream.read(buffer)
            while (read > 0) {
                digest.update(buffer, 0, read)
                read = stream.read(buffer)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
