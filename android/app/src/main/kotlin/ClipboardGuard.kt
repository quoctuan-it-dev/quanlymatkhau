package com.giadinh.quanlymatkhau

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import android.os.SystemClock

/**
 * Sao chép tên đăng nhập / mật khẩu vào bộ nhớ tạm và tự xóa theo nhiều lớp.
 * Nội dung do app này chép được gắn một "nhãn" riêng, nên nhận ra được
 * mà không cần lưu lại mật khẩu để so sánh.
 */
object ClipboardGuard {
    /** Lớp 3: tự xóa sau bao nhiêu phút. Đổi số này nếu muốn. */
    const val AUTO_CLEAR_MINUTES = 15L

    private const val CLIP_LABEL = "com.giadinh.quanlymatkhau.secret"
    private const val PREFS = "clipboard_guard"
    private const val KEY_PENDING = "pending"
    private const val REQUEST_CODE = 4201

    /** Sao chép và đánh dấu "nhạy cảm" để Android không hiện xem trước. */
    fun copySecret(context: Context, text: String) {
        val clip = ClipData.newPlainText(CLIP_LABEL, text)
        val extras = PersistableBundle()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
        } else {
            extras.putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        clip.description.extras = extras
        clipboard(context).setPrimaryClip(clip)
        prefs(context).edit().putBoolean(KEY_PENDING, true).apply()
        scheduleAutoClear(context)
    }

    /**
     * Lớp 1 và 2: app đang hiện trên màn hình nên đọc được bộ nhớ tạm.
     * Chỉ xóa nếu đúng là thứ app này đã chép.
     */
    fun clearIfOurs(context: Context) {
        if (!prefs(context).getBoolean(KEY_PENDING, false)) return
        val cm = clipboard(context)
        val label = cm.primaryClipDescription?.label?.toString()
        if (label == CLIP_LABEL) clear(cm)
        markDone(context)
    }

    /**
     * Lớp 3: gọi từ hẹn giờ. App đang ở nền nên Android không cho đọc
     * bộ nhớ tạm; chỉ xóa nếu người dùng chưa quay lại app kể từ lúc chép.
     */
    fun clearFromAlarm(context: Context) {
        if (!prefs(context).getBoolean(KEY_PENDING, false)) return
        clear(clipboard(context))
        prefs(context).edit().putBoolean(KEY_PENDING, false).apply()
    }

    private fun scheduleAutoClear(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = SystemClock.elapsedRealtime() + AUTO_CLEAR_MINUTES * 60_000
        am.set(AlarmManager.ELAPSED_REALTIME, triggerAt, pendingIntent(context))
    }

    private fun markDone(context: Context) {
        prefs(context).edit().putBoolean(KEY_PENDING, false).apply()
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pendingIntent(context))
    }

    private fun clear(cm: ClipboardManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            cm.clearPrimaryClip()
        } else {
            cm.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    private fun pendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, ClipboardClearReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun clipboard(context: Context) =
        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** Nhận tín hiệu hẹn giờ 15 phút từ hệ thống (lớp 3). */
class ClipboardClearReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ClipboardGuard.clearFromAlarm(context)
    }
}