class NotificationModel {
  final int? id;
  final int userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime timestamp;

  NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = 'INFO',
    this.isRead = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static NotificationModel fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      message: map['message'],
      type: map['type'],
      isRead: map['is_read'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

