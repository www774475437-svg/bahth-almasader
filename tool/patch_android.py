"""
يُشغَّل على GitHub بعد `flutter create` لتجهيز ملفات أندرويد:
- اسم التطبيق بالعربية وإذن الإنترنت
- استقبال النصوص من «مشاركة» في التطبيقات الأخرى
- الأيقونة وشاشة الافتتاح
- تنزيل خط أميري لتصدير PDF
"""
import os
import re
import shutil
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = os.path.join(ROOT, "android", "app", "src", "main")
RES = os.path.join(MAIN, "res")
MANIFEST = os.path.join(MAIN, "AndroidManifest.xml")


def patch_manifest():
    with open(MANIFEST, encoding="utf-8") as f:
        m = f.read()

    m = re.sub(r'android:label="[^"]*"', 'android:label="بحث المصادر"', m, count=1)

    if "android.permission.INTERNET" not in m:
        m = m.replace(
            "<application",
            '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1,
        )

    if "android.intent.action.SEND" not in m:
        share_filter = """<intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>"""
        m = m.replace(
            '<intent-filter>\n                <action android:name="android.intent.action.MAIN"/>',
            share_filter,
            1,
        )
        if "android.intent.action.SEND" not in m:
            # صيغة مختلفة للملف: نضيف المرشّح قبل إغلاق النشاط
            m = m.replace(
                "</activity>",
                """    <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
        </activity>""",
                1,
            )

    perms = [
        "android.permission.RECORD_AUDIO",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
    ]
    for perm in perms:
        if perm not in m:
            m = m.replace(
                "<application",
                f'<uses-permission android:name="{perm}"/>\n    <application',
                1,
            )

    receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:name=".FawaidWidgetProvider" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/fawaid_widget_info"/>
        </receiver>
    </application>"""
    if "FawaidWidgetProvider" not in m:
        m = m.replace("</application>", receivers, 1)

    speech_query = """<intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>"""
    if "android.speech.RecognitionService" not in m:
        if "<queries>" in m:
            m = m.replace("<queries>", "<queries>\n        " + speech_query, 1)
        else:
            m = m.replace("</manifest>", "    <queries>\n        " + speech_query + "\n    </queries>\n</manifest>", 1)

    m = m.replace('android:name="${applicationName}"', 'android:name=".CrashApp"', 1)
    if "EnableImpeller" not in m:
        m = m.replace("</application>", """    <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"/>
    </application>""", 1)

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(m)
    print("manifest patched")


def write_main_activity():
    kotlin_root = os.path.join(MAIN, "kotlin")
    target = None
    for dirpath, _, files in os.walk(kotlin_root):
        if "MainActivity.kt" in files:
            target = os.path.join(dirpath, "MainActivity.kt")
            break
    if target is None:
        raise SystemExit("MainActivity.kt not found")

    with open(target, encoding="utf-8") as f:
        pkg = re.search(r"^package\s+([\w.]+)", f.read(), re.M).group(1)

    src = os.path.join(ROOT, "tool", "MainActivity.kt")
    with open(src, encoding="utf-8") as f:
        code = f.read().replace("__PACKAGE__", pkg)
    with open(target, "w", encoding="utf-8") as f:
        f.write(code)
    print("MainActivity written:", pkg)
    with open(os.path.join(ROOT, "tool", "CrashApp.kt"), encoding="utf-8") as f:
        crash = f.read().replace("__PACKAGE__", pkg)
    with open(os.path.join(os.path.dirname(target), "CrashApp.kt"), "w", encoding="utf-8") as f:
        f.write(crash)
    add_shortcuts(pkg)


ICON_KEYS = ["main", "royal", "emerald", "black", "paper", "mihrab", "night", "library"]


def add_icon_aliases():
    """أيقونات بديلة: كل أيقونة «اسم مستعار» للنشاط الرئيسي، تُفعَّل واحدة فقط"""
    with open(MANIFEST, encoding="utf-8") as f:
        m = f.read()
    if "activity-alias" in m:
        return
    # نزيل LAUNCHER من النشاط الرئيسي (ينتقل إلى الأسماء المستعارة)
    m = m.replace('<category android:name="android.intent.category.LAUNCHER"/>', "", 1)
    aliases = []
    for k in ICON_KEYS:
        icon = "@mipmap/ic_launcher" if k == "main" else f"@mipmap/ic_alt_{k}"
        enabled = "true" if k == "main" else "false"
        name = ".Icon" + k.capitalize()
        aliases.append(f"""
        <activity-alias
            android:name="{name}"
            android:enabled="{enabled}"
            android:exported="true"
            android:icon="{icon}"
            android:roundIcon="{icon}"
            android:label="بحث المصادر"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts"/>
        </activity-alias>""")
    m = m.replace("</activity>", "</activity>" + "".join(aliases), 1)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(m)

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    for k in ICON_KEYS[1:]:
        with open(os.path.join(anydpi, f"ic_alt_{k}.xml"), "w", encoding="utf-8") as f:
            f.write(f"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_alt_{k}_foreground"/>
</adaptive-icon>
""")
    print("icon aliases added")


def add_shortcuts(pkg):
    xml_dir = os.path.join(RES, "xml")
    os.makedirs(xml_dir, exist_ok=True)
    items = [("paste", "sc_paste", "لصق وبحث"), ("voice", "sc_voice", "بحث بالصوت"), ("bookmarks", "sc_bookmarks", "الفواصل")]
    parts = []
    for host, sid, _ in items:
        parts.append(f"""    <shortcut
        android:shortcutId="{host}"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/{sid}">
        <intent
            android:action="android.intent.action.VIEW"
            android:data="bahth://{host}"
            android:targetPackage="{pkg}"
            android:targetClass="{pkg}.MainActivity"/>
    </shortcut>""")
    with open(os.path.join(xml_dir, "shortcuts.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">\n'
                + "\n".join(parts) + "\n</shortcuts>\n")
    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "shortcut_strings.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                + "\n".join(f'    <string name="{sid}">{label}</string>' for _, sid, label in items)
                + "\n</resources>\n")
    print("shortcuts added")


def write_widget():
    kotlin_root = os.path.join(MAIN, "kotlin")
    act_dir = None
    for dirpath, _, files in os.walk(kotlin_root):
        if "MainActivity.kt" in files:
            act_dir = dirpath
            break
    with open(os.path.join(act_dir, "MainActivity.kt"), encoding="utf-8") as f:
        pkg = re.search(r"^package\s+([\w.]+)", f.read(), re.M).group(1)
    with open(os.path.join(ROOT, "tool", "FawaidWidgetProvider.kt"), encoding="utf-8") as f:
        code = f.read().replace("__PACKAGE__", pkg)
    with open(os.path.join(act_dir, "FawaidWidgetProvider.kt"), "w", encoding="utf-8") as f:
        f.write(code)

    src = os.path.join(ROOT, "tool", "widget_res")
    for d in os.listdir(src):
        dst = os.path.join(RES, d)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(os.path.join(src, d)):
            shutil.copy(os.path.join(src, d, f), os.path.join(dst, f))
    print("widget written")


def enable_desugaring():
    app = os.path.join(ROOT, "android", "app")
    kts = os.path.join(app, "build.gradle.kts")
    groovy = os.path.join(app, "build.gradle")
    if os.path.exists(kts):
        with open(kts, encoding="utf-8") as f:
            g = f.read()
        if "isCoreLibraryDesugaringEnabled" not in g:
            g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
            g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n'
        with open(kts, "w", encoding="utf-8") as f:
            f.write(g)
        print("desugaring enabled (kts)")
    elif os.path.exists(groovy):
        with open(groovy, encoding="utf-8") as f:
            g = f.read()
        if "coreLibraryDesugaringEnabled" not in g:
            g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
            g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
        with open(groovy, "w", encoding="utf-8") as f:
            f.write(g)
        print("desugaring enabled (groovy)")


def force_compile_sdk():
    """compileSdk 36 للتطبيق ولكل المكتبات (بعض المكتبات الحديثة تشترط 36)"""
    android = os.path.join(ROOT, "android")
    # 1) التطبيق نفسه: نكتبها مباشرة
    for name in ("build.gradle.kts", "build.gradle"):
        app = os.path.join(android, "app", name)
        if os.path.exists(app):
            with open(app, encoding="utf-8") as f:
                g = f.read()
            g2 = re.sub(r"compileSdk\s*=\s*[^\n]+", "compileSdk = 36", g)
            g2 = re.sub(r"compileSdkVersion\s+[^\n]+", "compileSdkVersion 36", g2)
            if "compileSdk" not in g2:
                g2 = re.sub(r"android\s*\{", "android {\n    compileSdk = 36" if name.endswith("kts") else "android {\n    compileSdkVersion 36", g2, count=1)
            with open(app, "w", encoding="utf-8") as f:
                f.write(g2)
            print("app compileSdk = 36 (" + name + ")")
    # 2) كل المكتبات
    kts = os.path.join(android, "build.gradle.kts")
    groovy = os.path.join(android, "build.gradle")
    if os.path.exists(kts):
        with open(kts, encoding="utf-8") as f:
            g = f.read()
        if "forceCompileSdk2" not in g:
            g = re.sub(r"// forceCompileSdk\n.*?\n}\n\n", "", g, flags=re.S)
            block = """// forceCompileSdk2
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext != null) {
            var done = false
            for (m in ext.javaClass.methods) {
                if (!done && m.name == "compileSdkVersion" && m.parameterTypes.size == 1 &&
                    (m.parameterTypes[0] == Int::class.javaPrimitiveType || m.parameterTypes[0] == Int::class.javaObjectType)) {
                    try { m.invoke(ext, 36); done = true } catch (e: Exception) { }
                }
            }
            if (!done) {
                for (m in ext.javaClass.methods) {
                    if (!done && m.name == "setCompileSdk" && m.parameterTypes.size == 1) {
                        try { m.invoke(ext, 36); done = true } catch (e: Exception) { }
                    }
                }
            }
            println("forceCompileSdk " + project.name + " -> " + done)
        }
    }
}

"""
            g = block + g
            with open(kts, "w", encoding="utf-8") as f:
                f.write(g)
        print("libraries compileSdk forced (kts)")
    elif os.path.exists(groovy):
        with open(groovy, encoding="utf-8") as f:
            g = f.read()
        if "forceCompileSdk" not in g:
            block = """// forceCompileSdk
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android { compileSdkVersion 36 }
        }
    }
}

"""
            with open(groovy, "w", encoding="utf-8") as f:
                f.write(block + g)
        print("libraries compileSdk forced (groovy)")


def add_proguard_rules():
    """قواعد R8 لنسخة الإصدار (مكتبة الإشعارات تستخدم Gson)"""
    app = os.path.join(ROOT, "android", "app")
    with open(os.path.join(app, "proguard-rules.pro"), "w", encoding="utf-8") as f:
        f.write("""-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**
""")
    kts = os.path.join(app, "build.gradle.kts")
    groovy = os.path.join(app, "build.gradle")
    if os.path.exists(kts):
        with open(kts, encoding="utf-8") as f:
            g = f.read()
        if "proguard-rules.pro" not in g:
            g = g.replace('signingConfig = signingConfigs.getByName("debug")',
                          'signingConfig = signingConfigs.getByName("debug")\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', 1)
            with open(kts, "w", encoding="utf-8") as f:
                f.write(g)
    elif os.path.exists(groovy):
        with open(groovy, encoding="utf-8") as f:
            g = f.read()
        if "proguard-rules.pro" not in g:
            g = g.replace("signingConfig = signingConfigs.debug",
                          "signingConfig = signingConfigs.debug\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'", 1)
            with open(groovy, "w", encoding="utf-8") as f:
                f.write(g)
    print("proguard rules added")



def copy_icons():
    src_root = os.path.join(ROOT, "android_res")
    for d in os.listdir(src_root):
        dst = os.path.join(RES, d)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(os.path.join(src_root, d)):
            shutil.copy(os.path.join(src_root, d, f), os.path.join(dst, f))

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""")
    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1C1C1D</color>
    <color name="splash_background">#141415</color>
</resources>
""")

    splash = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background"/>
    <item>
        <bitmap android:gravity="center" android:src="@mipmap/ic_launcher_foreground"/>
    </item>
</layer-list>
"""
    for d in ("drawable", "drawable-v21"):
        p = os.path.join(RES, d)
        if os.path.isdir(p):
            with open(os.path.join(p, "launch_background.xml"), "w", encoding="utf-8") as f:
                f.write(splash)
    print("icons and splash copied")


def download_font():
    dst_dir = os.path.join(ROOT, "assets", "fonts")
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, "Amiri-Regular.ttf")
    if os.path.exists(dst) and os.path.getsize(dst) > 100000:
        return
    urls = [
        "https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Regular.ttf",
        "https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf",
    ]
    for u in urls:
        try:
            urllib.request.urlretrieve(u, dst)
            if os.path.getsize(dst) > 100000:
                print("font downloaded")
                return
        except Exception as e:  # noqa
            print("font download failed:", u, e)
    raise SystemExit("could not download Amiri font")


def disable_lint_vital():
    """فحص lint لنسخة الإصدار ينهار مع بعض المكتبات (url_launcher)، فنوقفه — لا يؤثر على التطبيق"""
    android = os.path.join(ROOT, "android")
    kts = os.path.join(android, "build.gradle.kts")
    groovy = os.path.join(android, "build.gradle")
    if os.path.exists(kts):
        path, block = kts, """
// disableLintVital
subprojects {
    tasks.configureEach {
        if (name.startsWith("lintVital")) enabled = false
    }
}
"""
    elif os.path.exists(groovy):
        path, block = groovy, """
// disableLintVital
subprojects {
    tasks.configureEach { t ->
        if (t.name.startsWith("lintVital")) t.enabled = false
    }
}
"""
    else:
        return
    with open(path, encoding="utf-8") as f:
        g = f.read()
    if "disableLintVital" not in g:
        with open(path, "a", encoding="utf-8") as f:
            f.write(block)
    print("lint vital disabled")


if __name__ == "__main__":
    patch_manifest()
    add_icon_aliases()
    write_main_activity()
    write_widget()
    enable_desugaring()
    force_compile_sdk()
    add_proguard_rules()
    disable_lint_vital()
    copy_icons()
    download_font()
