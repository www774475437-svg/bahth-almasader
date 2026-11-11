package __PACKAGE__

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// يستقبل النص المشارَك، واختصارات الأيقونة، ويبدّل أيقونة التطبيق
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingText: String? = null

    private val iconKeys = listOf("main", "royal", "emerald", "black", "paper", "mihrab", "night", "library")

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingText = incoming(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bahth/share")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialText" -> {
                    result.success(pendingText)
                    pendingText = null
                }
                "setIcon" -> {
                    val key = call.argument<String>("key") ?: "main"
                    try {
                        setIcon(key)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("icon", e.message, null)
                    }
                }
                "currentIcon" -> result.success(currentIcon())
                else -> result.notImplemented()
            }
        }
    }

    private fun aliasName(key: String) = "$packageName.Icon" + key.replaceFirstChar { it.uppercase() }

    private fun setIcon(key: String) {
        val pm = packageManager
        for (k in iconKeys) {
            val state = if (k == key) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            pm.setComponentEnabledSetting(ComponentName(this, aliasName(k)), state, PackageManager.DONT_KILL_APP)
        }
    }

    private fun currentIcon(): String {
        val pm = packageManager
        for (k in iconKeys) {
            val s = pm.getComponentEnabledSetting(ComponentName(this, aliasName(k)))
            if (s == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return k
        }
        return "main"
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = incoming(intent)
        if (text != null) {
            channel?.invokeMethod("sharedText", text)
        }
    }

    private fun incoming(i: Intent?): String? {
        if (i == null) return null
        if (i.action == Intent.ACTION_VIEW) {
            val d = i.data ?: return null
            if (d.scheme == "bahth") return "§shortcut:" + (d.host ?: "")
            return null
        }
        if (i.action != Intent.ACTION_SEND) return null
        val type = i.type ?: return null
        if (!type.startsWith("text/")) return null
        return i.getStringExtra(Intent.EXTRA_TEXT)
    }
}
