
class Reclamation {
  final int? id;
  final int userId;
  final String subject;
  final String message;
  final String type;
  final String status;
  final DateTime timestamp;
  final String? response;
  final String? attachmentUrl;
  final String? attachmentType;

  Reclamation({
    this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.type,
    this.status = 'EN_ATTENTE',
    required this.timestamp,
    this.response,
    this.attachmentUrl,
    this.attachmentType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'message': message,
      'type': type,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'response': response,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
    };
  }

  static Reclamation fromMap(Map<String, dynamic> map) {
    return Reclamation(
      id: map['id'],
      userId: map['user_id'],
      subject: map['subject'],
      message: map['message'],
      type: map['type'],
      status: map['status'],
      timestamp: DateTime.parse(map['timestamp']),
      response: map['response'],
      attachmentUrl: map['attachment_url'],
      attachmentType: map['attachment_type'],
    );
  }

  Reclamation copyWith({
    int? id,
    int? userId,
    String? subject,
    String? message,
    String? type,
    String? status,
    DateTime? timestamp,
    String? response,
  }) {
    return Reclamation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      response: response ?? this.response,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
    );
  }
}

