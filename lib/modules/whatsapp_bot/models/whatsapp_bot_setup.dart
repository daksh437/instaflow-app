class WhatsAppBotSetup {
  final String businessName;
  final String products;
  final String workingHours;

  // Shop Info (current onboarding step)
  final String shopName;
  final String category;
  final String city;
  final String whatsappDisplayName;

  // AI Setup (current onboarding step)
  final String productsOrServices;
  final String aiWorkingHours;
  final List<String> languages;
  final bool sharePrice;
  final String greetingMessage;

  final bool aiEnabled;
  final bool connected;
  final bool onboardingCompleted;

  const WhatsAppBotSetup({
    required this.businessName,
    required this.products,
    required this.workingHours,
    required this.shopName,
    required this.category,
    required this.city,
    required this.whatsappDisplayName,
    required this.productsOrServices,
    required this.aiWorkingHours,
    required this.languages,
    required this.sharePrice,
    required this.greetingMessage,
    required this.aiEnabled,
    required this.connected,
    required this.onboardingCompleted,
  });

  factory WhatsAppBotSetup.empty() => const WhatsAppBotSetup(
        businessName: '',
        products: '',
        workingHours: '',
        shopName: '',
        category: '',
        city: '',
        whatsappDisplayName: '',
        productsOrServices: '',
        aiWorkingHours: '',
        languages: <String>[],
        sharePrice: false,
        greetingMessage: '',
        aiEnabled: true,
        connected: false,
        onboardingCompleted: false,
      );

  factory WhatsAppBotSetup.fromJson(Map<String, dynamic> json) {
    final businessName =
        (json['businessName'] ?? json['business_name'] ?? '').toString();
    final products = (json['products'] ?? json['product'] ?? json['productsOrServices'] ?? '')
        .toString();
    final workingHours =
        (json['workingHours'] ?? json['working_hours'] ?? '').toString();

    final shopName =
        (json['shopName'] ?? json['shop_name'] ?? businessName).toString();
    final category =
        (json['category'] ?? json['shopCategory'] ?? products).toString();
    final city = (json['city'] ?? json['shopCity'] ?? workingHours).toString();
    final whatsappDisplayName =
        (json['whatsappDisplayName'] ?? json['whatsapp_display_name'] ?? '').toString();

    final productsOrServices =
        (json['productsOrServices'] ??
                json['products_or_services'] ??
                json['products'] ??
                '').toString();
    final aiWorkingHours =
        (json['aiWorkingHours'] ??
                json['ai_working_hours'] ??
                json['workingHours'] ??
                '').toString();

    final languagesRaw = json['languages'] ?? json['language'];
    final languages = <String>[];
    if (languagesRaw is List) {
      for (final v in languagesRaw) {
        if (v == null) continue;
        languages.add(v.toString());
      }
    } else if (languagesRaw is String) {
      languages.addAll(
        languagesRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final sharePrice =
        json['sharePrice'] == true || json['share_price'] == true;
    final greetingMessage =
        (json['greetingMessage'] ??
                json['greeting_message'] ??
                '').toString();

    return WhatsAppBotSetup(
      businessName: businessName,
      products: products,
      workingHours: workingHours,
      shopName: shopName,
      category: category,
      city: city,
      whatsappDisplayName: whatsappDisplayName,
      productsOrServices: productsOrServices,
      aiWorkingHours: aiWorkingHours,
      languages: languages,
      sharePrice: sharePrice,
      greetingMessage: greetingMessage,
      aiEnabled: json['aiEnabled'] == true || json['ai_enabled'] == true,
      connected: json['connected'] == true,
      onboardingCompleted: json['onboardingCompleted'] == true || json['onboarding_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'products': products,
        'workingHours': workingHours,
        'shopName': shopName,
        'category': category,
        'city': city,
        'whatsappDisplayName': whatsappDisplayName,
        'productsOrServices': productsOrServices,
        'aiWorkingHours': aiWorkingHours,
        'languages': languages,
        'sharePrice': sharePrice,
        'greetingMessage': greetingMessage,
        'aiEnabled': aiEnabled,
        'connected': connected,
        'onboardingCompleted': onboardingCompleted,
      };

  WhatsAppBotSetup copyWith({
    String? businessName,
    String? products,
    String? workingHours,
    String? shopName,
    String? category,
    String? city,
    String? whatsappDisplayName,
    String? productsOrServices,
    String? aiWorkingHours,
    List<String>? languages,
    bool? sharePrice,
    String? greetingMessage,
    bool? aiEnabled,
    bool? connected,
    bool? onboardingCompleted,
  }) {
    return WhatsAppBotSetup(
      businessName: businessName ?? this.businessName,
      products: products ?? this.products,
      workingHours: workingHours ?? this.workingHours,
      shopName: shopName ?? this.shopName,
      category: category ?? this.category,
      city: city ?? this.city,
      whatsappDisplayName: whatsappDisplayName ?? this.whatsappDisplayName,
      productsOrServices: productsOrServices ?? this.productsOrServices,
      aiWorkingHours: aiWorkingHours ?? this.aiWorkingHours,
      languages: languages ?? this.languages,
      sharePrice: sharePrice ?? this.sharePrice,
      greetingMessage: greetingMessage ?? this.greetingMessage,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      connected: connected ?? this.connected,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

