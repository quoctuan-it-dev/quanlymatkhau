package com.giadinh.quanlymatkhau

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Cầu nối giữa Flutter và Android.
 * Kênh "apps": danh sách app đã cài, biểu tượng, kiểm tra/mở app,
 * sao chép an toàn vào bộ nhớ tạm, và lưu/mở file sao lưu.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val REQ_SAVE_FILE = 5101
        private const val REQ_OPEN_FILE = 5102
        private const val MAX_FILE_BYTES = 5 * 1024 * 1024 // 5 MB
    }

    private val channelName = "com.giadinh.quanlymatkhau/apps"
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // true = lần tới app có tiêu điểm thì kiểm tra bộ nhớ tạm.
    // Lớp 2: true ngay khi app vừa mở. Lớp 1: true lại sau khi app bị che (đã sang app khác).
    private var checkClipboardOnFocus = true

    // Đang chờ người dùng chọn file trong hộp chọn của Android.
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Chặn chụp/quay màn hình và ẩn nội dung ở màn hình đa nhiệm.
        // Chỉ bật ở bản release; bản debug để trống để còn chụp màn hình khi lập trình.
        val isDebuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }

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
                    "saveFile" -> {
                        val name = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (name == null || bytes == null) result.error("ARG", "Thiếu dữ liệu", null)
                        else saveFile(name, bytes, result)
                    }
                    "openFile" -> openFile(result)
                                        "getAppVersion" -> result.success(UpdateHelper.appVersion(this))
                    "getUpdateDir" -> result.success(UpdateHelper.updateDir(this))
                    "canInstallPackages" -> result.success(UpdateHelper.canInstallPackages(this))
                    "openInstallPermissionSettings" -> {
                        UpdateHelper.openInstallPermissionSettings(this)
                        result.success(null)
                    }
                    "checkApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) result.error("ARG", "Thiếu path", null)
                        else result.success(UpdateHelper.checkApk(this, path))
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) result.error("ARG", "Thiếu path", null)
                        else result.success(UpdateHelper.installApk(this, path))
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

    // ---------- Lưu / mở file sao lưu (hộp chọn file của Android) ----------

    /** Mở hộp "Lưu vào..." để người dùng chọn nơi lưu (Google Drive, bộ nhớ máy...). */
    private fun saveFile(name: String, bytes: ByteArray, result: MethodChannel.Result) {
        if (pendingFileResult != null) {
            result.error("BUSY", "Đang chọn file", null)
            return
        }
        pendingFileResult = result
        pendingBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        startActivityForResult(intent, REQ_SAVE_FILE)
    }

    /** Mở hộp chọn file để người dùng chọn file sao lưu. */
    private fun openFile(result: MethodChannel.Result) {
        if (pendingFileResult != null) {
            result.error("BUSY", "Đang chọn file", null)
            return
        }
        pendingFileResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        startActivityForResult(intent, REQ_OPEN_FILE)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_SAVE_FILE && requestCode != REQ_OPEN_FILE) return
        val result = pendingFileResult ?: return
        val bytes = pendingBytes
        pendingFileResult = null
        pendingBytes = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // người dùng bấm hủy
            return
        }
        worker.execute {
            try {
                val value: Any = if (requestCode == REQ_SAVE_FILE) {
                    val out = contentResolver.openOutputStream(uri, "w")
                        ?: throw IllegalStateException("Không mở được nơi lưu")
                    out.use { it.write(bytes ?: ByteArray(0)) }
                    true
                } else {
                    val input = contentResolver.openInputStream(uri)
                        ?: throw IllegalStateException("Không mở được file")
                    input.use { readLimited(it) }
                }
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("FILE", e.message, null) }
            }
        }
    }

    /** Đọc file, tối đa 5 MB (file sao lưu thật chỉ vài KB). */
    private fun readLimited(input: InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val n = input.read(buffer)
            if (n < 0) break
            out.write(buffer, 0, n)
            if (out.size() > MAX_FILE_BYTES) throw IllegalStateException("File quá lớn")
        }
        return out.toByteArray()
    }

    // ---------- Các phần từ giai đoạn trước ----------

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