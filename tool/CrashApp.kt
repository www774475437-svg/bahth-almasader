package __PACKAGE__

import android.app.Application
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

// يسجّل سبب أي انهيار: في ملف crash.txt وفي الحافظة (للصقه للمطوّر)
class CrashApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val sw = StringWriter()
                error.printStackTrace(PrintWriter(sw))
                val text = "Android " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ") " +
                        Build.MANUFACTURER + " " + Build.MODEL + "\n\n" + sw.toString()
                try { File(getExternalFilesDir(null), "crash.txt").writeText(text) } catch (e: Exception) { }
                try { File(filesDir, "crash.txt").writeText(text) } catch (e: Exception) { }
                try {
                    val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(ClipData.newPlainText("crash", text.take(6000)))
                } catch (e: Exception) { }
            } catch (e: Exception) { }
            previous?.uncaughtException(thread, error)
        }
    }
}
