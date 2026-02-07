import '../models/notification_model.dart';
import '../models/user.dart';
import '../data/database_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> notifyUser({
    required int userId,
    required String title,
    required String message,
    String type = 'INFO',
  }) async {
    final notif = NotificationModel(
      userId: userId,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.createNotification(notif);
  }

  Future<void> notifyRole({
    required UserRole role,
    required String title,
    required String message,
    String type = 'INFO',
  }) async {
    final users = await DatabaseHelper.instance.getUsersByRole(role);
    for (var user in users) {
      if (user.id != null) {
        await notifyUser(userId: user.id!, title: title, message: message, type: type);
      }
    }
  }

  Future<void> notifyGroup({
    required int groupId,
    required String title,
    required String message,
    String type = 'INFO',
  }) async {
    final users = await DatabaseHelper.instance.getUsersByGroupe(groupId);
    for (var user in users) {
      if (user.id != null) {
        await notifyUser(userId: user.id!, title: title, message: message, type: type);
      }
    }
  }
}

