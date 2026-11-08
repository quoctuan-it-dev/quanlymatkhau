package com.giadinh.quanlymatkhau

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/** Các việc phía Android cho tính năng "Cập nhật app". */
object UpdateHelper {
    /** Số phiên bản đang cài, ví dụ versionName = "1.0.0", versionCode = 1. */
    fun appVersion(context: Context): Map<String, Any> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return mapOf(
            "versionName" to (info.versionName ?: ""),
            "versionCode" to versionCodeOf(info),
        )
    }

    /** Thư mục tạm để chứa file APK tải về. */
    fun updateDir(context: Context): String {
        val dir = File(context.cacheDir, "updates")
        dir.mkdirs()
        return dir.absolutePath
    }

    /** Người dùng đã cho phép app này mở trình cài đặt chưa. */
    fun canInstallPackages(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    /** Mở trang cài đặt "Cho phép cài ứng dụng từ nguồn này". */
    fun openInstallPermissionSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${context.packageName}"),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /** Kiểm tra file APK tải về: có đúng là app này không, và số phiên bản bao nhiêu. */
    fun checkApk(context: Context, path: String): Map<String, Any> {
        val info = context.packageManager.getPackageArchiveInfo(path, 0)
        if (info == null || info.packageName != context.packageName) {
            return mapOf("valid" to false, "versionCode" to 0L)
        }
        return mapOf("valid" to true, "versionCode" to versionCodeOf(info))
    }

    /** Mở màn hình cài đặt của Android cho file APK (người dùng bấm "Cập nhật"). */
    fun installApk(context: Context, path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        return true
    }

    @Suppress("DEPRECATION")
    private fun versionCodeOf(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
}