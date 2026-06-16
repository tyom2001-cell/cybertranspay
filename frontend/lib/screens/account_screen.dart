import 'package:cybertranspay/config.dart';
import 'package:cybertranspay/services/auth_client.dart';
import 'package:flutter/material.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.auth});

  final AuthClient auth;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  String? _error;
  String? _message;
  AuthSession? _session;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите email и пароль');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final session = _registerMode
          ? await widget.auth.signUp(email: email, password: password)
          : await widget.auth.signIn(email: email, password: password);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        _message = _registerMode
            ? 'Аккаунт создан. Можно отправить письмо подтверждения.'
            : 'Вход выполнен';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выполнить вход: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sendVerification() async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await widget.auth.sendEmailVerification(session.idToken);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Письмо подтверждения отправлено';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось отправить письмо: $e';
        _loading = false;
      });
    }
  }

  void _signOut() {
    setState(() {
      _session = null;
      _message = 'Сессия завершена';
      _error = null;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF060816),
            Color(0xFF0B1434),
            Color(0xFF10163A),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            Text(
              'Личный кабинет',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Firebase Auth, профиль, безопасность и история переводов.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (!widget.auth.isConfigured)
              const _SecurityBanner(
                icon: Icons.key_off,
                title: 'Firebase пока не подключен',
                text:
                    'Передайте FIREBASE_WEB_API_KEY через --dart-define, чтобы включить регистрацию и вход.',
                warning: true,
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _SecurityBanner(
                icon: Icons.error_outline,
                title: 'Ошибка',
                text: _error!,
                warning: true,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              _SecurityBanner(
                icon: Icons.check_circle_outline,
                title: 'Готово',
                text: _message!,
              ),
            ],
            const SizedBox(height: 16),
            if (session == null)
              _AuthPanel(
                emailController: _emailController,
                passwordController: _passwordController,
                registerMode: _registerMode,
                loading: _loading,
                enabled: widget.auth.isConfigured,
                onModeChanged: (value) {
                  setState(() {
                    _registerMode = value;
                    _error = null;
                    _message = null;
                  });
                },
                onSubmit: _submit,
              )
            else
              _ProfilePanel(
                session: session,
                loading: _loading,
                onSendVerification: _sendVerification,
                onSignOut: _signOut,
              ),
            const SizedBox(height: 16),
            _SecurityChecklist(
              firebaseConfigured: AppConfig.hasFirebaseWebApiKey,
              apiKeyConfigured: AppConfig.hasApiKey,
              signedIn: session != null,
              emailVerified: session?.emailVerified ?? false,
            ),
            const SizedBox(height: 16),
            const _HistoryPanel(),
          ],
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.emailController,
    required this.passwordController,
    required this.registerMode,
    required this.loading,
    required this.enabled,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool registerMode;
  final bool loading;
  final bool enabled;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            registerMode ? 'Создать аккаунт' : 'Войти',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Вход')),
              ButtonSegment(value: true, label: Text('Регистрация')),
            ],
            selected: {registerMode},
            onSelectionChanged: enabled && !loading
                ? (values) => onModeChanged(values.first)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('account-email-field'),
            controller: emailController,
            enabled: enabled && !loading,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('account-password-field'),
            controller: passwordController,
            enabled: enabled && !loading,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled && !loading ? onSubmit : null,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                loading
                    ? 'Проверяем...'
                    : registerMode
                        ? 'Создать аккаунт'
                        : 'Войти через Firebase',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.session,
    required this.loading,
    required this.onSendVerification,
    required this.onSignOut,
  });

  final AuthSession session;
  final bool loading;
  final VoidCallback onSendVerification;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF5EF7C8).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF5EF7C8).withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(Icons.person, color: Color(0xFF5EF7C8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.email,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'UID: ${session.localId}',
                      style: const TextStyle(color: Colors.white60),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            'Email',
            session.emailVerified ? 'подтвержден' : 'не подтвержден',
            accent: session.emailVerified,
          ),
          const _InfoRow('Auth provider', 'Firebase Identity Toolkit'),
          _InfoRow('ID token', session.idToken.isNotEmpty ? 'получен' : 'нет'),
          _InfoRow('Сессия', '${session.expiresIn ~/ 60} мин'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading || session.emailVerified
                      ? null
                      : onSendVerification,
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Подтвердить email'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: loading ? null : onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityChecklist extends StatelessWidget {
  const _SecurityChecklist({
    required this.firebaseConfigured,
    required this.apiKeyConfigured,
    required this.signedIn,
    required this.emailVerified,
  });

  final bool firebaseConfigured;
  final bool apiKeyConfigured;
  final bool signedIn;
  final bool emailVerified;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security baseline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          _CheckItem(
            label: 'Firebase Auth key',
            done: firebaseConfigured,
            text: firebaseConfigured ? 'настроен' : 'ожидает настройки',
          ),
          _CheckItem(
            label: 'Backend API key',
            done: apiKeyConfigured,
            text:
                apiKeyConfigured ? 'настроен' : 'нужен при AUTH_REQUIRED=true',
          ),
          _CheckItem(
            label: 'User session',
            done: signedIn,
            text: signedIn ? 'активна' : 'пользователь не вошел',
          ),
          _CheckItem(
            label: 'Email verification',
            done: emailVerified,
            text: emailVerified ? 'подтвержден' : 'нужно подтвердить',
          ),
          const _CheckItem(
            label: 'KYC / AML',
            done: false,
            text: 'следующий этап после аккаунта',
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context) {
    return const _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'История переводов',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'После привязки user_id backend будет показывать здесь переводы, получателей и статусы проверок.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({
    required this.icon,
    required this.title,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFFFD36E) : const Color(0xFF5EF7C8);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: accent ? const Color(0xFF5EF7C8) : Colors.white,
                fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.done,
    required this.text,
  });

  final String label;
  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF5EF7C8) : const Color(0xFFFFD36E);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $text',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
