package com.example.skanida_student

import android.app.ActivityManager
import android.content.Context
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var examChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        examChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "skanida/exam_lock",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Screen pinning (lock task). Tanpa device owner Android
                    // menampilkan konfirmasi / toast "Aplikasi disematkan".
                    "startLockTask" -> {
                        try {
                            startLockTask()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stopLockTask" -> {
                        try {
                            stopLockTask()
                        } catch (_: Exception) {
                            // Tidak sedang disematkan.
                        }
                        result.success(null)
                    }
                    // 0 = NONE, 1 = LOCKED, 2 = PINNED.
                    "lockTaskState" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        result.success(am.lockTaskModeState)
                    }
                    // Blok screenshot / rekam layar, pratinjau Recent jadi hitam.
                    "setSecure" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    // false bila layar mati / sedang mati (bukan keluar aplikasi).
                    "isInteractive" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isInteractive)
                    }
                    // Split-screen / jendela mengambang / picture-in-picture.
                    "isMultiWindow" -> result.success(isMultiWindowNow())
                    // Sembunyikan overlay aplikasi lain (chat head, bubble). API 31+.
                    "setHideOverlays" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            window.setHideOverlayWindows(call.arguments == true)
                        }
                        result.success(null)
                    }
                    // Tutup paksa aplikasi (dipakai saat syarat mode ujian tidak terpenuhi).
                    "forceClose" -> {
                        result.success(null)
                        try {
                            stopLockTask()
                        } catch (_: Exception) {
                        }
                        finishAndRemoveTask()
                        Process.killProcess(Process.myPid())
                    }
                    // Baterai & jenis koneksi untuk bar status halaman ujian.
                    "deviceStatus" -> result.success(deviceStatus())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun deviceStatus(): Map<String, Any?> {
        val status = HashMap<String, Any?>()
        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            status["battery"] = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            status["charging"] = bm.isCharging
        } catch (_: Exception) {
        }
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
            status["network"] = when {
                caps == null -> "none"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
            status["validated"] =
                caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        } catch (_: Exception) {
        }
        return status
    }

    private fun isMultiWindowNow(): Boolean =
        isInMultiWindowMode || isInPictureInPictureMode

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        examChannel?.invokeMethod("multiWindowChanged", isMultiWindowNow())
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        examChannel?.invokeMethod("multiWindowChanged", isMultiWindowNow())
    }

    // Dipanggil saat pengguna sendiri meninggalkan activity (Home / Recent),
    // tidak dipanggil untuk layar mati atau dialog sistem.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        examChannel?.invokeMethod("userLeaveHint", null)
    }
}
