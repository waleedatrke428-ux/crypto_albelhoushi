import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/supabase_service.dart';

const _background = Color(0xFF090D14);
const _surface = Color(0xFF111824);
const _muted = Color(0xFF91A0B5);
const _green = Color(0xFF36D399);
const _red = Color(0xFFFF647C);
const _gold = Color(0xFFF3BD5B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AdminSupabase.initialize();
    runApp(const CryptoAdminApp());
  } catch (error) {
    runApp(CryptoAdminApp(startupError: error));
  }
}

class CryptoAdminApp extends StatefulWidget {
  const CryptoAdminApp({this.startupError, super.key});

  final Object? startupError;

  @override
  State<CryptoAdminApp> createState() => _CryptoAdminAppState();
}

class _CryptoAdminAppState extends State<CryptoAdminApp> {
  bool _english = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'كريبتو البلحوسي - الإدارة',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _green,
            brightness: Brightness.dark,
            surface: _surface,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: _background,
            surfaceTintColor: Colors.transparent,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: Directionality(
          textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
          child: widget.startupError == null
              ? AdminAuthGate(
                  english: _english,
                  onToggleLanguage: () => setState(() => _english = !_english),
                )
              : _StartupError(error: widget.startupError!, english: _english),
        ),
      );
}

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({
    required this.english,
    required this.onToggleLanguage,
    super.key,
  });

  final bool english;
  final VoidCallback onToggleLanguage;

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  late Session? _session;
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    _session = AdminSupabase.client.auth.currentSession;
    _subscription = AdminSupabase.client.auth.onAuthStateChange.listen((state) {
      if (mounted) setState(() => _session = state.session);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return AdminSignIn(
        english: widget.english,
        onToggleLanguage: widget.onToggleLanguage,
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_session!.user.id),
      future: AdminSupabase.fetchCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AccessDenied(
            error: snapshot.error!,
            english: widget.english,
            onSignOut: AdminSupabase.signOut,
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!['role'] != 'admin') {
          return _AccessDenied(
            error: StateError('Signed-in account does not have administrator role.'),
            english: widget.english,
            onSignOut: AdminSupabase.signOut,
          );
        }
        return AdminHome(
          english: widget.english,
          onToggleLanguage: widget.onToggleLanguage,
          onSignOut: AdminSupabase.signOut,
        );
      },
    );
  }
}

class AdminSignIn extends StatefulWidget {
  const AdminSignIn({
    required this.english,
    required this.onToggleLanguage,
    super.key,
  });

  final bool english;
  final VoidCallback onToggleLanguage;

  @override
  State<AdminSignIn> createState() => _AdminSignInState();
}

class _AdminSignInState extends State<AdminSignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String t(String ar, String en) => widget.english ? en : ar;

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _message(t('أدخل البريد وكلمة المرور.', 'Enter email and password.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminSupabase.signIn(email: _email.text, password: _password.text);
    } on AuthException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(t('تعذر تسجيل الدخول: $error', 'Sign-in failed: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: [
            TextButton(
              onPressed: widget.onToggleLanguage,
              child: Text(widget.english ? 'العربية' : 'EN'),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 68)),
                  const SizedBox(height: 16),
                  Text(
                    t('دخول المدير', 'Administrator sign in'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: t('البريد الإلكتروني', 'Email')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: t('كلمة المرور', 'Password')),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: _background,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t('تسجيل الدخول', 'Sign in')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class AdminHome extends StatefulWidget {
  const AdminHome({
    required this.english,
    required this.onToggleLanguage,
    required this.onSignOut,
    super.key,
  });

  final bool english;
  final VoidCallback onToggleLanguage;
  final VoidCallback onSignOut;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;
  late Future<_AdminData> _data;

  String t(String ar, String en) => widget.english ? en : ar;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_AdminData> _load() async {
    final values = await Future.wait<Object?>([
      AdminSupabase.fetchCurrentProfile(),
      AdminSupabase.fetchUsers(),
      AdminSupabase.fetchSubscriptions(),
      AdminSupabase.fetchTrials(),
      AdminSupabase.fetchPayments(),
      AdminSupabase.fetchSignals(),
      AdminSupabase.fetchSupportMessages(),
      AdminSupabase.fetchSettings(),
    ]);
    return _AdminData(
      profile: values[0]! as Map<String, dynamic>,
      users: values[1]! as List<Map<String, dynamic>>,
      subscriptions: values[2]! as List<Map<String, dynamic>>,
      trials: values[3]! as List<Map<String, dynamic>>,
      payments: values[4]! as List<Map<String, dynamic>>,
      signals: values[5]! as List<Map<String, dynamic>>,
      support: values[6]! as List<Map<String, dynamic>>,
      settings: values[7]! as Map<String, String>,
    );
  }

  void _refresh() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const BrandMark(size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t('إدارة كريبتو البلحوسي', 'Crypto Albelhoushi Admin'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: t('تحديث', 'Refresh'),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: t('تغيير اللغة', 'Change language'),
              onPressed: widget.onToggleLanguage,
              icon: const Icon(Icons.translate),
            ),
            IconButton(
              tooltip: t('تسجيل الخروج', 'Sign out'),
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<_AdminData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorPanel(
                  error: snapshot.error!,
                  english: widget.english,
                  onRetry: _refresh,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final pages = [
                _dashboard(data),
                _users(data),
                _signals(data),
                _payments(data),
                _settings(data),
                _support(data),
              ];
              return IndexedStack(index: _tab, children: pages);
            },
          ),
        ),
        floatingActionButton: _tab == 2
            ? FloatingActionButton.extended(
                onPressed: () => _composeSignal(context),
                backgroundColor: _green,
                foregroundColor: _background,
                icon: const Icon(Icons.add),
                label: Text(t('نشر إشارة', 'Publish signal')),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined), label: t('الرئيسية', 'Home')),
            NavigationDestination(
                icon: const Icon(Icons.people_outline), label: t('المستخدمون', 'Users')),
            NavigationDestination(
                icon: const Icon(Icons.bolt_outlined), label: t('الإشارات', 'Signals')),
            NavigationDestination(
                icon: const Icon(Icons.payments_outlined), label: t('المدفوعات', 'Payments')),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined), label: t('الإعدادات', 'Settings')),
            NavigationDestination(
                icon: const Icon(Icons.support_agent), label: t('الدعم', 'Support')),
          ],
        ),
      );

  Widget _dashboard(_AdminData data) {
    final today = DateTime.now();
    final newToday = data.users.where((row) => _sameDay(row['created_at'], today)).length;
    final paymentsToday = data.payments.where((row) => _sameDay(row['created_at'], today)).length;
    final activeSubs = data.subscriptions.where((row) =>
        row['status'] == 'active' &&
        DateTime.tryParse(row['expires_at']?.toString() ?? '')?.isAfter(DateTime.now()) == true).length;
    final activeTrials = data.trials.where((row) =>
        row['is_active'] == true &&
        DateTime.tryParse(row['end_date']?.toString() ?? '')?.isAfter(DateTime.now()) == true).length;
    final name = data.profile['name'] as String? ?? '';
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('مرحبًا، ${name.isEmpty ? 'المدير' : name}',
              'Welcome, ${name.isEmpty ? 'Admin' : name}'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(t('مؤشرات حقيقية من قاعدة البيانات',
              'Live metrics from your database'),
              style: const TextStyle(color: _muted)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              MetricCard(title: t('المستخدمون', 'Users'), value: '${data.users.length}', icon: Icons.people_outline, color: _gold),
              MetricCard(title: t('اشتراكات سارية', 'Active subscriptions'), value: '$activeSubs', icon: Icons.verified_user_outlined, color: _green),
              MetricCard(title: t('تجارب سارية', 'Active trials'), value: '$activeTrials', icon: Icons.hourglass_bottom, color: const Color(0xFF68A9FF)),
              MetricCard(title: t('إشارات منشورة', 'Published signals'), value: '${data.signals.length}', icon: Icons.bolt, color: _gold),
            ],
          ),
          const SizedBox(height: 18),
          SectionHeading(title: t('نشاط اليوم', 'Today')),
          Card(
            color: _surface,
            child: Column(
              children: [
                _ActivityRow(label: t('حسابات جديدة', 'New accounts'), value: '$newToday'),
                const Divider(height: 1),
                _ActivityRow(label: t('طلبات دفع جديدة', 'Payment requests'), value: '$paymentsToday'),
                const Divider(height: 1),
                _ActivityRow(label: t('رسائل دعم غير مقروءة', 'Support messages'), value: '${data.support.length}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeading(
            title: t('طلبات الدفع المعلقة', 'Pending payment requests'),
            action: t('عرض الكل', 'View all'),
            onTap: () => setState(() => _tab = 3),
          ),
          for (final payment in data.payments.where((row) => row['status'] == 'pending').take(5))
            _PaymentCard(
              payment: payment,
              english: widget.english,
              onReview: (status) => _reviewPayment(payment, status),
            ),
          if (data.payments.every((row) => row['status'] != 'pending'))
            EmptyPanel(text: t('لا توجد طلبات معلقة.', 'No pending payments.')),
        ],
      ),
    );
  }

  Widget _users(_AdminData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('إدارة المستخدمين', 'Manage users'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (data.users.isEmpty)
          EmptyPanel(text: t('لا يوجد مستخدمون في قاعدة البيانات.',
              'No users found in the database.'))
        else
          for (final user in data.users)
            _UserCard(
              user: user,
              subscription: _latestForUser(data.subscriptions, user['id'], 'created_at'),
              trial: _latestForUser(data.trials, user['id'], 'start_date'),
              english: widget.english,
              onActivate: () => _activateSubscription(context, user),
            ),
      ],
    );
  }

  Widget _signals(_AdminData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('الإشارات المنشورة', 'Published signals'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(t('الإشارات الآلية لا تُراجع هنا؛ يمكن متابعة نتائجها وتحديثها.',
            'Automated signals are not reviewed here; track and update outcomes.'),
            style: const TextStyle(color: _muted)),
        const SizedBox(height: 12),
        if (data.signals.isEmpty)
          EmptyPanel(text: t('لا توجد إشارات في قاعدة البيانات.',
              'No signals in the database.'))
        else
          for (final signal in data.signals)
            _SignalAdminCard(
              row: signal,
              english: widget.english,
              onResult: (result) => _setResult(signal, result),
            ),
      ],
    );
  }

  Widget _payments(_AdminData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('طلبات الدفع', 'Payment requests'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (data.payments.isEmpty)
          EmptyPanel(text: t('لا توجد طلبات دفع.', 'No payment requests.'))
        else
          for (final payment in data.payments)
            _PaymentCard(
              payment: payment,
              english: widget.english,
              onReview: (status) => _reviewPayment(payment, status),
            ),
      ],
    );
  }

  Widget _settings(_AdminData data) {
    return _SettingsEditor(
      english: widget.english,
      initialSettings: data.settings,
      onSave: (settings) async {
        await AdminSupabase.saveSettings(settings);
        _refresh();
      },
      onBroadcast: _broadcastNotification,
    );
  }

  Widget _support(_AdminData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('رسائل الدعم', 'Support messages'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (data.support.isEmpty)
          EmptyPanel(text: t('لا توجد رسائل دعم.', 'No support messages.'))
        else
          for (final message in data.support)
            Card(
              color: _surface,
              child: ListTile(
                leading: const Icon(Icons.support_agent, color: _gold),
                title: Text(message['message']?.toString() ?? ''),
                subtitle: Text(
                  '${message['user_id'] ?? ''} • ${_formatDate(DateTime.tryParse(message['created_at']?.toString() ?? ''))}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ),
      ],
    );
  }

  Map<String, dynamic>? _latestForUser(
    List<Map<String, dynamic>> rows,
    Object? userId,
    String dateField,
  ) {
    for (final row in rows) {
      if (row['user_id'] == userId &&
          (row[dateField] == null || row[dateField] is String)) {
        return row;
      }
    }
    return null;
  }

  Future<void> _activateSubscription(
      BuildContext context, Map<String, dynamic> user) async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) => const _SubscriptionDialog(),
    );
    if (result == null) return;
    try {
      await AdminSupabase.activateSubscription(
        userId: user['id'] as String,
        planName: result.$1,
        durationDays: result.$2,
      );
      _toast(t('تم تفعيل الاشتراك.', 'Subscription activated.'));
      _refresh();
    } catch (error) {
      _toast(t('تعذر تفعيل الاشتراك: $error',
          'Could not activate subscription: $error'));
    }
  }

  Future<void> _composeSignal(BuildContext context) async {
    final signal = await showDialog<_SignalInput>(
      context: context,
      builder: (context) => _SignalComposer(english: widget.english),
    );
    if (signal == null) return;
    try {
      await AdminSupabase.publishSignal(
        pair: signal.pair,
        type: signal.type,
        entry: signal.entry,
        targets: jsonEncode(signal.targets),
        stopLoss: signal.stopLoss,
        exchange: signal.exchange,
        timeframe: signal.timeframe,
        rationale: signal.rationale,
        strength: signal.strength,
        isFree: signal.isFree,
      );
      _toast(t('نُشرت الإشارة ووُزعت حسب صلاحية الحساب.',
          'Signal published and distributed according to access.'));
      _refresh();
    } catch (error) {
      _toast(t('تعذر نشر الإشارة: $error', 'Could not publish signal: $error'));
    }
  }

  Future<void> _setResult(Map<String, dynamic> signal, String result) async {
    try {
      await AdminSupabase.setSignalResult(
        signalId: signal['id'] as int,
        result: result,
      );
      _toast(t('تم تحديث نتيجة الإشارة.', 'Signal result updated.'));
      _refresh();
    } catch (error) {
      _toast(t('تعذر تحديث النتيجة: $error', 'Could not update result: $error'));
    }
  }

  Future<void> _reviewPayment(
      Map<String, dynamic> payment, String status) async {
    var planName = 'monthly';
    var durationDays = 30;
    if (status == 'completed') {
      final plan = await showDialog<(String, int)>(
        context: context,
        builder: (context) => const _SubscriptionDialog(),
      );
      if (plan == null) return;
      planName = plan.$1;
      durationDays = plan.$2;
    }
    try {
      await AdminSupabase.reviewPayment(
        paymentId: payment['id'] as int,
        status: status,
        planName: planName,
        durationDays: durationDays,
      );
      _toast(t('تم تحديث حالة الدفع.', 'Payment status updated.'));
      _refresh();
    } catch (error) {
      _toast(t('تعذر تحديث الدفع: $error', 'Could not update payment: $error'));
    }
  }

  Future<void> _broadcastNotification() async {
    final input = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _BroadcastDialog(),
    );
    if (input == null) return;
    try {
      await AdminSupabase.broadcastNotification(title: input.$1, message: input.$2);
      _toast(t('أُرسل الإشعار العام.', 'Broadcast notification sent.'));
      _refresh();
    } catch (error) {
      _toast(t('تعذر إرسال الإشعار: $error', 'Could not send notification: $error'));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminData {
  const _AdminData({
    required this.profile,
    required this.users,
    required this.subscriptions,
    required this.trials,
    required this.payments,
    required this.signals,
    required this.support,
    required this.settings,
  });

  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> subscriptions;
  final List<Map<String, dynamic>> trials;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> signals;
  final List<Map<String, dynamic>> support;
  final Map<String, String> settings;
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.subscription,
    required this.trial,
    required this.english,
    required this.onActivate,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? trial;
  final bool english;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final trialEnd = DateTime.tryParse(trial?['end_date']?.toString() ?? '');
    final subEnd = DateTime.tryParse(subscription?['expires_at']?.toString() ?? '');
    final activeSub = subscription?['status'] == 'active' &&
        (subEnd?.isAfter(DateTime.now()) ?? false);
    final activeTrial = trial?['is_active'] == true &&
        (trialEnd?.isAfter(DateTime.now()) ?? false);
    final status = activeSub
        ? (english ? 'Subscribed' : 'مشترك')
        : activeTrial
            ? (english ? 'Trial until ${_formatDate(trialEnd)}' : 'تجريبي حتى ${_formatDate(trialEnd)}')
            : (english ? 'No active access' : 'لا توجد صلاحية');
    return Card(
      color: _surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1D2938),
          child: Text(
            _firstLetter(user['name'] as String? ?? user['email'] as String?),
            style: const TextStyle(color: _gold),
          ),
        ),
        title: Text(user['name'] as String? ?? user['email']?.toString() ?? ''),
        subtitle: Text(
          '${user['email'] ?? ''}\n$status',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: english ? 'Activate subscription' : 'تفعيل اشتراك',
          onPressed: onActivate,
          icon: const Icon(Icons.workspace_premium_outlined, color: _green),
        ),
      ),
    );
  }
}

class _SignalAdminCard extends StatelessWidget {
  const _SignalAdminCard({
    required this.row,
    required this.english,
    required this.onResult,
  });

  final Map<String, dynamic> row;
  final bool english;
  final ValueChanged<String> onResult;

  @override
  Widget build(BuildContext context) {
    final results = {
      'open': english ? 'Open' : 'مفتوحة',
      'tp1': 'TP1',
      'tp2': 'TP2',
      'tp3': 'TP3',
      'stop_loss': english ? 'Stop loss' : 'وقف خسارة',
      'breakeven': english ? 'Breakeven' : 'تعادل',
    };
    return Card(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${row['pair']} • ${row['type']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (row['is_free'] == true)
                  const Icon(Icons.campaign_outlined, color: _gold, size: 18),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${row['exchange'] ?? ''} • ${row['timeframe'] ?? ''} • ${english ? 'Entry' : 'دخول'} ${row['entry']}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: results.containsKey(row['result']) ? row['result'] as String : 'open',
              decoration: InputDecoration(
                labelText: english ? 'Outcome' : 'النتيجة',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                for (final entry in results.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) onResult(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.english,
    required this.onReview,
  });

  final Map<String, dynamic> payment;
  final bool english;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) {
    final status = payment['status']?.toString() ?? '';
    return Card(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${payment['amount']} ${payment['currency'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${payment['payment_method'] ?? ''} • ${payment['transaction_id'] ?? ''}',
                style: const TextStyle(color: _muted, fontSize: 12)),
            Text('${payment['user_id'] ?? ''} • $status',
                style: const TextStyle(color: _muted, fontSize: 11)),
            if (status == 'pending')
              Row(
                children: [
                  TextButton(
                    onPressed: () => onReview('rejected'),
                    child: Text(english ? 'Reject' : 'رفض',
                        style: const TextStyle(color: _red)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => onReview('completed'),
                    child: Text(english ? 'Confirm payment' : 'تأكيد الدفع'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsEditor extends StatefulWidget {
  const _SettingsEditor({
    required this.english,
    required this.initialSettings,
    required this.onSave,
    required this.onBroadcast,
  });

  final bool english;
  final Map<String, String> initialSettings;
  final Future<void> Function(Map<String, String>) onSave;
  final VoidCallback onBroadcast;

  @override
  State<_SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<_SettingsEditor> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  static const _keys = {
    'monthly_price': ('السعر الشهري', 'Monthly price'),
    'annual_price': ('السعر السنوي', 'Annual price'),
    'currency': ('العملة', 'Currency'),
    'payment_methods': ('طرق الدفع والتعليمات', 'Payment methods/instructions'),
    'support_url': ('رابط الدعم', 'Support URL'),
    'support_email': ('بريد الدعم', 'Support email'),
  };

  String t(String ar, String en) => widget.english ? en : ar;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(covariant _SettingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      for (final entry in _controllers.entries) {
        entry.value.text = widget.initialSettings[entry.key] ?? '';
      }
    }
  }

  void _initializeControllers() {
    for (final key in _keys.keys) {
      _controllers[key] = TextEditingController(
        text: widget.initialSettings[key] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave({
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('تم حفظ الإعدادات.', 'Settings saved.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('تعذر الحفظ: $error', 'Save failed: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('إعدادات التطبيق', 'App settings'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final entry in _keys.entries) ...[
            TextField(
              controller: _controllers[entry.key],
              maxLines: entry.key == 'payment_methods' ? 3 : 1,
              keyboardType: entry.key.endsWith('price')
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: t(entry.value.$1, entry.value.$2),
                helperText: widget.initialSettings.containsKey(entry.key)
                    ? null
                    : t('لم تُسجل هذه القيمة في قاعدة البيانات بعد.',
                        'This key is not yet present in the database.'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(t('حفظ الإعدادات', 'Save settings')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onBroadcast,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(t('إرسال إشعار عام', 'Broadcast notification')),
          ),
          const SizedBox(height: 16),
          _InfoNotice(
            textAr: 'لا تتضمن قاعدة البيانات الحالية بيانات شموع أو مزود أخبار أو توكنات Push. يلزم ربط هذه الخدمات قبل إظهارها كميزات مباشرة.',
            textEn: 'The current schema has no candle feed, news provider, or push-token storage. Those services must be integrated before being shown as live features.',
            english: widget.english,
          ),
        ],
      );
}

class _SignalInput {
  const _SignalInput({
    required this.pair,
    required this.type,
    required this.entry,
    required this.targets,
    required this.stopLoss,
    required this.exchange,
    required this.timeframe,
    required this.rationale,
    required this.strength,
    required this.isFree,
  });

  final String pair;
  final String type;
  final double entry;
  final List<double> targets;
  final double stopLoss;
  final String exchange;
  final String timeframe;
  final String rationale;
  final int strength;
  final bool isFree;
}

class _SignalComposer extends StatefulWidget {
  const _SignalComposer({required this.english});

  final bool english;

  @override
  State<_SignalComposer> createState() => _SignalComposerState();
}

class _SignalComposerState extends State<_SignalComposer> {
  final _formKey = GlobalKey<FormState>();
  final _pair = TextEditingController();
  final _entry = TextEditingController();
  final _stop = TextEditingController();
  final _targets = List.generate(3, (_) => TextEditingController());
  final _rationale = TextEditingController();
  String _type = 'LONG';
  String _exchange = 'Binance';
  String _timeframe = '15m';
  double _strength = 70;
  bool _isFree = true;

  String t(String ar, String en) => widget.english ? en : ar;

  @override
  void dispose() {
    _pair.dispose();
    _entry.dispose();
    _stop.dispose();
    _rationale.dispose();
    for (final controller in _targets) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _validPrice(String? value) {
    final price = double.tryParse(value ?? '');
    return price != null && price > 0 ? price : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(t('نشر إشارة تداول', 'Publish trading signal')),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _pair,
                    decoration: InputDecoration(labelText: t('الزوج', 'Pair')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? t('هذا الحقل مطلوب.', 'Required.')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _exchange,
                    decoration: InputDecoration(labelText: t('المنصة', 'Exchange')),
                    items: const ['Binance', 'Bybit', 'OKX']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _exchange = value ?? 'Binance'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: InputDecoration(labelText: t('الاتجاه', 'Direction')),
                    items: const [
                      DropdownMenuItem(value: 'LONG', child: Text('LONG')),
                      DropdownMenuItem(value: 'SHORT', child: Text('SHORT')),
                    ],
                    onChanged: (value) => setState(() => _type = value ?? 'LONG'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _timeframe,
                    decoration: InputDecoration(labelText: t('الإطار الزمني', 'Timeframe')),
                    items: const ['5m', '15m', '1h', '4h', '1d']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _timeframe = value ?? '15m'),
                  ),
                  const SizedBox(height: 8),
                  _priceInput(_entry, t('سعر الدخول', 'Entry')),
                  _priceInput(_stop, t('وقف الخسارة', 'Stop loss')),
                  for (var i = 0; i < _targets.length; i++)
                    _priceInput(_targets[i], '${t('الهدف', 'Target')} ${i + 1}'),
                  TextFormField(
                    controller: _rationale,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: t('سبب الإشارة', 'Rationale')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? t('أدخل تفسير الإشارة.', 'Enter the signal rationale.')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text(t('قوة الإشارة', 'Signal strength'))),
                      Text('${_strength.round()}%'),
                    ],
                  ),
                  Slider(
                    value: _strength,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: _green,
                    onChanged: (value) => setState(() => _strength = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isFree,
                    activeColor: _green,
                    title: Text(t('إشارة مجانية للجميع', 'Free signal for all users')),
                    onChanged: (value) => setState(() => _isFree = value),
                  ),
                  _InfoNotice(
                    textAr: 'تُنشر الإشارة فورًا عند الحفظ. القيم يجب أن تكون صحيحة؛ لا يجري هذا التطبيق توليدًا آليًا للإشارات.',
                    textEn: 'Saving publishes immediately. Verify all levels; this app does not generate AI signals.',
                    english: widget.english,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final entry = double.parse(_entry.text);
              final stop = double.parse(_stop.text);
              final targets = _targets.map((controller) => double.parse(controller.text)).toList();
              final targetsOrdered = _type == 'LONG'
                  ? targets[0] < targets[1] && targets[1] < targets[2]
                  : targets[0] > targets[1] && targets[1] > targets[2];
              final correctlyOrdered = _type == 'LONG'
                  ? stop < entry && targets.every((target) => target > entry)
                  : stop > entry && targets.every((target) => target < entry);
              if (!correctlyOrdered || !targetsOrdered) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t(
                    'تحقق من ترتيب الدخول ووقف الخسارة والأهداف.',
                    'Check entry, stop-loss and target ordering.',
                  ))),
                );
                return;
              }
              Navigator.pop(
                context,
                _SignalInput(
                  pair: _pair.text,
                  type: _type,
                  entry: entry,
                  targets: targets,
                  stopLoss: stop,
                  exchange: _exchange,
                  timeframe: _timeframe,
                  rationale: _rationale.text,
                  strength: _strength.round(),
                  isFree: _isFree,
                ),
              );
            },
            child: Text(t('نشر الإشارة', 'Publish')),
          ),
        ],
      );

  Widget _priceInput(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          validator: (value) =>
              _validPrice(value) == null ? t('أدخل سعرًا موجبًا.', 'Enter a positive price.') : null,
        ),
      );
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog();

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final _plan = TextEditingController(text: 'monthly');
  final _days = TextEditingController(text: '30');
  bool _annual = false;

  void _selectAnnual(bool annual) {
    setState(() {
      _annual = annual;
      _plan.text = annual ? 'annual' : 'monthly';
      _days.text = annual ? '365' : '30';
    });
  }

  @override
  void dispose() {
    _plan.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('تفعيل اشتراك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('شهري')),
                ButtonSegment(value: true, label: Text('سنوي')),
              ],
              selected: {_annual},
              onSelectionChanged: (selection) => _selectAnnual(selection.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: _plan, decoration: const InputDecoration(labelText: 'اسم الخطة')),
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الأيام'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final days = int.tryParse(_days.text);
              if (days == null || days < 1) return;
              Navigator.pop(context, (_plan.text.trim(), days));
            },
            child: const Text('تفعيل'),
          ),
        ],
      );
}

class _BroadcastDialog extends StatefulWidget {
  const _BroadcastDialog();

  @override
  State<_BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<_BroadcastDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('إشعار عام'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _message,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'الرسالة'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: _title.text.trim().isEmpty || _message.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (_title.text.trim(), _message.text.trim())),
            child: const Text('إرسال'),
          ),
        ],
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: _surface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
      );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: _muted))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.action, this.onTap, super.key});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ],
      );
}

class _InfoNotice extends StatelessWidget {
  _InfoNotice({
    required this.textAr,
    required this.textEn,
    required this.english,
  });

  final String textAr;
  final String textEn;
  final bool english;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF172130),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                english ? textEn : textAr,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF26364A)),
        ),
        child: Text(text, style: const TextStyle(color: _muted, height: 1.4)),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.error,
    required this.english,
    required this.onRetry,
  });

  final Object error;
  final bool english;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: _red, size: 36),
              const SizedBox(height: 12),
              Text(
                english ? 'Could not load data from Supabase.' : 'تعذر تحميل البيانات من Supabase.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(english ? 'Retry' : 'إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({
    required this.error,
    required this.english,
    required this.onSignOut,
  });

  final Object error;
  final bool english;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, color: _red, size: 42),
                const SizedBox(height: 12),
                Text(english ? 'Admin access denied.' : 'لا تملك صلاحية المدير.',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 14),
                FilledButton(onPressed: onSignOut, child: Text(english ? 'Sign out' : 'تسجيل الخروج')),
              ],
            ),
          ),
        ),
      );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.english});

  final Object error;
  final bool english;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 64),
                const SizedBox(height: 16),
                Text(english ? 'Supabase is not configured.' : 'إعدادات Supabase غير متوفرة.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(error.toString(), textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}

class BrandMark extends StatelessWidget {
  const BrandMark({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_green, Color(0xFF138C91)]),
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(Icons.show_chart, color: _background, size: size * .62),
      );
}

bool _sameDay(Object? value, DateTime day) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return date != null &&
      date.year == day.year &&
      date.month == day.month &&
      date.day == day.day;
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _firstLetter(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
}
