class Message {
  final int? id;
  final int senderId;
  final int? receiverId;
  final int? groupId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentType;
  final String? attachmentUrl;

  Message({
    this.id,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.attachmentType,
    this.attachmentUrl,
  }) : assert(receiverId != null || groupId != null, 'Either receiverId or groupId must be provided');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'group_id': groupId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'attachment_type': attachmentType,
      'attachment_url': attachmentUrl,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int?,
      senderId: map['sender_id'] as int,
      receiverId: map['receiver_id'] as int?,
      groupId: map['group_id'] as int?,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: (map['is_read'] as int? ?? 0) == 1,
      attachmentType: map['attachment_type'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
    );
  }
}

