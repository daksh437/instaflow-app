/// Admin access: Firestore users/{uid}.isAdmin must be true.
/// If adminEmails is non-empty, user email must also be in this list.
/// If adminEmails is empty, only Firestore isAdmin is checked (set isAdmin: true in Firestore for your uid).
class AdminConfig {
  AdminConfig._();

  /// Optional whitelist. If empty, any user with isAdmin: true in Firestore can access admin panel.
  /// Add emails here (lowercase) to restrict admin to only these emails.
  static const List<String> adminEmails = [
    // 'your-admin@example.com',
  ];

  /// Check if email is allowed admin access.
  static bool isAdminEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final lower = email.trim().toLowerCase();
    return adminEmails.contains(lower);
  }
}
