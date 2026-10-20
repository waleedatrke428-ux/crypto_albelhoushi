import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupabase {
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

  static Future<void> signOut() => client.auth.signOut();

  static Future<Map<String, dynamic>> fetchCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in required');
    return await client.from('users').select().eq('id', user.id).single();
  }

  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    return await client.from('users').select().order('created_at', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    return await client.from('subscriptions').select().order('created_at', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchTrials() async {
    return await client.from('trial_history').select().order('start_date', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchPayments() async {
    return await client.from('payments').select().order('created_at', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchSignals() async {
    return await client.from('signals').select().order('created_at', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> fetchSupportMessages() async {
    return await client
        .from('support_messages')
        .select()
        .order('created_at', ascending: false);
  }

  static Future<Map<String, String>> fetchSettings() async {
    final rows = await client.from('admin_settings').select();
    return {
      for (final row in rows)
        if (row['key'] is String && row['value'] is String)
          row['key'] as String: row['value'] as String,
    };
  }

  static Future<void> saveSetting(String key, String value) async {
    await saveSettings({key: value});
  }

  static Future<void> saveSettings(Map<String, String> settings) async {
    await client.from('admin_settings').upsert([
      for (final entry in settings.entries)
        {'key': entry.key, 'value': entry.value},
    ]);
  }

  static Future<void> publishSignal({
    required String pair,
    required String type,
    required double entry,
    required String targets,
    required double stopLoss,
    required String exchange,
    required String timeframe,
    required String rationale,
    required int strength,
    required bool isFree,
  }) async {
    await client.from('signals').insert({
      'pair': pair.trim().toUpperCase(),
      'type': type,
      'entry': entry,
      'targets': targets,
      'stop_loss': stopLoss,
      'exchange': exchange,
      'timeframe': timeframe,
      'rationale': rationale.trim(),
      'strength': strength,
      'is_free': isFree,
      'status': 'active',
      'result': 'open',
    });
  }

  static Future<void> activateSubscription({
    required String userId,
    required String planName,
    required int durationDays,
  }) async {
    await client.rpc(
      'admin_activate_subscription',
      params: {
        'target_user_id': userId,
        'target_plan_name': planName,
        'duration_days': durationDays,
      },
    );
  }

  static Future<void> setSignalResult({
    required int signalId,
    required String result,
  }) async {
    await client
        .from('signals')
        .update({
          'result': result,
          'status': result == 'open' ? 'active' : 'closed',
          'closed_at': result == 'open' ? null : DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', signalId);
  }

  static Future<void> reviewPayment({
    required int paymentId,
    required String status,
    String planName = 'monthly',
    int durationDays = 30,
  }) async {
    if (status == 'completed') {
      await client.rpc(
        'admin_confirm_payment',
        params: {
          'target_payment_id': paymentId,
          'target_plan_name': planName,
          'duration_days': durationDays,
        },
      );
      return;
    }
    await client.from('payments').update({'status': status}).eq('id', paymentId);
  }

  static Future<void> broadcastNotification({
    required String title,
    required String message,
  }) async {
    await client.from('notifications').insert({
      'title': title,
      'message': message,
    });
  }
}
