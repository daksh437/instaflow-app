import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../config/app_secrets.dart';
import '../models/user_model.dart';
import '../services/google_cloud_tts_service.dart';
import '../services/premium_service.dart';
import '../utils/voice_text_prep.dart';

/// AI Voice play/pause using Google Cloud TTS via proxy. Premium users only. Loading + cache.
class AIVoicePlayButton extends StatefulWidget {
  const AIVoicePlayButton({
    super.key,
    required this.textToSpeak,
    this.cacheKey,
    this.languageCode = 'en-IN',
    this.iconSize = 22,
    this.iconColor,
  });

  final String textToSpeak;
  final String? cacheKey;
  final String languageCode;
  final double iconSize;
  final Color? iconColor;

  @override
  State<AIVoicePlayButton> createState() => _AIVoicePlayButtonState();
}

class _AIVoicePlayButtonState extends State<AIVoicePlayButton> {
  final GoogleCloudTtsService _service = GoogleCloudTtsService.instance;
  bool _isLoading = false;
  String? _sourceId;
  bool? _isPremium;

  @override
  void initState() {
    super.initState();
    _sourceId = widget.cacheKey ?? _cacheKeyFor(prepareTextForSpeech(widget.textToSpeak), widget.languageCode);
    _checkPremium();
  }

  @override
  void didUpdateWidget(AIVoicePlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sourceId = widget.cacheKey ?? _cacheKeyFor(prepareTextForSpeech(widget.textToSpeak), widget.languageCode);
  }

  Future<void> _checkPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isPremium = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        if (mounted) setState(() => _isPremium = false);
        return;
      }
      final model = UserModel.fromFirestore(doc.data()!, user.uid);
      if (mounted) setState(() => _isPremium = PremiumService.isPremium(model));
    } catch (_) {
      if (mounted) setState(() => _isPremium = false);
    }
  }

  static String _cacheKeyFor(String text, String lang) {
    if (text.isEmpty) return '';
    final hash = text.hashCode.abs().toRadixString(16);
    final len = text.length.clamp(0, 100);
    final l = lang.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_');
    return '${l}_${hash}_$len';
  }

  Future<void> _toggle() async {
    final prepared = prepareTextForSpeech(widget.textToSpeak);
    if (prepared.isEmpty) return;

    if (_isPremium == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Voice is a premium feature')),
        );
        Navigator.pushNamed(context, '/premium');
      }
      return;
    }
    if (!AppSecrets.isTtsProxyConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Voice not configured. Set TTS proxy.')),
        );
      }
      return;
    }

    final key = widget.cacheKey ?? _cacheKeyFor(prepared, widget.languageCode);
    if (_service.currentSourceId == key && !_isLoading) {
      await _service.playOrPause(key);
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.playText(
        text: widget.textToSpeak,
        languageCode: widget.languageCode,
        cacheKey: key,
        onLoadingChanged: (loading) {
          if (mounted) setState(() => _isLoading = loading);
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play AI voice')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepared = prepareTextForSpeech(widget.textToSpeak);
    final disabled = prepared.isEmpty ||
        !AppSecrets.isTtsProxyConfigured ||
        _isPremium == false;
    final color = widget.iconColor ?? const Color(0xFF7B2CBF);

    return StreamBuilder<PlayerState>(
      stream: _service.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isThisSource = _sourceId != null && _service.currentSourceId == _sourceId;
        final playing = isThisSource && (state?.playing ?? false);

        return IconButton(
          icon: _isLoading
              ? SizedBox(
                  width: widget.iconSize,
                  height: widget.iconSize,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.volume_up_rounded,
                  size: widget.iconSize,
                  color: disabled ? Colors.grey : color,
                ),
          onPressed: disabled ? null : _toggle,
          tooltip: _isPremium == false
              ? 'Premium feature'
              : (playing ? 'Pause' : 'Listen (AI Voice)'),
        );
      },
    );
  }
}
