import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/incident_provider.dart';
import '../models/incident.dart';
import 'incident_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(incidentProvider);
    final notifier = ref.read(incidentProvider.notifier);

    ref.listen<IncidentState>(incidentProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage!,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF3366),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: '閉じる',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    // 未修復のインシデントがあるか確認
    final unresolvedCount = state.incidents.where((i) => i.status != 'completed' && i.status != 'failed').length;
    final hasActiveIncident = unresolvedCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161822),
        elevation: 0,
        title: Text(
          'AUTO DEVOPS COCKPIT',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFF00F0FF),
            fontSize: 20,
          ),
        ),
        actions: [
          // デモモード切り替えトグル
          Row(
            children: [
              Text(
                'DEMO MODE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: state.isDemoMode ? const Color(0xFFFF9900) : Colors.grey,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: state.isDemoMode,
                onChanged: (_) => notifier.toggleDemoMode(),
                activeColor: const Color(0xFFFF9900),
                activeTrackColor: const Color(0xFFFF9900).withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              hasActiveIncident 
                ? const Color(0xFFFF3366).withOpacity(0.08) 
                : const Color(0xFF00F0FF).withOpacity(0.04),
              const Color(0xFF0D0E12),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ⚡️ システムヘッダーステータス (アニメーション付き)
              _buildSystemStatusHeader(hasActiveIncident, unresolvedCount)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.1, end: 0.0),
              const SizedBox(height: 24),

              // 🕹️ デモ発生コントロールパネル (デモモード時のみ表示)
              if (state.isDemoMode)
                Card(
                  color: const Color(0xFF161822),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFFF9900), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRESENTATION TRIGGER',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF9900),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'デモ用の疑似ゼロ除算エラーを発生させ、AI自動修正のリアルタイム推論フローを起動します。',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => notifier.triggerMockIncident(),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                          label: Text(
                            'SIMULATE ERROR',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9900),
                            elevation: 8,
                            shadowColor: const Color(0xFFFF9900).withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .shimmer(delay: 2000.ms, duration: 1500.ms),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
              
              if (state.isDemoMode) const SizedBox(height: 24),

              // リストセクションタイトル
              Text(
                'MONITORED INCIDENTS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 12),

              // インシデントリスト
              Expanded(
                child: state.incidents.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: state.incidents.length,
                        itemBuilder: (context, index) {
                          final incident = state.incidents[index];
                          return _buildIncidentCard(context, ref, incident, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 🎨 UI 構築コンポーネントヘルパー
  // =========================================================================

  Widget _buildSystemStatusHeader(bool hasActiveIncident, int unresolvedCount) {
    final statusColor = hasActiveIncident ? const Color(0xFFFF3366) : const Color(0xFF00F0FF);
    final statusText = hasActiveIncident ? 'INCIDENTS UNRESOLVED' : 'SYSTEM FULLY SECURED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: -4,
          )
        ],
      ),
      child: Row(
        children: [
          // 点滅するインジケータードット
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 800.ms)
           .fadeIn(duration: 800.ms),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasActiveIncident 
                    ? 'AIが自動修復サイクルを実行中。$unresolvedCount 件のアクションが必要です。'
                    : '本番環境およびCI/CDビルドに異常はありません。AIが自律監視中。',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(BuildContext context, WidgetRef ref, Incident incident, int index) {
    Color cardBorderColor;
    Color glowColor;
    IconData statusIcon;

    switch (incident.status) {
      case 'pending':
        cardBorderColor = const Color(0xFFFF3366);
        glowColor = const Color(0xFFFF3366).withOpacity(0.08);
        statusIcon = Icons.error_outline_rounded;
        break;
      case 'analyzing':
      case 'fixing':
        cardBorderColor = const Color(0xFFFF9900);
        glowColor = const Color(0xFFFF9900).withOpacity(0.08);
        statusIcon = Icons.psychology_rounded;
        break;
      case 'waiting_approval':
        cardBorderColor = const Color(0xFF00F0FF);
        glowColor = const Color(0xFF00F0FF).withOpacity(0.12);
        statusIcon = Icons.verified_user_rounded;
        break;
      case 'approved':
        cardBorderColor = const Color(0xFF00F0FF);
        glowColor = const Color(0xFF00F0FF).withOpacity(0.05);
        statusIcon = Icons.autorenew_rounded;
        break;
      case 'completed':
        cardBorderColor = const Color(0xFF00E676);
        glowColor = Colors.transparent;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        cardBorderColor = Colors.grey.shade800;
        glowColor = Colors.transparent;
        statusIcon = Icons.help_outline_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF161822),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor.withOpacity(0.6), width: 1.2),
      ),
      elevation: 4,
      shadowColor: glowColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(incidentProvider.notifier).selectIncident(incident.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IncidentDetailScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // トリガーソースとブランチ
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBorderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          incident.triggerSource.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: cardBorderColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${incident.repository} [${incident.baseBranch}]',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                  // 日付
                  Text(
                    _formatTime(incident.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // エラー概要
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusIcon, color: cardBorderColor, size: 24)
                      .animate(target: (incident.status == 'analyzing' || incident.status == 'fixing' || incident.status == 'approved') ? 1.0 : 0.0)
                      .custom(
                        duration: 1000.ms,
                        builder: (context, val, child) => Transform.rotate(
                          angle: val * 2 * 3.14159,
                          child: child,
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                       .fadeIn(duration: 500.ms),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.errorMessage.split('\n').lastWhere(
                                (element) => element.trim().isNotEmpty,
                                orElse: () => 'System Error Detected',
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          incident.statusLabel,
                          style: GoogleFonts.outfit(
                            color: cardBorderColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 進捗バー (AI修復時のリアルなステータス変化用)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: incident.progressPercentage,
                  backgroundColor: Colors.grey.shade900,
                  valueColor: AlwaysStoppedAnimation<Color>(cardBorderColor),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: (index * 80).ms).slideY(begin: 0.08, end: 0.0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text(
            'NO ACTIVE INCIDENTS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '全てのシステムは安全に保護されています。',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}時間前';
    }
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
