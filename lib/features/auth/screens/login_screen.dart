import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Login screen (canvas 7a): wordmark, quiet labels above fields, one amber
/// action, neutral auth error.
///
/// First run (no users in the database) is the SAME screen in owner-setup
/// mode ([ownerSetup] = true): extra name + confirm-password fields and the
/// CTA becomes "إنشاء حساب المالك". This absorbs the old InitScreen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.ownerSetup = false});

  /// When true the screen creates the first owner account instead of
  /// signing in.
  final bool ownerSetup;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Login throttle (login mode only)
  int _failedAttempts = 0;
  bool _isThrottled = false;
  int _throttleSeconds = 0;
  Timer? _throttleTimer;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _throttleTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (widget.ownerSetup) {
      await _handleSetup();
    } else {
      await _handleLogin();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading || _isThrottled) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      // Success — GoRouter redirect handles navigation
      _failedAttempts = 0;
    } on AuthException catch (e) {
      _failedAttempts++;
      debugPrint('Auth error: ${e.message} (${e.statusCode})');
      if (mounted) {
        setState(() {
          _errorMessage = 'بيانات الدخول غير صحيحة — تأكد من الاسم وكلمة المرور';
          _passwordController.clear();
        });
      }

      // Throttle after 3 failures
      if (_failedAttempts >= 3) {
        _startThrottle();
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في الاتصال';
          _passwordController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final businessId = const Uuid().v4();
      final username = _usernameController.text.trim();
      final name = _nameController.text.trim();

      // 1. Create auth user via Supabase Auth signUp
      final authResponse = await client.auth.signUp(
        email: '$username@tawzii.local',
        password: _passwordController.text,
        data: {
          'role': 'owner',
          'business_id': businessId,
          'name': name,
          'username': username,
        },
      );

      if (authResponse.user == null) {
        throw Exception('فشل إنشاء الحساب');
      }

      // 2. Insert into public.users table (user is now authenticated)
      await client.from('users').insert({
        'id': authResponse.user!.id,
        'business_id': businessId,
        'name': name,
        'username': username,
        'role': 'owner',
        'password_hash': '',
      });

      // Success — GoRouter redirect will handle navigation
    } on AuthException catch (e) {
      debugPrint('Auth setup error: ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل إنشاء الحساب — اسم المستخدم قد يكون مستخدماً';
        });
      }
    } catch (e) {
      debugPrint('Setup error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء الإعداد. تأكد من الاتصال بالإنترنت.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startThrottle() {
    _throttleSeconds = 30;
    _isThrottled = true;
    _throttleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _throttleSeconds--;
        if (_throttleSeconds <= 0) {
          _isThrottled = false;
          _failedAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  Widget _fieldLabel(BuildContext context, String text) {
    final t = TawziiTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.textSecondary,
        ),
      ),
    );
  }

  Widget _neutralNotice(BuildContext context, String text) {
    final t = TawziiTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: t.textSecondary, height: 1.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final isSetup = widget.ownerSetup;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 64, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Wordmark
                      Text(
                        'دريم لاند',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        'توزيع المواد الغذائية بالجملة',
                        style:
                            TextStyle(fontSize: 13, color: t.textSecondary),
                      ),
                      const SizedBox(height: 44),

                      if (isSetup) ...[
                        Text(
                          'إعداد الحساب الأول',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'لا يوجد مستخدمون بعد — أنشئ حساب المالك للبدء.',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.textSecondary,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel(context, 'الاسم الكامل'),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Username
                      _fieldLabel(context, 'اسم المستخدم'),
                      TextFormField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        textDirection: TextDirection.ltr,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال اسم المستخدم';
                          }
                          if (isSetup && value.trim().contains(' ')) {
                            return 'لا يمكن أن يحتوي على مسافات';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Password
                      _fieldLabel(context, 'كلمة المرور'),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: isSetup
                            ? TextInputAction.next
                            : TextInputAction.done,
                        textDirection: TextDirection.ltr,
                        onFieldSubmitted:
                            isSetup ? null : (_) => _handleSubmit(),
                        decoration: InputDecoration(
                          suffixIcon: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                            child: Text(
                              _obscurePassword ? 'إظهار' : 'إخفاء',
                              style: TextStyle(
                                fontSize: 12,
                                color: t.textMuted,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال كلمة المرور';
                          }
                          if (isSetup && value.length < 6) {
                            return 'كلمة المرور قصيرة جداً (6 أحرف على الأقل)';
                          }
                          return null;
                        },
                      ),

                      if (isSetup) ...[
                        const SizedBox(height: 12),
                        _fieldLabel(context, 'تأكيد كلمة المرور'),
                        TextFormField(
                          controller: _confirmPasswordController,
                          enabled: !_isLoading,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          textDirection: TextDirection.ltr,
                          onFieldSubmitted: (_) => _handleSubmit(),
                          decoration: InputDecoration(
                            suffixIcon: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() =>
                                      _obscureConfirm = !_obscureConfirm),
                              child: Text(
                                _obscureConfirm ? 'إظهار' : 'إخفاء',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.textMuted,
                                ),
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'كلمتا المرور غير متطابقتين';
                            }
                            return null;
                          },
                        ),
                      ],

                      // Neutral auth error — danger is reserved for debt
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _neutralNotice(context, _errorMessage!),
                      ],

                      // Throttle notice (neutral as well)
                      if (_isThrottled) ...[
                        const SizedBox(height: 12),
                        _neutralNotice(
                          context,
                          'محاولات كثيرة. انتظر $_throttleSeconds ثانية',
                        ),
                      ],

                      const SizedBox(height: 12),

                      // One amber action, ink text
                      FilledButton(
                        onPressed: (_isLoading || _isThrottled)
                            ? null
                            : _handleSubmit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: t.onAccent,
                                ),
                              )
                            : Text(
                                isSetup
                                    ? 'إنشاء حساب المالك'
                                    : 'تسجيل الدخول',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Version footer
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'v${AppConstants.appVersion}',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 11,
                  color: t.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
