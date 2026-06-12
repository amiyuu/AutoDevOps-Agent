import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident.dart';

// デモ用のインシデントモックデータ
final List<Incident> _mockInitialIncidents = [
  Incident(
    id: 'incident-history-1',
    status: 'completed',
    errorMessage: 'NullPointerException: Attempt to invoke virtual method on a null object reference\n  at com.example.service.UserService.getUserDetails(UserService.java:82)',
    triggerSource: 'cloud_logging',
    repository: 'sakauchikanato/user-api',
    baseBranch: 'main',
    bugBranch: 'fix/user-details-npe',
    prUrl: 'https://github.com/sakauchikanato/user-api/pull/12',
    diff: '@@ -81,3 +81,7 @@\n UserDetails getUserDetails(String userId) {\n-    return userRepository.findById(userId).getDetails();\n+    User user = userRepository.findById(userId);\n+    if (user == null) {\n+        return UserDetails.empty();\n+    }\n+    return user.getDetails();\n }',
    thoughts: [
      'インシデントを検知しました。AIエージェントの起動準備をしています...',
      'エラーログの解析完了: UserService.java:82 で NullPointerException が発生。',
      'ソースコードの取得成功。引数 userId の結果が null の場合に考慮が漏れている箇所を特定。',
      '修正用ブランチ fix/user-details-npe を作成しました。',
      '自動修正PRを作成しました。承認待ち...',
      'マージが承認されました。本番デプロイ及び修復完了！'
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 55)),
  )
];

class IncidentState {
  final List<Incident> incidents;
  final bool isDemoMode;
  final bool isFirebaseConnected;
  final String? activeIncidentId; // 詳細画面で開いているインシデントID
  final String? errorMessage;

  IncidentState({
    required this.incidents,
    required this.isDemoMode,
    required this.isFirebaseConnected,
    this.activeIncidentId,
    this.errorMessage,
  });

  IncidentState copyWith({
    List<Incident>? incidents,
    bool? isDemoMode,
    bool? isFirebaseConnected,
    String? activeIncidentId,
    String? errorMessage,
  }) {
    return IncidentState(
      incidents: incidents ?? this.incidents,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      isFirebaseConnected: isFirebaseConnected ?? this.isFirebaseConnected,
      activeIncidentId: activeIncidentId ?? this.activeIncidentId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class IncidentNotifier extends StateNotifier<IncidentState> {
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  Timer? _simulationTimer;
  int _simStep = 0;

  IncidentNotifier()
      : super(IncidentState(
          incidents: [..._mockInitialIncidents],
          isDemoMode: true, // デフォルトはデモモード（プレゼン安全対策）
          isFirebaseConnected: false,
          errorMessage: null,
        )) {
    // 起動時にデモ用の初期インシデントを読み込む
    _setupFirestoreListener();
  }

  void _setupFirestoreListener() {
    _firestoreSubscription?.cancel();
    
    if (state.isDemoMode) {
      // デモモード時はFirestoreを聴かない
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      state = state.copyWith(isFirebaseConnected: true, errorMessage: null);
      
      _firestoreSubscription = firestore
          .collection('incidents')
          .orderBy('created_at', descending: true)
          .snapshots()
          .listen((snapshot) {
            final firestoreIncidents = snapshot.docs.map((doc) {
              return Incident.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
            
            // モック履歴とFirestoreデータを統合
            state = state.copyWith(
              incidents: [...firestoreIncidents, ..._mockInitialIncidents],
              errorMessage: null,
            );
          }, onError: (e) {
            print("Firestore Error: $e. Falling back to Demo Mode.");
            state = state.copyWith(
              isDemoMode: true, 
              isFirebaseConnected: false,
              errorMessage: "Firestore Error: $e",
            );
          });
    } catch (e) {
      print("Firebase not initialized or failed: $e. Using local Demo Mode.");
      state = state.copyWith(
        isDemoMode: true, 
        isFirebaseConnected: false,
        errorMessage: "Firebase not initialized or failed: $e",
      );
    }
  }

  void toggleDemoMode() {
    final newDemoMode = !state.isDemoMode;
    state = state.copyWith(isDemoMode: newDemoMode, errorMessage: null);
    
    if (newDemoMode) {
      _firestoreSubscription?.cancel();
      // デモモード切り替え時にモックデータを再セット
      state = state.copyWith(incidents: [..._mockInitialIncidents]);
    } else {
      _setupFirestoreListener();
    }
  }

  void selectIncident(String? id) {
    state = state.copyWith(activeIncidentId: id);
  }

  // =========================================================================
  // ⚡️ デモモード用: 自律自動修復のリアルタイムシミュレーション
  // =========================================================================
  
  void triggerMockIncident() {
    if (!state.isDemoMode) return;
    
    _simulationTimer?.cancel();
    _simStep = 0;
    
    final newIncidentId = 'demo-incident-${DateTime.now().millisecondsSinceEpoch}';
    final newIncident = Incident(
      id: newIncidentId,
      status: 'pending',
      errorMessage: 'Traceback (most recent call last):\n  File "app/main.py", line 48, in handle_request\n    return calculate_average(items)\n  File "app/main.py", line 44, in calculate_average\n    return sum(numbers) / len(numbers)\nZeroDivisionError: division by zero',
      triggerSource: 'github_actions',
      repository: 'sakauchikanato/demo-repo',
      baseBranch: 'main',
      bugBranch: '',
      prUrl: '',
      diff: '',
      thoughts: ['インシデントを検知しました。AIエージェントの起動準備をしています...'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // インシデントリストの先頭に追加し、それをアクティブにする
    state = state.copyWith(
      incidents: [newIncident, ...state.incidents],
      activeIncidentId: newIncidentId,
    );

    // AIの自律思考プロセスをシミュレーション開始 (3秒ごとにステップが進む)
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _simStep++;
      _runSimulationStep(newIncidentId);
    });
  }

  void _runSimulationStep(String incidentId) {
    final index = state.incidents.indexWhere((element) => element.id == incidentId);
    if (index == -1) return;
    
    final current = state.incidents[index];
    Incident updated = current;

    switch (_simStep) {
      case 1:
        updated = current.copyWith(
          status: 'analyzing',
          thoughts: [
            ...current.thoughts,
            'Analyzing error log and locating the buggy source file...',
            'GitHubリポジトリ sakauchikanato/demo-repo から app/main.py のソースコードを読み込んでいます...'
          ],
          updatedAt: DateTime.now(),
        );
        break;
      case 2:
        updated = current.copyWith(
          status: 'fixing',
          thoughts: [
            ...current.thoughts,
            'Generating bugfix patch and submitting Pull Request...',
            'AI自動修正ブランチ fix/zero-division-error を作成し、GitHub PRを作成中...'
          ],
          diff: '@@ -41,6 +41,10 @@\n def calculate_average(numbers):\n-    # Bug: Raises ZeroDivisionError if list is empty\n-    return sum(numbers) / len(numbers)\n+    # Bug Fix: list size safety check added\n+    if not numbers or len(numbers) == 0:\n+        return 0.0\n+    return sum(numbers) / len(numbers)',
          updatedAt: DateTime.now(),
        );
        break;
      case 3:
        updated = current.copyWith(
          status: 'waiting_approval',
          bugBranch: 'fix/zero-division-error',
          prUrl: 'https://github.com/sakauchikanato/demo-repo/pull/42',
          thoughts: [
            ...current.thoughts,
            'バグ修正案が完成しました！開発者のコックピットでの承認をお待ちしています。🚨'
          ],
          updatedAt: DateTime.now(),
        );
        _simulationTimer?.cancel(); // 承認待ちでタイマーを停止
        break;
    }

    final list = [...state.incidents];
    list[index] = updated;
    state = state.copyWith(incidents: list);
  }

  // =========================================================================
  // 🔘 人間の承認アクション
  // =========================================================================
  
  Future<void> approveIncident(String incidentId) async {
    final index = state.incidents.indexWhere((element) => element.id == incidentId);
    if (index == -1) return;

    if (!state.isDemoMode && state.isFirebaseConnected) {
      // 1. 本番モード: Firebase Firestore のドキュメントステータスを更新
      try {
        await FirebaseFirestore.instance
            .collection('incidents')
            .doc(incidentId)
            .update({
              'status': 'approved',
              'thoughts': FieldValue.arrayUnion(['マージが承認されました。自動マージとデプロイを実行します...'])
            });
      } catch (e) {
        print("Failed to approve in Firestore: $e");
      }
    } else {
      // 2. デモモード: ローカルアニメーションシミュレーション
      final current = state.incidents[index];
      
      // 承認中 (approved) に更新
      var list = [...state.incidents];
      list[index] = current.copyWith(
        status: 'approved',
        thoughts: [...current.thoughts, 'マージが承認されました。自動マージと本番デプロイを実行します...'],
        updatedAt: DateTime.now(),
      );
      state = state.copyWith(incidents: list);

      // 4秒後に修復完了 (completed) にする
      await Future.delayed(const Duration(seconds: 4));
      
      final latestList = [...state.incidents];
      final latestIndex = latestList.indexWhere((element) => element.id == incidentId);
      if (latestIndex != -1) {
        latestList[latestIndex] = latestList[latestIndex].copyWith(
          status: 'completed',
          thoughts: [...latestList[latestIndex].thoughts, '本番環境への自動デプロイが成功し、システムが正常に復旧しました！🎉'],
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(incidents: latestList);
      }
    }
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}

// Riverpod プロバイダーの定義
final incidentProvider = StateNotifierProvider<IncidentNotifier, IncidentState>((ref) {
  return IncidentNotifier();
});
