import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/whatsapp_bot_storage.dart';
import '../services/whatsapp_bot_firestore_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress.dart';

import 'success_screen.dart' show SuccessScreen;

/// Short name for [WhatsAppBotAiSetupScreen].
typedef AISetupScreen = WhatsAppBotAiSetupScreen;

const String _kAiPreviewDummy = '''
Sample reply (preview):

"Namaste! Hamare working hours 10:00 - 19:00 hain. Main aapki kaise madad kar sakta hoon?"

Yahan aapke greeting, languages aur price settings ke hisaab se AI jawab tayar hoga — yeh sirf demo text hai.
''';

class WhatsAppBotAiSetupScreen extends StatefulWidget {
  const WhatsAppBotAiSetupScreen({super.key});

  @override
  State<WhatsAppBotAiSetupScreen> createState() =>
      _WhatsAppBotAiSetupScreenState();
}

class _WhatsAppBotAiSetupScreenState extends State<WhatsAppBotAiSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _productsController = TextEditingController();
  final _greetingController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _languageOptions = const ['Hindi', 'English', 'Hinglish'];
  final Set<String> _selectedLanguages = <String>{'Hinglish'};

  bool _sharePrice = false;
  bool _saving = false;

  final _startTimeDisplayController = TextEditingController();
  final _endTimeDisplayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncTimeDisplay();
    _load();
  }

  Future<void> _load() async {
    final setup = await WhatsAppBotStorage.load();
    if (!mounted) return;
    // Prefill if we have existing values.
    final working = setup.aiWorkingHours.trim();
    TimeOfDay? start;
    TimeOfDay? end;
    if (working.contains('-')) {
      final parts = working.split('-').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        start = _parseTime(parts[0]);
        end = _parseTime(parts[1]);
      }
    }

    final langs = setup.languages;

    setState(() {
      _productsController.text = setup.productsOrServices;
      _greetingController.text = setup.greetingMessage;
      _startTime = start;
      _endTime = end;
      _selectedLanguages
        ..clear()
        ..addAll(langs.isNotEmpty ? langs : <String>['Hinglish']);
      _sharePrice = setup.sharePrice;
    });
    _syncTimeDisplay();
  }

  @override
  void dispose() {
    _productsController.dispose();
    _greetingController.dispose();
    _startTimeDisplayController.dispose();
    _endTimeDisplayController.dispose();
    super.dispose();
  }

  void _syncTimeDisplay() {
    _startTimeDisplayController.text =
        _startTime == null ? 'Select' : _formatTimeOfDay(_startTime!);
    _endTimeDisplayController.text =
        _endTime == null ? 'Select' : _formatTimeOfDay(_endTime!);
  }

  TimeOfDay? _parseTime(String hhmm) {
    final cleaned = hhmm.replaceAll(' ', '');
    final parts = cleaned.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]) ?? -1;
    final m = int.tryParse(parts[1]) ?? -1;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _workingHoursText() {
    if (_startTime == null || _endTime == null) return '';
    final s = _formatTimeOfDay(_startTime!);
    final e = _formatTimeOfDay(_endTime!);
    return '$s - $e';
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF0B0B10),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
    _syncTimeDisplay();
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF0B0B10),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() => _endTime = picked);
    _syncTimeDisplay();
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    const accent = Color(0xFF25D366);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
    );
  }

  Future<void> _activateBot() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() => _saving = true);
    try {
      final prev = await WhatsAppBotStorage.load();
      final hours = _workingHoursText();
      final next = prev.copyWith(
        productsOrServices: _productsController.text.trim(),
        aiWorkingHours: hours,
        languages: _selectedLanguages.toList(),
        sharePrice: _sharePrice,
        greetingMessage: _greetingController.text.trim(),
        // Backward-compatible fields used elsewhere:
        products: _productsController.text.trim(),
        workingHours: hours,
        aiEnabled: true,
        onboardingCompleted: true,
        connected: true,
      );
      await WhatsAppBotStorage.save(next);

      try {
        await WhatsAppBotFirestoreService.instance.saveAiSettings(next);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[AISetup] Firestore: $e');
          debugPrint('$st');
        }
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const SuccessScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B10);
    const card = Color(0xFF14141A);
    const accent = Color(0xFF25D366);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('AI Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(currentStep: 5, totalSteps: 6),
              const SizedBox(height: 18),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: card.withValues(alpha: 0.95),
                      elevation: 8,
                      shadowColor: accent.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: accent.withValues(alpha: 0.20), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Products/Services (multiline)
                            Text(
                              'Products/Services',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _productsController,
                              style: const TextStyle(color: Colors.white),
                              minLines: 4,
                              maxLines: 7,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return 'Products/Services required';
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                '',
                                hint: 'e.g., We sell skincare, we do waxing, and we offer home delivery...',
                              ).copyWith(
                                labelText: null,
                                hintText: 'e.g., We sell skincare, we do waxing, and we offer home delivery...',
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Working hours (time picker)
                            Text(
                              'Working hours',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _timeField(
                                    label: 'Start',
                                    controller: _startTimeDisplayController,
                                    onTap: _pickStartTime,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _timeField(
                                    label: 'End',
                                    controller: _endTimeDisplayController,
                                    onTap: _pickEndTime,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),
                            Text(
                              _workingHoursText().isEmpty
                                  ? 'Pick start + end time'
                                  : 'Selected: ${_workingHoursText()}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Language selection
                            Text(
                              'Language selection',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _languageOptions.map((lang) {
                                final selected = _selectedLanguages.contains(lang);
                                return FilterChip(
                                  selected: selected,
                                  label: Text(
                                    lang,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selectedColor: accent.withValues(alpha: 0.95),
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: accent.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _selectedLanguages.add(lang);
                                      } else {
                                        _selectedLanguages.remove(lang);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // Price share toggle
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14141A).withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.18),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Price share',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Bot will share pricing in replies',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: _sharePrice,
                                    onChanged: (v) =>
                                        setState(() => _sharePrice = v),
                                    activeColor: accent,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Greeting message
                            Text(
                              'Custom greeting message',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _greetingController,
                              style: const TextStyle(color: Colors.white),
                              minLines: 2,
                              maxLines: 4,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return 'Greeting required';
                                return null;
                              },
                              decoration: _inputDecoration(
                                '',
                                hint: 'e.g., Hello! Welcome to InstaFlow Support 👋 How can I help?',
                              ).copyWith(labelText: null),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // AI preview box
                    Card(
                      color: card.withValues(alpha: 0.95),
                      elevation: 6,
                      shadowColor: accent.withValues(alpha: 0.14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: accent.withValues(alpha: 0.18), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'AI Preview',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14141A).withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _kAiPreviewDummy,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.86),
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    PrimaryButton(
                      label: _saving ? 'Saving...' : 'Bot Activate Karo',
                      isLoading: _saving,
                      onPressed: _handleActivateTap,
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Settings stored locally for now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    const accent = Color(0xFF25D366);
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: accent, width: 2),
            ),
          ),
          validator: (_) => null,
        ),
      ),
    );
  }

  void _handleActivateTap() {
    // Validate language and times too
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_workingHoursText().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select working hours'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Fire and forget: _activateBot updates UI + navigation.
    _activateBot();
  }
}

