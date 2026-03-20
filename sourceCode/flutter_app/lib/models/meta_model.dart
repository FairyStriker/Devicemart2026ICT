// lib/models/meta_model.dart

class MetaModel {
  final String stage;
  final int timestamp;
  final String? userId;
  final String? userName;

  MetaModel({
    required this.stage,
    required this.timestamp,
    this.userId,
    this.userName,
  });

  factory MetaModel.fromJson(Map<String, dynamic> json) {
    return MetaModel(
      stage: json['stage'] ?? 'boot',
      timestamp: json['timestamp'] ?? 0,
      userId: json['user_id'],
      userName: json['user_name'],
    );
  }

  // 기본값 (앱 시작 전)
  factory MetaModel.initial() {
    return MetaModel(stage: 'boot', timestamp: 0);
  }
}
