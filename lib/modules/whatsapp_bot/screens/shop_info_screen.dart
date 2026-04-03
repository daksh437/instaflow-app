import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/whatsapp_bot_storage.dart';
import '../services/whatsapp_bot_firestore_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/rounded_input_field.dart';
import '../widgets/step_progress.dart';

import 'ai_setup_screen.dart' show AISetupScreen;

/// Short name for [WhatsAppBotShopInfoScreen] (shop details → AI setup).
typedef ShopInfoScreen = WhatsAppBotShopInfoScreen;

class WhatsAppBotShopInfoScreen extends StatefulWidget {
  const WhatsAppBotShopInfoScreen({super.key});

  @override
  State<WhatsAppBotShopInfoScreen> createState() =>
      _WhatsAppBotShopInfoScreenState();
}

class _WhatsAppBotShopInfoScreenState
    extends State<WhatsAppBotShopInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _whatsappDisplayNameController = TextEditingController();

  static const List<String> _categories = <String>[
    'Restaurant',
    'Online Store',
    'Services',
    'Retail',
    'Other',
  ];

  String _selectedCategory = _categories.first;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final setup = await WhatsAppBotStorage.load();
    if (!mounted) return;

    _shopNameController.text =
        (setup.shopName.isNotEmpty ? setup.shopName : setup.businessName);

    final categoryFallback =
        setup.products.isNotEmpty ? setup.products : _categories.first;
    _selectedCategory = setup.category.isNotEmpty ? setup.category : categoryFallback;

    _cityController.text =
        (setup.city.isNotEmpty ? setup.city : setup.workingHours);

    _whatsappDisplayNameController.text = setup.whatsappDisplayName;
    setState(() {});
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _cityController.dispose();
    _whatsappDisplayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    setState(() => _saving = true);
    try {
      final prev = await WhatsAppBotStorage.load();
      final next = prev.copyWith(
        shopName: _shopNameController.text.trim(),
        category: _selectedCategory,
        city: _cityController.text.trim(),
        whatsappDisplayName:
            _whatsappDisplayNameController.text.trim(),
        // Backward-compatible mappings
        businessName: _shopNameController.text.trim(),
        products: _selectedCategory,
        workingHours: _cityController.text.trim(),
        connected: true,
      );

      await WhatsAppBotStorage.save(next);

      try {
        await WhatsAppBotFirestoreService.instance.saveShopInfo(next);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[ShopInfo] Firestore: $e');
          debugPrint('$st');
        }
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const AISetupScreen(),
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
        title: const Text('Shop Info'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(currentStep: 4, totalSteps: 6),
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
                        side: BorderSide(
                          color: accent.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Add your shop details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            RoundedInputField(
                              label: 'Shop Name',
                              hint: 'e.g., InstaFlow Studio',
                              controller: _shopNameController,
                              minLines: 1,
                              maxLines: 1,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return 'Shop Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              items: _categories
                                  .map((c) => DropdownMenuItem<String>(
                                        value: c,
                                        child: Text(
                                          c,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedCategory = v);
                              },
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Category is required';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Category',
                                hintText: 'Select category',
                                hintStyle: const TextStyle(color: Colors.white54),
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: accent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              dropdownColor: card,
                              style: const TextStyle(color: Colors.white),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: accent,
                              ),
                              isExpanded: true,
                            ),
                            const SizedBox(height: 14),
                            RoundedInputField(
                              label: 'City',
                              hint: 'e.g., Mumbai',
                              controller: _cityController,
                              minLines: 1,
                              maxLines: 1,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return 'City is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            RoundedInputField(
                              label: 'WhatsApp display name',
                              hint: 'e.g., InstaFlow Support',
                              controller: _whatsappDisplayNameController,
                              minLines: 1,
                              maxLines: 1,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return 'WhatsApp display name is required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: _saving ? 'Saving...' : 'Aage Badho',
                      isLoading: _saving,
                      onPressed: _saveAndContinue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Saved locally on this device.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
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
}

