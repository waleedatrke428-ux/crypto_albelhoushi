import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    final url = const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gdsnaivwmdbuqktzrbin.supabase.co');
    final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_VbgMS_Y_oNs8rbMhVs1Tpg_9GJbP-gl');
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Build with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      client.auth.signInWithPassword(email: email.trim(), password: password);

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) =>
      client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );

  static Future<void> sendPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email.trim());

  static Future<void> signOut() => client.auth.signOut();

  static Future<Map<String, dynamic>> fetchProfile(String userId) async {
    return await client.from('users').select().eq('id', userId).single();
  }

  static Future<Map<String, dynamic>?> fetchSubscription(String userId) async {
    return await client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  static Future<Map<String, dynamic>?> fetchTrial(String userId) async {
    return await client
        .from('trial_history')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .gt('end_date', DateTime.now().toUtc().toIso8601String())
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> fetchSignals() async {
    final response = await client
        .from('signals')
        .select()
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return response;
  }

  static Future<List<Map<String, dynamic>>> fetchSignalHistory(
    String userId,
  ) async {
    final deliveries = await client
        .from('signal_deliveries')
        .select('id, signal_id, status, delivered_at')
        .eq('user_id', userId)
        .order('delivered_at', ascending: false);
    if (deliveries.isEmpty) return const [];

    final ids = deliveries
        .map((row) => row['signal_id'])
        .whereType<int>()
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final signals = await client.from('signals').select().inFilter('id', ids);
    final byId = {for (final row in signals) row['id']: row};

    return [
      for (final delivery in deliveries)
        if (byId[delivery['signal_id']] != null)
          {...byId[delivery['signal_id']]!, 'delivered_at': delivery['delivered_at']}
    ];
  }

  static Future<List<Map<String, dynamic>>> fetchMarketData() async {
    return await client
        .from('market_data')
        .select()
        .order('updated_at', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications(
    String userId,
  ) async {
    return await client
        .from('notifications')
        .select()
        .or('user_id.is.null,user_id.eq.$userId')
        .order('created_at', ascending: false);
  }

  static Future<Map<String, String>> fetchPublicSettings() async {
    final rows = await client.from('admin_settings').select();
    return {
      for (final row in rows)
        if (row['key'] is String && row['value'] is String)
          row['key'] as String: row['value'] as String,
    };
  }

  static Future<void> createSupportMessage({
    required String userId,
    required String message,
  }) async {
    await client.from('support_messages').insert({
      'user_id': userId,
      'message': message.trim(),
    });
  }

  static Future<void> submitPayment({
    required String userId,
    required double amount,
    required String currency,
    required String paymentMethod,
    required String transactionId,
  }) async {
    await client.from('payments').insert({
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'transaction_id': transactionId.trim(),
    });
  }
}
