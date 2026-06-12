import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/incident_provider.dart';
import '../models/incident.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(incidentProvider);
    final notifier = ref.read(incidentProvider.notifier);
    
    // 現在開いているインシデントを取得
    final incidentId = state.activeIncidentId;
    final incidentIndex = state.incidents.indexWhere((element) => element.id == incidentId);
    
    if (incidentIndex == -1) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0E12),
        body: Center(child: Text('Incident not found', style: TextStyle(color: Colors.white))),
      );
    }
    
    final incident = state.incidents[incidentIndex];

    Color themeColor;
    switch (incident.status) {
      case 'pending':
        themeColor = const Color(0xFFFF3366);
        break;
      case 'analyzing':
      case 'fixing':
        themeColor = const Color(0xFFFF9900);
        break;
      case 'waiting_approval':
        themeColor = const Color(0xFF00F0FF);
        break;
      case 'approved':
        themeColor = const Color(0xFF00F0FF);
        break;
      case 'completed':
        themeColor = const Color(0xFF00E676);
        break;
      default:
        themeColor = Colors.grey;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161822),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            notifier.selectIncident(null);
            Navigator.pop(context);
          },
        ),
        title: Text(
          'AUTO-RECOVERY CORE',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. トップ概要パネル
              _buildSummaryHeader(incident, themeColor),
              const SizedBox(height: 20),

              // 2. AI思考プロセスタイムライン
              _buildTimelineSection(incident, themeColor),
              const SizedBox(height: 20),

              // 3. エラーログ（スタックトレース）
              _buildErrorLogSection(incident),
              const SizedBox(height: 20),

              // 4. 修正パッチ (Diff Viewer)
              if (incident.diff.isNotEmpty) ...[
                _buildDiffViewerSection(incident),
                const SizedBox(height: 24),
              ],

              // 5. アクションボタン (GitHub遷移 & 承認ボタン)
              _buildActionButtons(context, ref, incident, themeColor),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 🎨 UI 構築ヘルパー
  // =========================================================================

  Widget _buildSummaryHeader(Incident incident, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TARGET REPOSITORY',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'TRIGGER: ${incident.triggerSource.toUpperCase()}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            incident.repository,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF262938), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BASE BRANCH', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.commit_rounded, color: Colors.grey, size: 14),
                      const SizedBox(width: 4),
                      Text(incident.baseBranch, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              if (incident.bugBranch.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('BUGFIX BRANCH', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.alt_route_rounded, color: Color(0xFFFF9900), size: 14),
                        const SizedBox(width: 4),
                        Text(incident.bugBranch, style: GoogleFonts.outfit(color: const Color(0xFFFF9900), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(Incident incident, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262938), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFF00F0FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'AI AGENT SELF-HEALING THOUGHTS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // タイムラインステップのビルド
          ...List.generate(incident.thoughts.length, (index) {
            final isLast = index == incident.thoughts.length - 1;
            final thought = incident.thoughts[index];
            final isAnalyzing = incident.status == 'analyzing' || incident.status == 'fixing' || incident.status == 'approved';

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側の縦棒と丸インジケータ
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isLast && isAnalyzing ? themeColor : const Color(0xFF00F0FF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (isLast && isAnalyzing)
                            BoxShadow(
                              color: themeColor.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                    ).animate(target: (isLast && isAnalyzing) ? 1.0 : 0.0)
                     .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 600.ms)
                     .fadeIn(),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: const Color(0xFF262938),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // 思考ログテキスト
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0.0),
                    child: Text(
                      thought,
                      style: GoogleFonts.outfit(
                        color: isLast ? Colors.white : Colors.grey.shade400,
                        fontSize: 12.5,
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildErrorLogSection(Incident incident) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262938), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, color: Color(0xFFFF3366), size: 20),
              const SizedBox(width: 8),
              Text(
                'DETECTED ERROR LOGS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ターミナル風表示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF07080A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F2230), width: 1),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                incident.errorMessage.trim(),
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFFF5252),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffViewerSection(Incident incident) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262938), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.code_rounded, color: Color(0xFF00E676), size: 20),
              const SizedBox(width: 8),
              Text(
                'AI SUGGESTED CODE CHANGES (DIFF)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 差分パース表示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF07080A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F2230), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: incident.diff.split('\n').map((line) {
                Color textColor = Colors.grey.shade400;
                Color bgColor = Colors.transparent;

                if (line.startsWith('+') && !line.startsWith('+++')) {
                  textColor = const Color(0xFF00E676);
                  bgColor = const Color(0xFF00E676).withOpacity(0.08);
                } else if (line.startsWith('-') && !line.startsWith('---')) {
                  textColor = const Color(0xFFFF3366);
                  bgColor = const Color(0xFFFF3366).withOpacity(0.08);
                } else if (line.startsWith('@@')) {
                  textColor = const Color(0xFF00F0FF);
                  bgColor = const Color(0xFF00F0FF).withOpacity(0.03);
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    line,
                    style: GoogleFonts.jetBrainsMono(
                      color: textColor,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Incident incident, Color themeColor) {
    final notifier = ref.read(incidentProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // GitHub PRのリンク遷移 (PRがある場合)
        if (incident.prUrl.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () => _launchURL(context, incident.prUrl),
            icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF00F0FF), size: 18),
            label: Text(
              'VIEW PULL REQUEST ON GITHUB',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 13,
                color: const Color(0xFF00F0FF),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF00F0FF), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 承認ボタン (マージ実行)
        if (incident.status == 'waiting_approval')
          ElevatedButton.icon(
            onPressed: () => notifier.approveIncident(incident.id),
            icon: const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
            label: Text(
              'APPROVE & MERGE PATCH',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 12,
              shadowColor: const Color(0xFF00F0FF).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .shimmer(delay: 1500.ms, duration: 1500.ms)
        else if (incident.status == 'approved')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF161822),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00F0FF), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'APPLYING PATCH & DEPLOYING...',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00F0FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          )
        else if (incident.status == 'completed')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 20),
                const SizedBox(width: 8),
                Text(
                  'SYSTEM FULLY RECOVERED',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('リンクを開けませんでした: $urlString'),
          backgroundColor: const Color(0xFFFF3366),
        ),
      );
    }
  }
}
