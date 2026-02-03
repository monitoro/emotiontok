class Letter {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final String sender;
  bool isRead;

  Letter({
    required this.id,
    this.title = '위로의 편지',
    required this.content,
    required this.timestamp,
    this.sender = 'SaRr',
    this.isRead = false,
  });

  String get previewText {
    // Return a short preview of the content (first 50 characters)
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'sender': sender,
      'isRead': isRead,
    };
  }

  factory Letter.fromMap(Map<String, dynamic> map) {
    return Letter(
      id: map['id'] ?? '',
      title: map['title'] ?? '위로의 편지',
      content: map['content'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      sender: map['sender'] ?? 'SaRr',
      isRead: map['isRead'] ?? false,
    );
  }
}
