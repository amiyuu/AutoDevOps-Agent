import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String id;
  final String status; // 'pending' | 'analyzing' | 'fixing' | 'waiting_approval' | 'approved' | 'completed' | 'failed'
  final String errorMessage;
  final String triggerSource;
  final String repository;
  final String baseBranch;
  final String bugBranch;
  final String prUrl;
  final String diff;
  final List<String> thoughts;
  final DateTime createdAt;
  final DateTime updatedAt;

  Incident({
    required this.id,
    required this.status,
    required this.errorMessage,
    required this.triggerSource,
    required this.repository,
    required this.baseBranch,
    required this.bugBranch,
    required this.prUrl,
    required this.diff,
    required this.thoughts,
    required this.createdAt,
    required this.updatedAt,
  });

  Incident copyWith({
    String? id,
    String? status,
    String? errorMessage,
    String? triggerSource,
    String? repository,
    String? baseBranch,
    String? bugBranch,
    String? prUrl,
    String? diff,
    List<String>? thoughts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Incident(
      id: id ?? this.id,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      triggerSource: triggerSource ?? this.triggerSource,
      repository: repository ?? this.repository,
      baseBranch: baseBranch ?? this.baseBranch,
      bugBranch: bugBranch ?? this.bugBranch,
      prUrl: prUrl ?? this.prUrl,
      diff: diff ?? this.diff,
      thoughts: thoughts ?? this.thoughts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'error_message': errorMessage,
      'trigger_source': triggerSource,
      'repository': repository,
      'base_branch': baseBranch,
      'bug_branch': bugBranch,
      'pr_url': prUrl,
      'diff': diff,
      'thoughts': thoughts,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  factory Incident.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Incident(
      id: documentId,
      status: map['status'] ?? 'pending',
      errorMessage: map['error_message'] ?? '',
      triggerSource: map['trigger_source'] ?? 'unknown',
      repository: map['repository'] ?? '',
      baseBranch: map['base_branch'] ?? 'main',
      bugBranch: map['bug_branch'] ?? '',
      prUrl: map['pr_url'] ?? '',
      diff: map['diff'] ?? '',
      thoughts: List<String>.from(map['thoughts'] ?? []),
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
    );
  }

  // ステータスに応じた日本語ラベルを取得
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'インシデント検知 (待機中)';
      case 'analyzing':
        return 'AI原因解析中...';
      case 'fixing':
        return 'AI修正パッチ作成中...';
      case 'waiting_approval':
        return '修復承認待ち (要確認) 🚨';
      case 'approved':
        return '承認済・マージ実行中...';
      case 'completed':
        return '修復完了 (システム正常復旧) 🎉';
      case 'failed':
        return '修復失敗 ⚠️';
      default:
        return 'ステータス不明';
    }
  }

  // ステータス進行割合 (0.0 〜 1.0) - UIの進捗インジケータ用
  double get progressPercentage {
    switch (status) {
      case 'pending':
        return 0.15;
      case 'analyzing':
        return 0.40;
      case 'fixing':
        return 0.65;
      case 'waiting_approval':
        return 0.85;
      case 'approved':
        return 0.95;
      case 'completed':
        return 1.0;
      case 'failed':
        return 1.0;
      default:
        return 0.0;
    }
  }
}
