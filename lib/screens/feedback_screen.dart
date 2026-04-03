import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/feedback_service.dart';
import '../services/analytics_service.dart';
import '../utils/global_error_handler.dart';

const int _maxMessageLength = 2000;
const List<Map<String, String>> _feedbackTypes = [
  {'value': 'bug', 'label': 'Bug Report'},
  {'value': 'feature', 'label': 'Feature Request'},
  {'value': 'suggestion', 'label': 'Suggestion'},
];

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _screenController = TextEditingController();
  final FeedbackService _feedbackService = FeedbackService();

  String _selectedType = 'suggestion';
  bool _submitting = false;
  bool _showSuccess = false;

  @override
  void dispose() {
    _messageController.dispose();
    _screenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send feedback')),
      );
      return;
    }
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    setState(() => _submitting = true);
    try {
      await _feedbackService.submitFeedback(
        type: _selectedType,
        message: _messageController.text.trim(),
        screen: _screenController.text.trim().isEmpty ? null : _screenController.text.trim(),
      );
      if (!mounted) return;
      AnalyticsService.logFeedbackSent(type: _selectedType);
      setState(() {
        _submitting = false;
        _showSuccess = true;
        _messageController.clear();
        _screenController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Thanks! We read every feedback.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _showSuccess = false);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        GlobalErrorHandler.log('FeedbackSubmit', e);
        GlobalErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Send Feedback'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/my-feedback'),
            child: const Text('My feedback', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _showSuccess
              ? _buildSuccessAnimation()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildTypeDropdown(),
                    const SizedBox(height: 20),
                    _buildMessageField(),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (_, value, __) => Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${value.text.length}/$_maxMessageLength',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildScreenField(),
                    const SizedBox(height: 28),
                    _buildSubmitButton(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Feedback sent!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We read every message.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      decoration: InputDecoration(
        labelText: 'Feedback Type',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _feedbackTypes
          .map((e) => DropdownMenuItem(value: e['value'], child: Text(e['label'] ?? '')))
          .toList(),
      onChanged: (v) => setState(() => _selectedType = v ?? 'suggestion'),
    );
  }

  Widget _buildMessageField() {
    return TextFormField(
      controller: _messageController,
      maxLines: 6,
      maxLength: _maxMessageLength,
      decoration: InputDecoration(
        labelText: 'Your message',
        hintText: 'Describe your feedback in detail...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return 'Please enter your message';
        if (t.length > _maxMessageLength) return 'Message too long';
        return null;
      },
    );
  }

  Widget _buildScreenField() {
    return TextFormField(
      controller: _screenController,
      decoration: InputDecoration(
        labelText: 'Screen (optional)',
        hintText: 'e.g. Hashtag Generator',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _submitting ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF7B2CBF),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _submitting
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Submit Feedback'),
    );
  }
}
