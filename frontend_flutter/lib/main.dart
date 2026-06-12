import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // ローカル認証情報で Firestore に接続できるように、プロジェクトIDを指定して初期化
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "dummy-key-for-native-sdk",
        appId: "1:dummy:web:dummy",
        messagingSenderId: "dummy",
        projectId: "project-20179432-3457-4d7f-9c5",
      ),
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  runApp(const AutoDevOpsDashboardApp());
}

class AutoDevOpsDashboardApp extends StatelessWidget {
  const AutoDevOpsDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoDevOps Agent Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        cardColor: const Color(0xFF1E1E24),
        primaryColor: const Color(0xFF6366F1),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          error: Color(0xFFEF4444),
          surface: Color(0xFF1E1E24),
        ),
        dividerColor: const Color(0xFF2E2E38),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedFilter = 'pending';
  DocumentSnapshot? _selectedFix;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            const Text(
              'AutoDevOps Agent',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, py: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Phase 3',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1E),
        elevation: 0,
        actions: [
          // フィルター選択
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('未処理'), icon: Icon(Icons.hourglass_empty)),
                ButtonSegment(value: 'merged', label: Text('承認済'), icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(value: 'rejected', label: Text('却下済'), icon: Icon(Icons.cancel_outlined)),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedFilter = newSelection.first;
                  _selectedFix = null; // フィルター切り替え時に選択を解除
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF6366F1);
                  }
                  return const Color(0xFF1E1E24);
                }),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // 左側: エラー一覧
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFF2E2E38)),
                ),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('auto_fixes')
                    .where('status', isEqualTo: _selectedFilter)
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('エラーが発生しました: ${snapshot.error}'),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text(
                            '表示する提案はありません',
                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isSelected = _selectedFix?.id == doc.id;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withOpacity(0.15)
                              : const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF2E2E38),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['target_file'] ?? 'Unknown File',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusBadge(data['status']),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                data['error_message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatTimestamp(data['created_at']),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedFix = doc;
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // 右側: 詳細ビュー
          Expanded(
            flex: 3,
            child: _selectedFix == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('左側のリストから修正提案を選択してください。', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : FixDetailView(
                    fixDoc: _selectedFix!,
                    onActionComplete: () {
                      setState(() {
                        _selectedFix = null;
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color = Colors.grey;
    String label = 'UNKNOWN';
    if (status == 'pending') {
      color = const Color(0xFFF59E0B);
      label = 'PENDING';
    } else if (status == 'merged') {
      color = const Color(0xFF10B981);
      label = 'MERGED';
    } else if (status == 'rejected') {
      color = const Color(0xFFEF4444);
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}

class FixDetailView extends StatelessWidget {
  final DocumentSnapshot fixDoc;
  final VoidCallback onActionComplete;

  const FixDetailView({
    super.key,
    required this.fixDoc,
    required this.onActionComplete,
  });

  Map<String, dynamic> get data => fixDoc.data() as Map<String, dynamic>;

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String originalCode = data['original_code'] ?? '';
    final String fixedCode = data['fixed_code'] ?? '';
    final String? prUrl = data['github_pr_url'];
    final String status = data['status'] ?? 'pending';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー情報
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['target_file'] ?? 'Unknown File',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${fixDoc.id}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (prUrl != null && prUrl.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _launchURL(prUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('GitHub PRを開く'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF24292F), // GitHubカラー
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const Divider(height: 32),

          // エラーログ表示
          const Text(
            'エラー内容',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F11),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2E2E38)),
            ),
            child: Text(
              data['error_message'] ?? 'ログ情報なし',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFF3F4F6),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // コードの比較（横並び）
          const Text(
            'ソースコード比較 (左: 修正前 / 右: 修正後)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                // 修正前
                Expanded(
                  child: CodeViewerPanel(
                    code: originalCode,
                    title: 'ORIGINAL',
                    borderColor: const Color(0xFFEF4444).withOpacity(0.5),
                    headerColor: const Color(0xFFEF4444).withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 16),
                // 修正後
                Expanded(
                  child: CodeViewerPanel(
                    code: fixedCode,
                    title: 'PROPOSED FIX',
                    borderColor: const Color(0xFF10B981).withOpacity(0.5),
                    headerColor: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // アクションボタン（ステータスが pending の時のみ表示）
          if (status == 'pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _updateFixStatus('rejected'),
                  icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
                  label: const Text('却下する', style: TextStyle(color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _updateFixStatus('merged'),
                  icon: const Icon(Icons.check),
                  label: const Text('承認してマージする'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _updateFixStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('auto_fixes')
          .document(fixDoc.id)
          .update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      onActionComplete();
    } catch (e) {
      debugPrint("Failed to update status: $e");
    }
  }
}

class CodeViewerPanel extends StatelessWidget {
  final String code;
  final String title;
  final Color borderColor;
  final Color headerColor;

  const CodeViewerPanel({
    super.key,
    required this.code,
    required this.title,
    required this.borderColor,
    required this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: title == 'ORIGINAL' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  code.isEmpty ? '// 差分なし' : code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
