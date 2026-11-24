class AppNotification {
  final int? id;
  final String uid;
  final String title;
  final String body;
  final DateTime triggeredAt;
  final bool isRead;

  const AppNotification({
    this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.triggeredAt,
    this.isRead = false,
  });

  Map<String, Object?> toDbMap() => {
    'uid': uid,
    'title': title,
    'body': body,
    'triggeredAt': triggeredAt.millisecondsSinceEpoch,
    'isRead': isRead ? 1 : 0,
  };

  factory AppNotification.fromDbMap(Map<String, Object?> map) {
    return AppNotification(
      id: map['id'] as int?,
      uid: (map['uid'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      triggeredAt: DateTime.fromMillisecondsSinceEpoch(
        (map['triggeredAt'] as int?) ?? 0,
      ),
      isRead: ((map['isRead'] as int?) ?? 0) == 1,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    uid: uid,
    title: title,
    body: body,
    triggeredAt: triggeredAt,
    isRead: isRead ?? this.isRead,
  );
}
