import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../main.dart';

class ReminderNotificationService {
  ReminderNotificationService._();

  static Future<void> scheduleReminderNotification({
    required String reminderId,
    required String title,
    required String body,
    required DateTime reminderDateTime,
    required bool sound,
    int minutesBefore = 10,
  }) async {
    final DateTime notificationTime = reminderDateTime.subtract(
      Duration(minutes: minutesBefore),
    );

    if (notificationTime.isBefore(DateTime.now())) return;

    await notificationsPlugin.zonedSchedule(
      reminderId.hashCode,
      title,
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminder Notifications',
          channelDescription: 'Notifications before reminder time',
          importance: Importance.max,
          priority: Priority.high,
          playSound: sound,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: sound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminderNotification(String reminderId) async {
    await notificationsPlugin.cancel(reminderId.hashCode);
  }
}
