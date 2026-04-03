import 'package:flutter/material.dart';

import '../models/whatsapp_bot_setup.dart';
import '../models/whatsapp_bot_storage.dart';

/// Short name for [WhatsAppBotDashboardScreen].
typedef DashboardScreen = WhatsAppBotDashboardScreen;

class WhatsAppBotDashboardScreen extends StatefulWidget {
  const WhatsAppBotDashboardScreen({super.key});

  @override
  State<WhatsAppBotDashboardScreen> createState() =>
      _WhatsAppBotDashboardScreenState();
}

class _WhatsAppBotDashboardScreenState
    extends State<WhatsAppBotDashboardScreen> {
  static const Color _whatsappGreen = Color(0xFF075E54);
  static const Color _accentGreen = Color(0xFF25D366);

  int _tabIndex = 0;
  bool _loading = true;
  bool _aiOn = true;

  String? _activeChatId;

  final _manualController = TextEditingController();
  final _editController = TextEditingController();

  bool _editing = false;
  bool _suggestionRejected = false;

  final List<_ChatItem> _chats = [
    _ChatItem(
      id: 'c1',
      name: 'Alex Johnson',
      lastMessage: 'Can you share pricing for the starter package?',
      time: DateTime.now().subtract(const Duration(minutes: 22)),
      unread: 3,
      aiEnabled: true,
      messages: [
        _ChatMessage(
          text: 'Hi! I saw your ad.',
          isMine: false,
          time: DateTime.now().subtract(const Duration(minutes: 28)),
        ),
        _ChatMessage(
          text: 'Can you share pricing for the starter package?',
          isMine: false,
          time: DateTime.now().subtract(const Duration(minutes: 22)),
        ),
      ],
    ),
    _ChatItem(
      id: 'c2',
      name: 'Maria Garcia',
      lastMessage: 'What are your working hours on Saturdays?',
      time: DateTime.now().subtract(const Duration(hours: 1)),
      unread: 1,
      aiEnabled: true,
      messages: [
        _ChatMessage(
          text: 'Hello 👋',
          isMine: false,
          time: DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
        ),
        _ChatMessage(
          text: 'What are your working hours on Saturdays?',
          isMine: false,
          time: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
    _ChatItem(
      id: 'c3',
      name: 'Priya Shah',
      lastMessage: 'I want to book an onboarding call tomorrow.',
      time: DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
      unread: 0,
      aiEnabled: true,
      messages: [
        _ChatMessage(
          text: 'I want to book an onboarding call tomorrow.',
          isMine: false,
          time: DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
        ),
      ],
    ),
  ];

  String _aiSuggestion = 'Hi! Thanks for reaching out. How can I help you?';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final WhatsAppBotSetup setup = await WhatsAppBotStorage.load();
    if (!mounted) return;
    setState(() {
      _aiOn = setup.aiEnabled;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _setAiOn(bool v) async {
    setState(() => _aiOn = v);
    final prev = await WhatsAppBotStorage.load();
    if (!mounted) return;
    await WhatsAppBotStorage.save(prev.copyWith(aiEnabled: v));
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  _ChatItem? _activeChat() {
    if (_activeChatId == null) return null;
    try {
      return _chats.firstWhere((c) => c.id == _activeChatId);
    } catch (_) {
      return null;
    }
  }

  void _openChat(String id) {
    setState(() {
      _activeChatId = id;
      _suggestionRejected = false;
      _editing = false;
      _manualController.clear();
      _editController.text = '';

      // Mark unread as read
      for (final c in _chats) {
        if (c.id == id) c.unread = 0;
      }

      _aiSuggestion = _generateSuggestion(_chats.firstWhere((c) => c.id == id).lastMessage);
    });
  }

  void _backToChats() {
    setState(() {
      _activeChatId = null;
      _editing = false;
      _suggestionRejected = false;
      _manualController.clear();
      _editController.text = '';
    });
  }

  String _generateSuggestion(String lastMessage) {
    final lower = lastMessage.toLowerCase();
    if (lower.contains('pricing') || lower.contains('price') || lower.contains('cost')) {
      return 'Sure! For pricing, which plan are you interested in (Free / Pro)?';
    }
    if (lower.contains('hours') || lower.contains('saturday') || lower.contains('working')) {
      return 'Yes! We’re open during working hours. What time would you prefer?';
    }
    if (lower.contains('book') || lower.contains('onboarding') || lower.contains('call')) {
      return 'Great! What time works best for your onboarding call?';
    }
    return 'Hi! Thanks for reaching out. How can I help you today?';
  }

  void _sendAiSuggestion() {
    final chat = _activeChat();
    if (chat == null || _activeChatId == null) return;
    final text = (_editing ? _editController.text : _aiSuggestion).trim();
    if (text.isEmpty) return;

    setState(() {
      chat.messages.add(
        _ChatMessage(text: text, isMine: true, time: DateTime.now()),
      );
      chat.lastMessage = text;
      chat.time = DateTime.now();
      _editing = false;
      _suggestionRejected = false;
      _manualController.clear();
      _editController.text = '';
      _aiSuggestion = _generateSuggestion(text);
    });
  }

  void _rejectAiSuggestion() {
    setState(() {
      _suggestionRejected = true;
      _editing = false;
    });
  }

  void _sendManual() {
    final chat = _activeChat();
    if (chat == null || _activeChatId == null) return;
    final text = _manualController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      chat.messages.add(
        _ChatMessage(text: text, isMine: true, time: DateTime.now()),
      );
      chat.lastMessage = text;
      chat.time = DateTime.now();
      _manualController.clear();
      _suggestionRejected = false;
      _editing = false;
      _aiSuggestion = _aiOn ? _generateSuggestion(text) : _aiSuggestion;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeChat();
    final title = switch (_tabIndex) {
      0 => 'Chats',
      1 => 'Bot Settings',
      2 => 'Analytics',
      3 => 'Profile',
      _ => 'WhatsApp Bot',
    };

    final inChat = _tabIndex == 0 && active != null;

    return Scaffold(
      backgroundColor:
          _tabIndex == 0 && _activeChatId == null ? const Color(0xFFF0F2F5) : Colors.white,
      appBar: AppBar(
        backgroundColor: _whatsappGreen,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: inChat
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _backToChats,
              )
            : null,
        automaticallyImplyLeading: false,
        title: inChat
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    active.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'WhatsApp Business',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tabIndex == 0
              ? _buildChatsTab()
              : _buildOtherTabs(),
      bottomNavigationBar: _activeChatId != null
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _tabIndex,
              onTap: (i) {
                setState(() {
                  _tabIndex = i;
                  if (i != 0) _activeChatId = null;
                });
              },
              selectedItemColor: _whatsappGreen,
              unselectedItemColor: Colors.grey[600],
              backgroundColor: Colors.white,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_rounded),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Bot Settings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'Analytics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  Widget _buildOtherTabs() {
    if (_tabIndex == 1) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              title: 'AI ON/OFF',
              subtitle: 'Enable AI suggested replies',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _aiOn ? 'AI ON' : 'AI OFF',
                    style: TextStyle(
                      color: _whatsappGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Switch(
                    value: _aiOn,
                    onChanged: _setAiOn,
                    activeTrackColor: _accentGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_tabIndex == 2) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              title: 'Analytics',
              subtitle: 'Dummy stats for now',
              child: const Text(
                'Messages: 0\nCustomers: 0',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            title: 'Profile',
            subtitle: 'Placeholder tab',
            child: const Text('Coming soon'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_activeChatId != null) {
      return _buildChatDetail();
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _chats.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey[300],
      ),
      itemBuilder: (context, i) {
        final chat = _chats[i];
        return _ChatTile(
          name: chat.name,
          lastMessage: chat.lastMessage,
          time: _formatTime(chat.time),
          unread: chat.unread,
          showAiBadge: chat.aiEnabled,
          onTap: () => _openChat(chat.id),
        );
      },
    );
  }

  Widget _buildChatDetail() {
    final chat = _activeChat();
    if (chat == null || _activeChatId == null) return const SizedBox.shrink();

    final showSuggestion = _aiOn && !_suggestionRejected;
    final suggestionText = _aiSuggestion;

    const wallpaper = Color(0xFFECE5DD);
    const aiBarBg = Color(0xFFE8F5E9);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _backToChats();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top: AI ON/OFF (WhatsApp-style strip)
          Material(
            color: aiBarBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_rounded,
                      color: _whatsappGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI replies ${_aiOn ? 'ON' : 'OFF'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111B21),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: _aiOn,
                    onChanged: _setAiOn,
                    activeTrackColor: _accentGreen,
                  ),
                ],
              ),
            ),
          ),

          // AI suggestion card
          if (showSuggestion)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Color(0xFF075E54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Suggested reply',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF111B21),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_editing)
                        TextField(
                          controller: _editController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF0F2F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _whatsappGreen.withValues(alpha: 0.22),
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          suggestionText,
                          style: const TextStyle(
                            color: Color(0xFF111B21),
                            fontWeight: FontWeight.w900,
                            height: 1.45,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                if (_editing) {
                                  _aiSuggestion = _editController.text.trim();
                                  _editing = false;
                                }
                                _sendAiSuggestion();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: _whatsappGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Send'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _editing = !_editing;
                                if (_editing) {
                                  _editController.text = _aiSuggestion;
                                }
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _whatsappGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: _whatsappGreen.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _rejectAiSuggestion,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: Colors.red[300]!),
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _aiOn
                        ? 'AI suggestion rejected. Manual reply below.'
                        : 'AI OFF. Manual reply below.',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),

          // Conversation (WhatsApp wallpaper + bubbles)
          Expanded(
            child: Container(
              color: wallpaper,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                itemCount: chat.messages.length,
                itemBuilder: (context, i) {
                  final m = chat.messages[i];
                  return _WaBubble(
                    text: m.text,
                    isMine: m.isMine,
                    timeLabel: _formatTime(m.time),
                  );
                },
              ),
            ),
          ),

          // Composer
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _manualController,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(
                          color: Color(0xFF111B21),
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _accentGreen,
                    radius: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendManual,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _whatsappGreen.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isMine,
    required this.time,
  });

  final String text;
  final bool isMine;
  final DateTime time;
}

class _ChatItem {
  final String id;
  final String name;
  String lastMessage;
  DateTime time;
  int unread;
  final bool aiEnabled;
  final List<_ChatMessage> messages;

  _ChatItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.aiEnabled,
    required List<_ChatMessage> messages,
  }) : messages = List<_ChatMessage>.from(messages);
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.showAiBadge,
    required this.onTap,
  });

  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final bool showAiBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const whatsappGreen = Color(0xFF075E54);
    const accent = Color(0xFF25D366);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_rounded, color: whatsappGreen),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111B21),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (showAiBadge)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: Color(0xFF1E8E3E),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF667781),
                              fontWeight:
                                  unread > 0 ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
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

/// WhatsApp-style bubbles: incoming white, outgoing #DCF8C6.
class _WaBubble extends StatelessWidget {
  const _WaBubble({
    required this.text,
    required this.isMine,
    required this.timeLabel,
  });

  final String text;
  final bool isMine;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    const incoming = Color(0xFFFFFFFF);
    const outgoing = Color(0xFFDCF8C6);
    const textIncoming = Color(0xFF111B21);
    const textOutgoing = Color(0xFF111B21);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isMine ? outgoing : incoming,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(8),
                topRight: const Radius.circular(8),
                bottomLeft: Radius.circular(isMine ? 8 : 0),
                bottomRight: Radius.circular(isMine ? 0 : 8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isMine ? textOutgoing : textIncoming,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: const Color(0xFF667781).withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

