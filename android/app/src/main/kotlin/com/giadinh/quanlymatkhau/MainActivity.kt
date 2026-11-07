package com.giadinh.quanlymatkhau

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Cầu nối giữa Flutter và Android.
 * Kênh "apps": danh sách app đã cài, biểu tượng, kiểm tra/mở app,
 * và sao chép an toàn vào bộ nhớ tạm.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.giadinh.quanlymatkhau/apps"
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // true = lần tới app có tiêu điểm thì kiểm tra bộ nhớ tạm.
    // Lớp 2: true ngay khi app vừa mở. Lớp 1: true lại sau khi app bị che (đã sang app khác).
    private var checkClipboardOnFocus = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val pkg = call.argument<String>("packageName")
                when (call.method) {
                    "getLaunchableApps" -> runInBackground(result) { getLaunchableApps() }
                    "getAppIcon" -> {
                        val size = call.argument<Int>("size") ?: 144
                        if (pkg == null) result.error("ARG", "Thiếu packageName", null)
                        else runInBackground(result) { getAppIcon(pkg, size) }
                    }
                    "isInstalled" -> {
                        if (pkg == null) result.error("ARG", "Thiếu packageName", null)
                        else result.success(isInstalled(pkg))
                    }
                    "launchApp" -> {
                        if (pkg == null) result.error("ARG", "Thiếu packageName", null)
                        else result.success(launchApp(pkg))
                    }
                    "copySecret" -> {
                        val text = call.argument<String>("text")
                        if (text == null) {
                            result.error("ARG", "Thiếu text", null)
                        } else {
                            ClipboardGuard.copySecret(this, text)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        checkClipboardOnFocus = true
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Android 10+ chỉ cho đọc bộ nhớ tạm khi app đang có tiêu điểm.
        if (hasFocus && checkClipboardOnFocus) {
            checkClipboardOnFocus = false
            ClipboardGuard.clearIfOurs(this)
        }
    }

    /** Chạy việc nặng ở luồng nền để giao diện không bị giật. */
    private fun runInBackground(result: MethodChannel.Result, task: () -> Any?) {
        worker.execute {
            try {
                val value = task()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("NATIVE", e.message, null) }
            }
        }
    }

    /** Các app có biểu tượng mở được (trừ chính app này). */
    private fun getLaunchableApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { it.first != packageName }
            .distinctBy { it.first }
            .map { mapOf("packageName" to it.first, "label" to it.second) }
    }

    /** Biểu tượng app dạng ảnh PNG; null nếu app không còn trên máy. */
    private fun getAppIcon(pkg: String, size: Int): ByteArray? {
        val drawable = try {
            packageManager.getApplicationIcon(pkg)
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun isInstalled(pkg: String): Boolean =
        packageManager.getLaunchIntentForPackage(pkg) != null

    /** Mở app đích. Trả về false nếu app chưa cài. */
    private fun launchApp(pkg: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }
}