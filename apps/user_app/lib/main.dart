import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/signal_model.dart';
import 'services/supabase_service.dart';

const _background = Color(0xFF090D14);
const _surface = Color(0xFF111824);
const _muted = Color(0xFF91A0B5);
const _green = Color(0xFF36D399);
const _red = Color(0xFFFF647C);
const _gold = Color(0xFFF3BD5B);

String _requestErrorMessage(Object error, {required bool english}) {
  final details = error.toString().toLowerCase();
  if (details.contains('failed host lookup') ||
      details.contains('no address associated with hostname') ||
      details.contains('socketexception')) {
    return english
        ? 'Could not reach the server. Check your internet connection, turn off VPN or Private DNS temporarily, then try again using mobile data or another Wi-Fi network.'
        : 'تعذر الوصول إلى الخادم. تحقق من الإنترنت، وأوقف VPN أو DNS الخاص مؤقتًا، ثم أعد المحاولة عبر بيانات الهاتف أو شبكة Wi-Fi أخرى.';
  }
  return english
      ? 'Could not complete the request: $error'
      : 'تعذر إكمال العملية: $error';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppSupabase.initialize();
    runApp(const CryptoUserApp());
  } catch (error) {
    runApp(CryptoUserApp(startupError: error));
  }
}

class CryptoUserApp extends StatefulWidget {
  const CryptoUserApp({this.startupError, super.key});

  final Object? startupError;

  @override
  State<CryptoUserApp> createState() => _CryptoUserAppState();
}

class _CryptoUserAppState extends State<CryptoUserApp> {
  bool _english = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'كريبتو البلحوسي',
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
            ? AuthGate(
                english: _english,
                onToggleLanguage: () => setState(() => _english = !_english),
              )
            : _StartupError(error: widget.startupError!, english: _english),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.english,
    required this.onToggleLanguage,
    super.key,
  });

  final bool english;
  final VoidCallback onToggleLanguage;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session;
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    _session = AppSupabase.client.auth.currentSession;
    _subscription = AppSupabase.client.auth.onAuthStateChange.listen((state) {
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
      return SignInScreen(
        english: widget.english,
        onToggleLanguage: widget.onToggleLanguage,
      );
    }
    return UserHome(
      key: ValueKey(_session!.user.id),
      user: _session!.user,
      english: widget.english,
      onToggleLanguage: widget.onToggleLanguage,
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.english,
    required this.onToggleLanguage,
    super.key,
  });

  final bool english;
  final VoidCallback onToggleLanguage;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String t(String ar, String en) => widget.english ? en : ar;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        final response = await AppSupabase.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        if (response.session == null) {
          _message(t(
            'تم إنشاء الحساب. تحقق من بريدك لتأكيده ثم سجّل الدخول.',
            'Account created. Verify your email, then sign in.',
          ));
        }
      } else {
        await AppSupabase.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(_requestErrorMessage(error, english: widget.english));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _message(t('أدخل بريدك الإلكتروني أولًا.', 'Enter your email address first.'));
      return;
    }
    try {
      await AppSupabase.sendPasswordReset(email);
      _message(t('أرسلنا رابط استعادة كلمة المرور إلى بريدك.',
          'Password reset link sent to your email.'));
    } on AuthException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(_requestErrorMessage(error, english: widget.english));
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: widget.onToggleLanguage,
            child: Text(widget.english ? 'العربية' : 'EN'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandMark(size: 78)),
                    const SizedBox(height: 18),
                    Text(
                      t('كريبتو البلحوسي', 'Crypto Albelhoushi'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('رؤى السوق، بوضوح.', 'Market insight, made clear.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 30),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: t('الاسم', 'Name')),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? t('أدخل اسمك.', 'Enter your name.')
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t('البريد الإلكتروني', 'Email address'),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (value) => value == null || !value.contains('@')
                          ? t('أدخل بريدًا إلكترونيًا صالحًا.', 'Enter a valid email.')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: t('كلمة المرور', 'Password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? t('كلمة المرور يجب ألا تقل عن 8 أحرف.',
                              'Password must be at least 8 characters.')
                          : null,
                    ),
                    if (!_register)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: Text(t('نسيت كلمة المرور؟', 'Forgot password?')),
                        ),
                      ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
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
                          : Text(_register
                              ? t('إنشاء الحساب', 'Create account')
                              : t('تسجيل الدخول', 'Sign in')),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(_register
                          ? t('لديك حساب؟ سجّل الدخول', 'Already registered? Sign in')
                          : t('إنشاء حساب جديد', 'Create an account')),
                    ),
                    const SizedBox(height: 12),
                    RiskNotice(english: widget.english),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserHome extends StatefulWidget {
  const UserHome({
    required this.user,
    required this.english,
    required this.onToggleLanguage,
    super.key,
  });

  final User user;
  final bool english;
  final VoidCallback onToggleLanguage;

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _tab = 0;
  late Future<_UserData> _data;

  String t(String ar, String en) => widget.english ? en : ar;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_UserData> _load() async {
    final id = widget.user.id;
    final values = await Future.wait<Object?>([
      AppSupabase.fetchProfile(id),
      AppSupabase.fetchSubscription(id),
      AppSupabase.fetchTrial(id),
      AppSupabase.fetchSignals(),
      AppSupabase.fetchMarketData(),
      AppSupabase.fetchNotifications(id),
      AppSupabase.fetchSignalHistory(id),
      AppSupabase.fetchPublicSettings(),
    ]);
    return _UserData(
      profile: values[0]! as Map<String, dynamic>,
      subscription: values[1] as Map<String, dynamic>?,
      trial: values[2] as Map<String, dynamic>?,
      signals: (values[3]! as List<Map<String, dynamic>>)
          .map(SignalModel.fromJson)
          .toList(),
      markets: values[4]! as List<Map<String, dynamic>>,
      notifications: values[5]! as List<Map<String, dynamic>>,
      history: (values[6]! as List<Map<String, dynamic>>)
          .map(SignalModel.fromJson)
          .toList(),
      settings: values[7]! as Map<String, String>,
    );
  }

  void _refresh() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    final labels = [
      t('الرئيسية', 'Overview'),
      t('الإشارات', 'Signals'),
      t('السوق', 'Market'),
      t('حسابي', 'Account'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                t('كريبتو البلحوسي', 'Crypto Albelhoushi'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: t('الإشعارات', 'Notifications'),
            onPressed: () => setState(() => _tab = 4),
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: t('تغيير اللغة', 'Change language'),
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: t('تحديث', 'Refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_UserData>(
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
              _overview(data),
              _signals(data),
              _markets(data),
              _account(data),
              _notifications(data),
            ];
            return IndexedStack(index: _tab, children: pages);
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab > 3 ? 3 : _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon([
                Icons.dashboard_outlined,
                Icons.bolt_outlined,
                Icons.show_chart,
                Icons.person_outline,
              ][i]),
              selectedIcon: Icon([
                Icons.dashboard,
                Icons.bolt,
                Icons.show_chart,
                Icons.person,
              ][i]),
              label: labels[i],
            ),
        ],
      ),
    );
  }

  Widget _overview(_UserData data) {
    final name = data.profile['name'] as String? ?? widget.user.email ?? '';
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('مرحبًا، $name', 'Welcome, $name'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(t('بيانات مباشرة من حسابك', 'Live data from your account'),
              style: const TextStyle(color: _muted)),
          const SizedBox(height: 16),
          _entitlementCard(data),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: t('الإشارات المتاحة', 'Available signals'),
                  value: '${data.signals.length}',
                  icon: Icons.bolt,
                  color: _gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  title: t('سجل الإشارات', 'Signal history'),
                  value: '${data.history.length}',
                  icon: Icons.history,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionHeading(
            title: t('أحدث الإشارات', 'Latest signals'),
            action: t('عرض الكل', 'View all'),
            onTap: () => setState(() => _tab = 1),
          ),
          const SizedBox(height: 8),
          if (data.signals.isEmpty)
            EmptyPanel(text: t('لا توجد إشارات متاحة لحسابك الآن.',
                'No signals are available to your account right now.'))
          else
            for (final signal in data.signals.take(3))
              SignalCard(
                signal: signal,
                english: widget.english,
                onTap: () => _openSignal(context, signal, widget.english),
              ),
          const SizedBox(height: 12),
          RiskNotice(english: widget.english),
        ],
      ),
    );
  }

  Widget _signals(_UserData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('إشارات التداول', 'Trading signals'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (data.signals.isEmpty)
          EmptyPanel(text: t(
            'لا توجد إشارات متاحة. ستظهر الإشارات العامة أو المؤهلة حسب صلاحية الحساب.',
            'No signals available. Public or entitled signals appear based on account access.',
          ))
        else
          for (final signal in data.signals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SignalCard(
                signal: signal,
                english: widget.english,
                onTap: () => _openSignal(context, signal, widget.english),
              ),
            ),
        const SizedBox(height: 8),
        RiskNotice(english: widget.english),
      ],
    );
  }

  Widget _markets(_UserData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('السوق', 'Market'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(t('آخر أسعار مزودة في جدول market_data',
            'Latest prices supplied in market_data'),
            style: const TextStyle(color: _muted)),
        const SizedBox(height: 12),
        if (data.markets.isEmpty)
          EmptyPanel(text: t('لا توجد بيانات سوق من الخادم.',
              'No market data has been provided by the server.'))
        else
          for (final row in data.markets)
            MarketRow(row: row, english: widget.english),
        const SizedBox(height: 10),
        EmptyPanel(text: t(
          'لا يحتوي المخطط الحالي على شموع تاريخية أو مصدر شارت مباشر. أضف مصدر بيانات أو تكامل TradingView لعرضه.',
          'The current schema has no candle history or live chart source. Add a market feed or TradingView integration to display charts.',
        )),
      ],
    );
  }

  Widget _account(_UserData data) {
    final displayName = data.profile['name'] as String? ?? '';
    final active = data.subscription;
    final trial = data.trial;
    final canAccess = active != null || trial != null;
    final trialEnd = DateTime.tryParse(trial?['end_date']?.toString() ?? '');
    final daysLeft = trialEnd == null
        ? null
        : trialEnd.difference(DateTime.now()).inDays.clamp(0, 6);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('حسابي', 'My account'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _entitlementCard(data),
        Card(
          color: _surface,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, color: _gold),
                title: Text(displayName.isEmpty ? widget.user.email ?? '' : displayName),
                subtitle: Text(widget.user.email ?? '',
                    style: const TextStyle(color: _muted)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history, color: _gold),
                title: Text(t('سجل الإشارات', 'Signal history')),
                subtitle: Text(t('${data.history.length} إشارة مستلمة',
                    '${data.history.length} delivered signals')),
                trailing: Text(_winRate(data.history, widget.english),
                    style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
                onTap: () => _showHistory(context, data.history, widget.english),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined, color: _gold),
                title: Text(t('طلب اشتراك', 'Request subscription')),
                onTap: () => _showPaymentForm(context, data),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent, color: _gold),
                title: Text(t('إرسال رسالة للدعم', 'Contact support')),
                onTap: () => _showSupportForm(context),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: _red),
                title: Text(t('تسجيل الخروج', 'Sign out')),
                onTap: AppSupabase.signOut,
              ),
            ],
          ),
        ),
        if (!canAccess) ...[
          const SizedBox(height: 12),
          EmptyPanel(text: t('انتهت التجربة أو لم تبدأ. أرسل طلب اشتراك للتواصل مع الإدارة.',
              'Your trial has ended or has not started. Submit a subscription request to contact the administrator.')),
        ],
        if (daysLeft != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(t('الأيام المتبقية من التجربة: $daysLeft',
                'Trial days remaining: $daysLeft'),
                style: const TextStyle(color: _muted)),
          ),
        const SizedBox(height: 12),
        RiskNotice(english: widget.english),
      ],
    );
  }

  Widget _notifications(_UserData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('الإشعارات', 'Notifications'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (data.notifications.isEmpty)
          EmptyPanel(text: t('لا توجد إشعارات.', 'No notifications.'))
        else
          for (final item in data.notifications)
            Card(
              color: _surface,
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: _gold),
                title: Text(item['title']?.toString() ?? ''),
                subtitle: Text(item['message']?.toString() ?? ''),
                trailing: Text(_date(item['created_at']),
                    style: const TextStyle(color: _muted, fontSize: 10)),
              ),
            ),
      ],
    );
  }

  Widget _entitlementCard(_UserData data) {
    final subscription = data.subscription;
    final trial = data.trial;
    final expires = subscription?['expires_at'] ?? trial?['end_date'];
    final until = expires == null ? '' : _date(expires);
    final text = subscription != null
        ? t('اشتراك فعّال حتى $until', 'Active subscription until $until')
        : trial != null
            ? t('فترة تجريبية نشطة حتى $until', 'Trial active until $until')
            : t('لا يوجد اشتراك فعّال', 'No active subscription');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF162A2B), Color(0xFF172130)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF28504A)),
      ),
      child: Row(
        children: [
          Icon(
            subscription != null || trial != null
                ? Icons.workspace_premium_outlined
                : Icons.lock_outline,
            color: subscription != null || trial != null ? _green : _gold,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _winRate(List<SignalModel> history, bool english) {
    final closed = history.where((signal) => signal.result != 'open').toList();
    if (closed.isEmpty) return english ? 'N/A' : 'غير متاح';
    final wins = closed.where((signal) => signal.result.startsWith('tp')).length;
    return '${(wins * 100 / closed.length).toStringAsFixed(0)}%';
  }

  Future<void> _showPaymentForm(BuildContext context, _UserData data) async {
    final transaction = TextEditingController();
    final method = TextEditingController();
    final amount = TextEditingController(
      text: data.settings['monthly_price'] ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('طلب اشتراك يدوي', 'Manual subscription request')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t('المبلغ', 'Amount')),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? t('أدخل مبلغًا صالحًا.', 'Enter a valid amount.')
                    : null,
              ),
              TextFormField(
                controller: method,
                decoration: InputDecoration(labelText: t('طريقة الدفع', 'Payment method')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? t('هذا الحقل مطلوب.', 'Required field.')
                    : null,
              ),
              TextFormField(
                controller: transaction,
                decoration: InputDecoration(labelText: t('رقم العملية/الإيصال', 'Transaction/receipt reference')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? t('أدخل مرجع الدفع.', 'Enter payment reference.')
                    : null,
              ),
              const SizedBox(height: 8),
              Text(t('سيبقى الطلب قيد المراجعة حتى يؤكده المدير.',
                  'The request remains pending until an administrator confirms it.'),
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: Text(t('إرسال الطلب', 'Submit request')),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await AppSupabase.submitPayment(
          userId: widget.user.id,
          amount: double.parse(amount.text),
          currency: data.settings['currency'] ?? 'USD',
          paymentMethod: method.text.trim(),
          transactionId: transaction.text.trim(),
        );
        _message(t('أُرسل طلب الدفع للمراجعة.', 'Payment request submitted for review.'));
        _refresh();
      } catch (error) {
        _message(t('تعذر إرسال الطلب: $error', 'Could not submit request: $error'));
      }
    }
    transaction.dispose();
    method.dispose();
    amount.dispose();
  }

  Future<void> _showSupportForm(BuildContext context) async {
    final message = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('رسالة للدعم', 'Support message')),
        content: TextField(
          controller: message,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: t('اكتب رسالتك', 'Your message')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('إرسال', 'Send')),
          ),
        ],
      ),
    );
    if (result == true && message.text.trim().isNotEmpty) {
      try {
        await AppSupabase.createSupportMessage(
          userId: widget.user.id,
          message: message.text,
        );
        _message(t('تم إرسال الرسالة.', 'Message sent.'));
      } catch (error) {
        _message(t('تعذر إرسال الرسالة: $error', 'Could not send message: $error'));
      }
    }
    message.dispose();
  }

  void _showHistory(
    BuildContext context,
    List<SignalModel> history,
    bool english,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t('سجل الإشارات', 'Signal history'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (history.isEmpty)
                EmptyPanel(text: t('لا يوجد سجل بعد.', 'No history yet.')),
              for (final signal in history)
                SignalCard(
                  signal: signal,
                  english: english,
                  onTap: () => _openSignal(context, signal, english),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _UserData {
  const _UserData({
    required this.profile,
    required this.subscription,
    required this.trial,
    required this.signals,
    required this.markets,
    required this.notifications,
    required this.history,
    required this.settings,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? trial;
  final List<SignalModel> signals;
  final List<Map<String, dynamic>> markets;
  final List<Map<String, dynamic>> notifications;
  final List<SignalModel> history;
  final Map<String, String> settings;
}

class SignalCard extends StatelessWidget {
  const SignalCard({
    required this.signal,
    required this.english,
    required this.onTap,
    super.key,
  });

  final SignalModel signal;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final long = signal.type.toUpperCase() == 'LONG' || signal.type.toUpperCase() == 'BUY';
    return Card(
      color: _surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1D2938),
                    child: Icon(Icons.currency_bitcoin, color: _gold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(signal.pair, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          [
                            signal.exchange,
                            signal.timeframe,
                            if (signal.isFree) english ? 'Free' : 'مجانية',
                          ].where((part) => part.isNotEmpty).join(' • '),
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    long ? 'LONG' : 'SHORT',
                    style: TextStyle(
                      color: long ? _green : _red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 14,
                runSpacing: 8,
                children: [
                  _PriceLabel(title: english ? 'ENTRY' : 'الدخول', value: _price(signal.entry)),
                  _PriceLabel(title: english ? 'STOP' : 'وقف الخسارة', value: _price(signal.stopLoss), color: _red),
                  _PriceLabel(title: english ? 'STRENGTH' : 'القوة', value: '${signal.strength}%', color: _gold),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                english ? 'Targets: ${signal.targetLevels.join(' · ')}'
                    : 'الأهداف: ${signal.targetLevels.join(' · ')}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openSignal(BuildContext context, SignalModel signal, bool english) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _background,
    builder: (context) => Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(signal.pair,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  Text(signal.type.toUpperCase(),
                      style: TextStyle(
                        color: signal.type.toUpperCase() == 'LONG' ? _green : _red,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              const SizedBox(height: 5),
              Text('${signal.exchange} • ${signal.timeframe}',
                  style: const TextStyle(color: _muted)),
              const SizedBox(height: 16),
              _ChartUnavailable(english: english),
              const SizedBox(height: 18),
              Text(english ? 'Trade levels' : 'مستويات الصفقة',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              LevelRow(label: english ? 'ENTRY' : 'الدخول', value: _price(signal.entry), color: _gold),
              LevelRow(label: english ? 'STOP LOSS' : 'وقف الخسارة', value: _price(signal.stopLoss), color: _red),
              for (var i = 0; i < signal.targetLevels.length; i++)
                LevelRow(
                  label: '${english ? 'TAKE PROFIT' : 'الهدف'} ${i + 1}',
                  value: signal.targetLevels[i],
                  color: _green,
                ),
              const SizedBox(height: 12),
              Text(english ? 'Signal rationale' : 'سبب الإشارة',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                signal.rationale.isEmpty
                    ? (english ? 'No rationale was supplied for this signal.' : 'لم يُرفق تفسير لهذه الإشارة.')
                    : signal.rationale,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              RiskNotice(english: english),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChartUnavailable extends StatelessWidget {
  const _ChartUnavailable({required this.english});

  final bool english;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26364A)),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                english
                    ? 'Live candles are not included in the supplied database schema.'
                    : 'بيانات الشموع المباشرة غير موجودة في مخطط قاعدة البيانات المرسل.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _DynamicWatermark(english: english),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicWatermark extends StatefulWidget {
  const _DynamicWatermark({required this.english});

  final bool english;

  @override
  State<_DynamicWatermark> createState() => _DynamicWatermarkState();
}

class _DynamicWatermarkState extends State<_DynamicWatermark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Align(
          alignment: Alignment(
            .7 - _controller.value * 1.4,
            .65 - _controller.value * 1.2,
          ),
          child: child,
        ),
        child: Transform.rotate(
          angle: -.15,
          child: Text(
            widget.english ? 'Waleed Turki Alhamad' : 'وليد تركي الحمد',
            style: TextStyle(
              color: Colors.white.withOpacity(.18),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
      );
}

class MarketRow extends StatelessWidget {
  const MarketRow({required this.row, required this.english, super.key});

  final Map<String, dynamic> row;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(row['price']?.toString() ?? '');
    final change = double.tryParse(row['change_24h']?.toString() ?? '');
    final positive = (change ?? 0) >= 0;
    return Card(
      color: _surface,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1D2938),
          child: Icon(Icons.show_chart, color: _gold),
        ),
        title: Text(row['symbol']?.toString() ?? ''),
        subtitle: Text(
          '${english ? 'Updated' : 'تحديث'}: ${_date(row['updated_at'])}',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price == null ? '—' : _price(price)),
            Text(
              change == null ? '—' : '${change.toStringAsFixed(2)}%',
              style: TextStyle(color: positive ? _green : _red, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.title, required this.value, this.color});

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _muted, fontSize: 9)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      );
}

class LevelRow extends StatelessWidget {
  const LevelRow({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
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
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
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
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ],
      );
}

class RiskNotice extends StatelessWidget {
  const RiskNotice({required this.english, super.key});

  final bool english;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF251D16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF5A4225)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: _gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                english
                    ? 'Futures trading is high risk. Please respect the stop-loss. When target 1 is reached, move the stop-loss to entry as specified by the signal.'
                    : 'التداول في العقود الآجلة عالي المخاطر؛ يرجى الالتزام بوقف الخسارة. عند بلوغ الهدف الأول، انقل وقف الخسارة إلى سعر الدخول وفق الإشارة.',
                style: const TextStyle(color: Color(0xFFFFD391), height: 1.45, fontSize: 12),
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
                english
                    ? 'Could not load account data from Supabase.'
                    : 'تعذر تحميل بيانات الحساب من Supabase.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(error.toString(),
                  textAlign: TextAlign.center,
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
                Text(
                  english
                      ? 'The app could not start.'
                      : 'تعذر بدء التطبيق.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}

String _price(double value) => value.toStringAsFixed(value.abs() >= 100 ? 2 : 4);

String _date(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
