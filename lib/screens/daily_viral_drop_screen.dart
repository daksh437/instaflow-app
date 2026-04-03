import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/daily_drop_model.dart';
import '../models/user_model.dart';
import '../services/daily_drop_service.dart';
import '../services/analytics_service.dart';
import '../services/voice_service.dart';
import '../widgets/voice_play_button.dart';
import '../widgets/upgrade_dialog.dart';

/// Daily Viral Drop: 1 claim per day. Reset at midnight. dailyDropCount, dailyDropLastDate on user doc.
class DailyViralDropScreen extends StatefulWidget {
  const DailyViralDropScreen({super.key});

  @override
  State<DailyViralDropScreen> createState() => _DailyViralDropScreenState();
}

class _DailyViralDropScreenState extends State<DailyViralDropScreen>
    with SingleTickerProviderStateMixin {
  final DailyDropService _dropService = DailyDropService();

  UserModel? _userModel;
  int _streakDays = 0;
  int _limit = 1;
  bool _canRequest = true;
  bool _isLoading = true;
  DailyDropModel? _drop;
  bool _viewRecorded = false;
  Timer? _countdownTimer;
  Duration _countdown = Duration.zero;
  bool _countdownStarted = false;

  late AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    AnalyticsService.logDailyDropOpen();
    _loadInitial();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    VoiceService().stop();
    _revealController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    if (_countdownStarted) return;
    _countdownStarted = true;
    _countdownTimer?.cancel();
    void tick() {
      if (!mounted) return;
      setState(() => _countdown = DailyDropService.getTimeUntilMidnight());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tick();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    });
  }

  void _stopCountdown() {
    _countdownStarted = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  static String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _loadInitial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        _userModel = UserModel.fromFirestore(doc.data()!, user.uid);
      }
      _streakDays = await _dropService.getStreakDays(user.uid);
      final drop = await _dropService.getTodayDrop();
      if (mounted) {
        setState(() {
          _drop = drop;
          _isLoading = false;
        });
        if (drop != null) AnalyticsService.logDailyDropCached();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recordViewOnce(String userId) async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    await _dropService.recordDropView(userId, _userModel);
    if (!mounted) return;
    final streak = await _dropService.getStreakDays(userId);
    setState(() => _streakDays = streak);
  }

  Future<void> _retryLoadDrop() async {
    setState(() => _isLoading = true);
    await _loadInitial();
  }

  Future<void> _onClaimTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ok = await _dropService.claimDailyDrop();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already claimed today. Try again at midnight.')),
      );
      return;
    }
    if (_drop == null) {
      await _loadInitial();
      if (!mounted) return;
    }
    _revealController.forward();
    await _recordViewOnce(user.uid);
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied!'),
        backgroundColor: Color(0xFF7B2CBF),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (_isLoading && user != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Today\'s Viral Drop'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
        ),
      );
    }
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Today\'s Viral Drop'),
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Sign in to claim')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Today\'s Viral Drop'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<bool>(
        stream: _dropService.hasClaimedTodayStream(user.uid),
        builder: (context, claimSnap) {
          final hasClaimedToday = claimSnap.data ?? false;
          _canRequest = !hasClaimedToday;
          _limit = 1;
          if (hasClaimedToday) _startCountdown(); else _stopCountdown();
          final hasDrop = _drop != null;
          if (hasClaimedToday && hasDrop && _revealController.value < 1.0) _revealController.forward();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasDrop) ...[
                  const SizedBox(height: 32),
                  Icon(Icons.schedule_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Generating today\'s drop…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Today\'s viral drop is created at midnight. Check back in a moment or pull to refresh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _retryLoadDrop,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B2CBF),
                      side: const BorderSide(color: Color(0xFF7B2CBF)),
                    ),
                  ),
                ],
                if (hasDrop && _drop != null) ...[
                  if (!hasClaimedToday) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _onClaimTap,
                      icon: const Icon(Icons.card_giftcard_rounded, size: 22),
                      label: const Text('Claim today\'s drop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2CBF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _RevealCard(index: 0, controller: _revealController, child: _Card1TrendScore(drop: _drop!)),
                  _RevealCard(index: 1, controller: _revealController, child: _Card2Concept(drop: _drop!, onCopy: _copy)),
                  _RevealCard(index: 2, controller: _revealController, child: _Card3Steps(drop: _drop!, onCopy: _copy)),
                  _RevealCard(index: 3, controller: _revealController, child: _Card4Hooks(drop: _drop!, onCopy: _copy)),
                  _RevealCard(index: 4, controller: _revealController, child: _Card5CaptionCta(drop: _drop!, onCopy: _copy)),
                  _RevealCard(index: 5, controller: _revealController, child: _Card6Hashtags(drop: _drop!, onCopy: _copy)),
                  _RevealCard(index: 6, controller: _revealController, child: _Card7BestTime(drop: _drop!, onCopy: _copy)),
                  _RevealCard(index: 7, controller: _revealController, child: _Card8CoachVoice(drop: _drop!)),
                  const SizedBox(height: 24),
                  _Footer(streakDays: _streakDays, nextDropAt: _dropService.nextDropAt),
                  if (hasClaimedToday) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Claimed for today. Next drop in ${_formatCountdown(_countdown.inSeconds > 0 ? _countdown : DailyDropService.getTimeUntilMidnight())}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule_rounded, size: 20),
                      label: Text('Next claim at midnight — ${_formatCountdown(_countdown.inSeconds > 0 ? _countdown : DailyDropService.getTimeUntilMidnight())}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const total = 8;
    final delay = (index / total) * 0.7;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        final t = v > delay ? ((v - delay) / (1 - delay)).clamp(0.0, 1.0) : 0.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class _Card1TrendScore extends StatelessWidget {
  const _Card1TrendScore({required this.drop});
  final DailyDropModel drop;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.trending_up_rounded,
      title: 'Trend theme',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              drop.trendTheme,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7B2CBF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${drop.viralityScore}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B2CBF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card2Concept extends StatelessWidget {
  const _Card2Concept({required this.drop, required this.onCopy});
  final DailyDropModel drop;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.movie_creation_outlined,
      title: 'Reel concept',
      content: drop.concept,
      onCopy: () => onCopy(drop.concept),
      trailing: VoicePlayButton(
        textToSpeak: drop.concept,
        iconSize: 22,
        iconColor: const Color(0xFF7B2CBF),
      ),
    );
  }
}

class _Card3Steps extends StatelessWidget {
  const _Card3Steps({required this.drop, required this.onCopy});
  final DailyDropModel drop;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final text = drop.steps
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return _SectionCard(
      icon: Icons.format_list_numbered_rounded,
      title: 'Step timeline (5 steps)',
      content: text.isEmpty ? '—' : text,
      onCopy: text.isEmpty ? null : () => onCopy(text),
    );
  }
}

class _Card4Hooks extends StatelessWidget {
  const _Card4Hooks({required this.drop, required this.onCopy});
  final DailyDropModel drop;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final text = drop.hooks
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return _SectionCard(
      icon: Icons.flash_on_rounded,
      title: 'Hooks',
      content: text.isEmpty ? '—' : text,
      onCopy: text.isEmpty ? null : () => onCopy(text),
      trailing: text.isEmpty
          ? null
          : VoicePlayButton(
              textToSpeak: text,
              iconSize: 22,
              iconColor: const Color(0xFF7B2CBF),
            ),
    );
  }
}

class _Card5CaptionCta extends StatelessWidget {
  const _Card5CaptionCta({required this.drop, required this.onCopy});
  final DailyDropModel drop;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Caption + CTA',
      content: drop.caption,
      onCopy: () => onCopy(drop.caption),
      trailing: VoicePlayButton(
        textToSpeak: drop.caption,
        iconSize: 22,
        iconColor: const Color(0xFF7B2CBF),
      ),
    );
  }
}

class _Card6Hashtags extends StatelessWidget {
  const _Card6Hashtags({required this.drop, required this.onCopy});
  final DailyDropModel drop;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final text = drop.hashtags.join(' ');
    return _SectionCard(
      icon: Icons.tag_rounded,
      title: 'Hashtag cluster',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...drop.hashtags.map(
            (h) => Chip(
              label: Text(h.startsWith('#') ? h : '#$h'),
              backgroundColor: const Color(0xFF7B2CBF).withOpacity(0.1),
            ),
          ),
        ],
      ),
      onCopy: text.isEmpty ? null : () => onCopy(text),
    );
  }
}

class _Card7BestTime extends StatelessWidget {
  const _Card7BestTime({required this.drop, required this.onCopy});
  final DailyDropModel drop;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.schedule_rounded,
      title: 'Best post time',
      content: drop.bestTime,
      onCopy: () => onCopy(drop.bestTime),
    );
  }
}

class _Card8CoachVoice extends StatelessWidget {
  const _Card8CoachVoice({required this.drop});
  final DailyDropModel drop;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.record_voice_over_rounded,
      title: 'Coach summary',
      content: drop.coachSummary,
      trailing: VoicePlayButton(
        textToSpeak: drop.coachSummary,
        iconSize: 24,
        iconColor: const Color(0xFF7B2CBF),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.streakDays,
    required this.nextDropAt,
  });
  final int streakDays;
  final DateTime nextDropAt;

  @override
  Widget build(BuildContext context) {
    final nextStr = DateFormat.jm().format(nextDropAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              Text(
                '$streakDays day streak',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          Text(
            'Next drop: $nextStr',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.content,
    this.child,
    this.onCopy,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? content;
  final Widget? child;
  final VoidCallback? onCopy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF7B2CBF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: onCopy,
                  color: const Color(0xFF7B2CBF),
                  tooltip: 'Copy',
                ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          if (child != null)
            child!
          else
            Text(
              content ?? '',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
        ],
      ),
    );
  }
}
