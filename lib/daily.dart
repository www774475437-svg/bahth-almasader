import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'daily_benefit.dart';
import 'settings.dart';
import 'storage.dart';

/// مفتاح التنقل العام (لفتح الصفحات عند الضغط على إشعار)
final navigatorKey = GlobalKey<NavigatorState>();

/// يُضبط من HomeShell لمعالجة الضغط على الإشعار
void Function(String payload)? onNotificationTap;

/// الإشعارات: «فائدة اليوم» والتذكيرات، وويدجت الشاشة الرئيسية
class Daily {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool ready = false;
  static String? launchPayload;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) onNotificationTap?.call(p);
        },
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        launchPayload = launch.notificationResponse?.payload;
      }
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await a?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  static String short(String s, int n) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > n ? '${t.substring(0, n)}…' : t;
  }

  /// يجدول إشعارًا في وقت محلي محدد
  static Future<void> scheduleAt(
    int id,
    String title,
    String body,
    DateTime when, {
    String? payload,
    String channelId = 'reminders',
    String channelName = 'التذكيرات',
  }) async {
    if (!ready || !when.isAfter(DateTime.now())) return;
    await plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.UTC),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> cancelRange(int from, int count) async {
    if (!ready) return;
    for (var i = 0; i < count; i++) {
      try {
        await plugin.cancel(from + i);
      } catch (_) {}
    }
  }

  /// يحدّث الويدجت ويجدول «فائدة اليوم» للأيام السبعة القادمة
  static Future<void> refresh() async {
    await _updateWidget();
    await _scheduleFawaid();
  }

  static Future<void> _updateWidget() async {
    try {
      final hit = DailyBenefit.today() ?? Store.instance.dailyPick()?.hit;
      await HomeWidget.saveWidgetData<String>(
          'fawaid_text', hit == null ? 'افتح التطبيق لتظهر فائدة اليوم هنا' : '«${short(hit.snippet, 220)}»');
      await HomeWidget.saveWidgetData<String>(
          'fawaid_source', hit == null ? 'بحث المصادر' : '📓 ${hit.bookName} (صـ ${hit.volPage})');
      await HomeWidget.updateWidget(androidName: 'FawaidWidgetProvider');
    } catch (_) {}
  }

  static Future<void> _scheduleFawaid() async {
    if (!ready) return;
    try {
      await cancelRange(100, 7);
      final s = Settings.instance;
      final saved = Store.instance.saved;
      if (!s.dailyNotify) return;

      final rnd = Random();
      final now = DateTime.now();
      var first = DateTime(now.year, now.month, now.day, s.notifyHour);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));

      for (var i = 0; i < 7; i++) {
        final when = DateTime(first.year, first.month, first.day + i, s.notifyHour);
        final approved = DailyBenefit.forDay(when);
        if (approved == null && saved.isEmpty) continue;
        final hit = approved ?? saved[rnd.nextInt(saved.length)].hit;
        final body = '«${short(hit.snippet, 300)}»\n📓 ${hit.bookName} (صـ ${hit.volPage})';
        await scheduleAt(100 + i, 'فائدة اليوم 🌿', body, when,
            channelId: 'daily_fawaid', channelName: 'فائدة اليوم', payload: approved == null ? 'saved' : 'daily');
      }
    } catch (_) {}
  }
}
