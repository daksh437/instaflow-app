import 'dart:async';

import 'package:flutter/material.dart';

import '../models/whatsapp_bot_storage.dart';
import 'connect_screen.dart' show WhatsAppBotConnectScreen;
import 'dashboard_screen.dart' show DashboardScreen;

class WhatsAppBotIntroScreen extends StatefulWidget {
  const WhatsAppBotIntroScreen({super.key});

  @override
  State<WhatsAppBotIntroScreen> createState() => _WhatsAppBotIntroScreenState();
}

class _WhatsAppBotIntroScreenState extends State<WhatsAppBotIntroScreen>
    with TickerProviderStateMixin {
  static const Color _bgTint = Color(0xFFF0FDF4);
  static const Color _accent = Color(0xFF25D366);
  static const Color _accentDark = Color(0xFF075E54);

  bool _connected = false;
  bool _initializing = true;

  // Typing / cursor
  late final AnimationController _cursorBlinkController;
  Timer? _typingTimer;
  int _typedCount = 0;

  // General section animations
  late final AnimationController _introAnimController;
  late final Animation<double> _subtitleAnim;
  late final Animation<Offset> _subtitleSlideAnim;
  late final Animation<double> _iconScaleAnim;

  // Chat preview sequence
  bool _showUserBubble = false;
  bool _showTypingDots = false;
  bool _showAiBubble = false;
  bool _showCTA = false;

  // Typing dots bounce
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);

    _introAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _subtitleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _introAnimController,
        curve: const Interval(0.22, 0.55, curve: Curves.easeOut),
      ),
    );

    _subtitleSlideAnim = Tween<Offset>(begin: const Offset(0, 12), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _introAnimController,
        curve: const Interval(0.22, 0.55, curve: Curves.easeOut),
      ),
    );

    _iconScaleAnim = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _introAnimController,
        curve: const Interval(0.06, 0.22, curve: Curves.elasticOut),
      ),
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _checkConnectedAndInit();
  }

  Future<void> _checkConnectedAndInit() async {
    final setup = await WhatsAppBotStorage.load();
    if (!mounted) return;

    if (setup.onboardingCompleted) {
      setState(() => _connected = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const DashboardScreen(),
          ),
          (route) => route.isFirst,
        );
      });
      return;
    }

    setState(() => _initializing = false);
    _introAnimController.forward();
    _runPremiumOnboardingSequence();
  }

  void _runPremiumOnboardingSequence() {
    const typingStartDelay = Duration(milliseconds: 420);
    Future.delayed(typingStartDelay, () {
      if (!mounted) return;
      _startTypewriter();
    });
  }

  void _startChatSequence(
    Duration userDelay,
    Duration aiDelay,
    Duration ctaDelay,
  ) {
    Future.delayed(userDelay, () {
      if (!mounted) return;
      setState(() => _showUserBubble = true);
    });

    Future.delayed(userDelay + const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() => _showTypingDots = true);
    });

    Future.delayed(userDelay + aiDelay, () {
      if (!mounted) return;
      setState(() {
        _showTypingDots = false;
        _showAiBubble = true;
      });
    });

    Future.delayed(userDelay + aiDelay + ctaDelay, () {
      if (!mounted) return;
      setState(() => _showCTA = true);
    });
  }

  static const String _preText = 'Soye bhi, ';
  static const String _businessText = 'business';
  static const String _postText = ' chale bhi';
  static const String _fullText = 'Soye bhi, business chale bhi';

  void _startTypewriter() {
    _typingTimer?.cancel();
    _typedCount = 0;
    setState(() {});

    // Ensure chat sequence will be triggered after typing ends.
    final fullLen = _fullText.length;
    const step = Duration(milliseconds: 38);

    _typingTimer = Timer.periodic(step, (timer) {
      if (!mounted) return;

      final next = _typedCount + 1;
      if (next >= fullLen) {
        timer.cancel();
        _typedCount = fullLen;
        setState(() {});

        // Drive chat/CTA sequence from real typing completion.
        _startChatSequence(
          const Duration(milliseconds: 520),
          const Duration(milliseconds: 1000),
          const Duration(milliseconds: 380),
        );
        return;
      }

      _typedCount = next;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorBlinkController.dispose();
    _introAnimController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  void _goConnect() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const WhatsAppBotConnectScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: _bgTint,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_connected) {
      // Navigation will happen immediately; keep UI minimal.
      return const Scaffold(
        backgroundColor: _bgTint,
        body: SafeArea(child: SizedBox.shrink()),
      );
    }

    return Scaffold(
      backgroundColor: _bgTint,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 16, 0),
              child: _TopBar(
                leftBrand: 'InstaFlow',
                onSkip: _goConnect,
                accent: _accent,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _WhatsAppIconBounce(
                      iconScaleAnim: _iconScaleAnim,
                      accent: _accentDark,
                      bg: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    _TypewriterBlock(
                      typedCount: _typedCount,
                      cursorBlink: _cursorBlinkController,
                      accent: _accent,
                    ),
                    const SizedBox(height: 14),
                    _SubtitleBlock(
                      subtitle: 'WhatsApp pe customer aata hai — AI reply karta hai...',
                      subtitleAnim: _subtitleAnim,
                      slideAnim: _subtitleSlideAnim,
                    ),
                    const SizedBox(height: 18),
                    _FeaturePillsList(
                      accent: _accent,
                      introAnimController: _introAnimController,
                    ),
                    const SizedBox(height: 18),
                    _ChatPreviewCard(
                      showUserBubble: _showUserBubble,
                      showTypingDots: _showTypingDots,
                      showAiBubble: _showAiBubble,
                      dotsController: _dotsController,
                      accent: _accent,
                    ),
                    const SizedBox(height: 20),
                    _TrustStrip(),
                    const SizedBox(height: 80), // spacing so CTA never overlaps content
                  ],
                ),
              ),
            ),
            _CTASection(
              show: _showCTA,
              accent: _accent,
              onPressed: _goConnect,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.leftBrand,
    required this.onSkip,
    required this.accent,
  });

  final String leftBrand;
  final VoidCallback onSkip;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              leftBrand,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0F766E),
          ),
          child: const Text(
            'Skip',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _WhatsAppIconBounce extends StatelessWidget {
  const _WhatsAppIconBounce({
    required this.iconScaleAnim,
    required this.accent,
    required this.bg,
  });

  final Animation<double> iconScaleAnim;
  final Color accent;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    // Flutter does not always include a WhatsApp-specific Material icon across
    // versions. This is a WhatsApp-style chat icon.
    return Center(
      child: ScaleTransition(
        scale: iconScaleAnim,
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.chat_rounded,
            size: 42,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _TypewriterBlock extends StatelessWidget {
  const _TypewriterBlock({
    required this.typedCount,
    required this.cursorBlink,
    required this.accent,
  });

  final int typedCount;
  final Animation<double> cursorBlink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Split the full text so we can highlight "business".
    const pre = _WhatsAppBotIntroScreenState._preText;
    const business = _WhatsAppBotIntroScreenState._businessText;
    const post = _WhatsAppBotIntroScreenState._postText;

    final preLen = pre.length;
    final bizLen = business.length;
    final afterLen = post.length;

    final count = typedCount.clamp(0, preLen + bizLen + afterLen);

    final preShown = count <= preLen ? count : preLen;
    final bizShown =
        count <= preLen ? 0 : (count <= preLen + bizLen ? count - preLen : bizLen);
    final afterShown = count <= preLen + bizLen ? 0 : count - (preLen + bizLen);

    final preText = pre.substring(0, preShown);
    final bizText = business.substring(0, bizShown);
    final afterText = post.substring(0, afterShown);

    final isTyping = count < (preLen + bizLen + afterLen);

    return Center(
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.25,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(text: preText),
                TextSpan(
                  text: bizText,
                  style: TextStyle(color: accent),
                ),
                TextSpan(text: afterText),
              ],
            ),
          ),
          // Blinking cursor
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: isTyping
                ? FadeTransition(
                    opacity: cursorBlink,
                    child: Container(
                      width: 10,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SubtitleBlock extends StatelessWidget {
  const _SubtitleBlock({
    required this.subtitle,
    required this.subtitleAnim,
    required this.slideAnim,
  });

  final String subtitle;
  final Animation<double> subtitleAnim;
  final Animation<Offset> slideAnim;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: subtitleAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _FeaturePillsList extends StatelessWidget {
  const _FeaturePillsList({
    required this.accent,
    required this.introAnimController,
  });

  final Color accent;
  final AnimationController introAnimController;

  @override
  Widget build(BuildContext context) {
    final pills = const <String>[
      '24/7',
      'Hindi',
      'Free Plan',
    ];

    return Column(
      children: [
        for (int i = 0; i < pills.length; i++)
          _FeaturePill(
            text: pills[i],
            accent: accent,
            animation: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: introAnimController,
                curve: Interval(0.38 + i * 0.06, 0.66 + i * 0.06, curve: Curves.easeOut),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.text,
    required this.accent,
    required this.animation,
  });

  final String text;
  final Color accent;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatPreviewCard extends StatelessWidget {
  const _ChatPreviewCard({
    required this.showUserBubble,
    required this.showTypingDots,
    required this.showAiBubble,
    required this.dotsController,
    required this.accent,
  });

  final bool showUserBubble;
  final bool showTypingDots;
  final bool showAiBubble;
  final AnimationController dotsController;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live preview',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            _FadeIn(
              show: showUserBubble,
              child: _Bubble(
                align: Alignment.centerRight,
                bg: accent.withValues(alpha: 0.10),
                fg: _WhatsAppBotIntroScreenState._accentDark,
                text: 'Hi! I need info about services.',
              ),
            ),
            const SizedBox(height: 10),
            if (showTypingDots)
              _TypingDots(
                dotsController: dotsController,
                accent: accent,
              ),
            const SizedBox(height: 10),
            _FadeIn(
              show: showAiBubble,
              child: _Bubble(
                align: Alignment.centerLeft,
                bg: const Color(0xFFF3F4F6),
                fg: const Color(0xFF111827),
                text: 'Sure! We reply 24/7 with AI. Want pricing + working hours?',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.align,
    required this.bg,
    required this.fg,
    required this.text,
  });

  final Alignment align;
  final Color bg;
  final Color fg;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({
    required this.dotsController,
    required this.accent,
  });

  final AnimationController dotsController;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: dotsController,
            builder: (context, child) {
              final t = dotsController.value;
              final phase = (i * 0.25);
              final s = (t + phase) % 1.0;
              final y = (1 - s) * 10;
              final scale = 0.85 + (1 - (s - 0.5).abs() * 1.1).clamp(0, 1) * 0.35;
              return Transform.translate(
                offset: Offset(0, -y),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      opacity: show ? 1 : 0,
      child: show
          ? child
          : const SizedBox.shrink(),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: const [
              _TrustItem(title: 'Meta Verified', subtitle: 'Trusted platform'),
              SizedBox(height: 10),
              _TrustItem(title: 'Data Safe', subtitle: 'Secure storage'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.verified_rounded,
              size: 16,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CTASection extends StatelessWidget {
  const _CTASection({
    required this.show,
    required this.accent,
    required this.onPressed,
  });

  final bool show;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      offset: show ? const Offset(0, 0) : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: show ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: IgnorePointer(
            ignoring: !show,
            child: _PremiumCTAButton(
              accent: accent,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumCTAButton extends StatefulWidget {
  const _PremiumCTAButton({
    required this.accent,
    required this.onPressed,
  });

  final Color accent;
  final VoidCallback onPressed;

  @override
  State<_PremiumCTAButton> createState() => _PremiumCTAButtonState();
}

class _PremiumCTAButtonState extends State<_PremiumCTAButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.985 : 1.0;
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: scale,
      child: Material(
        color: widget.accent,
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Abhi Free Setup Karo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'No card • 2 min • 50 msg free/month',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

