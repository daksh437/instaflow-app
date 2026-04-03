import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../utils/voice_text_prep.dart';
import '../utils/voice_gating_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Small speaker button for AI result voice playback. Placed beside copy button.
class VoicePlayButton extends StatefulWidget {
  const VoicePlayButton({
    super.key,
    required this.textToSpeak,
    this.iconSize = 20,
    this.iconColor,
  });

  final String textToSpeak;
  final double iconSize;
  final Color? iconColor;

  @override
  State<VoicePlayButton> createState() => _VoicePlayButtonState();
}

class _VoicePlayButtonState extends State<VoicePlayButton> {
  final VoiceService _voiceService = VoiceService();

  @override
  void initState() {
    super.initState();
    _voiceService.onSpeakingChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _voiceService.onSpeakingChanged = null;
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _toggleSpeak() async {
    final prepared = prepareTextForSpeech(widget.textToSpeak);
    if (prepared.isEmpty) return;
    if (!mounted) return;
    final canSpeak = await VoiceGatingHelper.checkCanSpeak(context);
    if (!canSpeak || !mounted) return;
    if (_voiceService.isSpeaking) {
      await _voiceService.stop();
      setState(() {});
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _voiceService.speak(prepared);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await VoiceGatingHelper.recordVoiceUse(user.uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice unavailable')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepared = prepareTextForSpeech(widget.textToSpeak);
    final disabled = prepared.isEmpty;
    final color = widget.iconColor ?? const Color(0xFF7B2CBF);
    return IconButton(
      icon: _isLoading
          ? SizedBox(
              width: widget.iconSize,
              height: widget.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(
              _voiceService.isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: widget.iconSize,
              color: disabled ? Colors.grey : color,
            ),
      onPressed: disabled ? null : _toggleSpeak,
      tooltip: _voiceService.isSpeaking ? 'Stop' : 'Listen',
    );
  }
}
