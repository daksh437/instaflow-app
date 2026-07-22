import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../utils/share_helper.dart';

/// Refer & Earn: share your code — you and your friend each get free Premium
/// days. Product-led viral growth on top of the share loop.
class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  static const _primary = Color(0xFF7B2CBF);
  final _api = ApiService();
  final _codeController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _myCode = '';
  int _count = 0;
  int _rewardDays = 5;
  bool _alreadyRedeemed = false;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getReferralCode();
      if (!mounted) return;
      setState(() {
        _myCode = data['code']?.toString() ?? '';
        _count = (data['referralCount'] as num?)?.toInt() ?? 0;
        _rewardDays = (data['rewardDays'] as num?)?.toInt() ?? 5;
        _alreadyRedeemed = data['alreadyRedeemed'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your referral code. Check your connection.';
      });
    }
  }

  Future<void> _shareCode() async {
    await Share.share(
      'Get InstaFlow — AI captions, hashtags & reels for Instagram 🔥\n\n'
      'Use my code *$_myCode* and we BOTH get $_rewardDays days of Premium free!\n\n'
      '👉 ${ShareHelper.playUrl}',
      subject: 'Join me on InstaFlow ✨',
    );
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || _redeeming) return;
    setState(() => _redeeming = true);
    try {
      final res = await _api.redeemReferral(code);
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? (ok ? 'Reward applied!' : 'Could not redeem'))),
      );
      if (ok) {
        _codeController.clear();
        setState(() => _alreadyRedeemed = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not redeem this code. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Card(color: Colors.red[50], child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: TextStyle(color: Colors.red[800])))),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text('Invite a friend, you BOTH get\n$_rewardDays days of Premium free',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE3FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SelectableText(
                                _myCode,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4, color: _primary),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: _primary),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _myCode));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _shareCode,
                            icon: const Icon(Icons.ios_share_rounded),
                            label: const Text('Share your code'),
                            style: FilledButton.styleFrom(backgroundColor: _primary, minimumSize: const Size.fromHeight(50)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('$_count friend${_count == 1 ? '' : 's'} joined', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_alreadyRedeemed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Have a friend\'s code?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Enter code',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _redeeming ? null : _redeem,
                                style: FilledButton.styleFrom(backgroundColor: _primary),
                                child: _redeeming
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Redeem'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
