import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/driver/providers/user_management_provider.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/payments/providers/payment_provider.dart';

/// Users screen (canvas 7d): status-dot list, performance as the drill-in.
///
/// Owner sees all non-owner users; admin manages drivers only. Tapping a
/// driver opens the merged performance detail (absorbs the old
/// DriverPerformanceScreen).
class UserManagementScreen extends ConsumerWidget {
  final bool isOwner;

  const UserManagementScreen({super.key, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    final usersAsync =
        ref.watch(isOwner ? allUsersProvider : driversOnlyProvider);

    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 96),
          children: [
            Text(
              isOwner ? l10n.users : l10n.drivers,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            usersAsync.when(
              loading: () =>
                  const SurfaceCard(child: SkeletonList(count: 6)),
              error: (e, _) => ErrorRetryRow(
                onRetry: () {
                  ref.invalidate(allUsersProvider);
                  ref.invalidate(driversOnlyProvider);
                },
              ),
              data: (users) {
                if (users.isEmpty) {
                  return EmptyState(
                    title: l10n.noUsers,
                    message: 'أضف مستخدماً جديداً ليظهر في القائمة',
                    ctaLabel: l10n.createUser,
                    onCta: () => _showCreateDialog(context, ref),
                  );
                }

                return SurfaceCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < users.length; i++)
                        _buildUserRow(
                          context,
                          ref,
                          t,
                          l10n,
                          users[i],
                          showDivider: i < users.length - 1,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(
    BuildContext context,
    WidgetRef ref,
    TawziiTokens t,
    AppLocalizations l10n,
    Map<String, dynamic> user, {
    required bool showDivider,
  }) {
    final name = user['name'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final role = user['role'] as String? ?? 'driver';
    final active = user['active'] as bool? ?? true;
    final isDriverRole = role == 'driver';
    final roleLabel = isDriverRole ? l10n.driver : l10n.admin;

    final row = TawziiRow(
      leading: StatusDot(active ? StatusKind.success : StatusKind.neutral),
      title: name,
      subtitle: isOwner ? '$roleLabel · $username' : username,
      showDivider: showDivider,
      onTap: isDriverRole
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _UserPerformanceScreen(
                    userId: user['id'] as String,
                    name: name,
                    roleLabel: roleLabel,
                    active: active,
                  ),
                ),
              )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active)
            StatusPill(label: l10n.inactive, kind: StatusKind.neutral),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: t.textMuted),
            onSelected: (action) {
              if (action == 'deactivate') {
                _confirmDeactivate(context, ref, user['id'] as String);
              } else if (action == 'activate') {
                _handleActivate(context, ref, user['id'] as String);
              }
            },
            itemBuilder: (ctx) => [
              if (active)
                PopupMenuItem(
                  value: 'deactivate',
                  child: Text(
                    l10n.deactivateUser,
                    style: TextStyle(color: t.danger),
                  ),
                )
              else
                PopupMenuItem(
                  value: 'activate',
                  child: Text(l10n.activateUser),
                ),
            ],
          ),
          if (isDriverRole)
            Text('‹', style: TextStyle(fontSize: 12, color: t.textMuted)),
        ],
      ),
    );

    if (active) return row;
    return Opacity(opacity: 0.5, child: row);
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'driver';

    Widget fieldLabel(BuildContext ctx, String text) {
      final t = TawziiTokens.of(ctx);
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 5, top: 12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        var loading = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final t = TawziiTokens.of(ctx);
            return AlertDialog(
              title: Text(l10n.createUser),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isOwner) ...[
                        fieldLabel(ctx, l10n.selectRole),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          items: [
                            DropdownMenuItem(
                              value: 'driver',
                              child: Text(l10n.driver),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text(l10n.admin),
                            ),
                          ],
                          onChanged: loading
                              ? null
                              : (v) => setDialogState(
                                  () => selectedRole = v ?? 'driver'),
                        ),
                      ],
                      fieldLabel(ctx, 'الاسم'),
                      TextFormField(
                        controller: nameCtrl,
                        enabled: !loading,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.error
                            : null,
                      ),
                      fieldLabel(ctx, l10n.username),
                      TextFormField(
                        controller: usernameCtrl,
                        enabled: !loading,
                        textDirection: TextDirection.ltr,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n.error;
                          }
                          if (v.trim().contains(' ')) {
                            return l10n.usernameNoSpaces;
                          }
                          return null;
                        },
                      ),
                      fieldLabel(ctx, l10n.password),
                      TextFormField(
                        controller: passwordCtrl,
                        enabled: !loading,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        validator: (v) {
                          if (v == null || v.isEmpty) return l10n.error;
                          if (v.length < 6) return l10n.passwordMinLength;
                          return null;
                        },
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMsg!,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            loading = true;
                            errorMsg = null;
                          });
                          try {
                            final repo =
                                ref.read(userRepositoryProvider)!;
                            await repo.createUser(
                              name: nameCtrl.text.trim(),
                              username: usernameCtrl.text.trim(),
                              password: passwordCtrl.text,
                              role: isOwner ? selectedRole : 'driver',
                            );
                            ref.invalidate(allUsersProvider);
                            ref.invalidate(driversOnlyProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(l10n.userCreated)),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMsg = '$e';
                              loading = false;
                            });
                          }
                        },
                  child: loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.onAccent,
                          ),
                        )
                      : Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeactivate(
      BuildContext context, WidgetRef ref, String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deactivateUser),
        content: Text(l10n.confirmDeactivate),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(userRepositoryProvider)!.deactivate(userId);
      ref.invalidate(allUsersProvider);
      ref.invalidate(driversOnlyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deactivateUser)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _handleActivate(
      BuildContext context, WidgetRef ref, String userId) async {
    try {
      await ref.read(userRepositoryProvider)!.activate(userId);
      ref.invalidate(allUsersProvider);
      ref.invalidate(driversOnlyProvider);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.activateUser)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Performance drill-in (canvas 7d, right mock) — absorbed driver performance
// ---------------------------------------------------------------------------

enum _Period { today, week, month }

class _UserPerformanceScreen extends ConsumerStatefulWidget {
  final String userId;
  final String name;
  final String roleLabel;
  final bool active;

  const _UserPerformanceScreen({
    required this.userId,
    required this.name,
    required this.roleLabel,
    required this.active,
  });

  @override
  ConsumerState<_UserPerformanceScreen> createState() =>
      _UserPerformanceScreenState();
}

class _UserPerformanceScreenState
    extends ConsumerState<_UserPerformanceScreen> {
  late Future<List<List<Map<String, dynamic>>>> _future;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<List<Map<String, dynamic>>>> _load() {
    final orderRepo = ref.read(orderRepositoryProvider);
    final paymentRepo = ref.read(paymentRepositoryProvider);
    return Future.wait([
      orderRepo?.getAll(driverId: widget.userId) ??
          Future.value(<Map<String, dynamic>>[]),
      paymentRepo?.getAll(driverId: widget.userId) ??
          Future.value(<Map<String, dynamic>>[]),
    ]);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  bool _inPeriod(String createdAt) {
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return false;
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      case _Period.week:
        return now.difference(dt).inDays < 7;
      case _Period.month:
        return now.difference(dt).inDays < 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: Text(l10n.driverPerformance)),
      body: SafeArea(
        child: FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
                children: [
                  _buildHeader(t),
                  const SizedBox(height: 16),
                  const SurfaceCard(child: SkeletonList(count: 5)),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
                children: [
                  _buildHeader(t),
                  const SizedBox(height: 16),
                  ErrorRetryRow(onRetry: _retry),
                ],
              );
            }

            final allOrders = snapshot.data?[0] ?? [];
            final allPayments = snapshot.data?[1] ?? [];

            final orders = allOrders
                .where((o) => _inPeriod(o['created_at'] as String? ?? ''))
                .toList();
            final payments = allPayments
                .where((p) => _inPeriod(p['created_at'] as String? ?? ''))
                .toList();

            final orderCount = orders.length;
            double orderTotal = 0;
            for (final o in orders) {
              orderTotal += (o['total'] as num?)?.toDouble() ?? 0;
            }
            double paymentTotal = 0;
            for (final p in payments) {
              paymentTotal += (p['amount'] as num?)?.toDouble() ?? 0;
            }
            final avgOrder = orderCount == 0 ? 0.0 : orderTotal / orderCount;

            // Interleave orders + payments by created_at, descending
            final activities = <_ActivityItem>[];
            for (final o in allOrders) {
              final store = o['stores'] as Map<String, dynamic>?;
              activities.add(_ActivityItem(
                type: _ActivityType.order,
                storeName: store?['name'] as String? ?? '',
                amount: (o['total'] as num?)?.toDouble() ?? 0,
                createdAt: o['created_at'] as String? ?? '',
              ));
            }
            for (final p in allPayments) {
              final store = p['stores'] as Map<String, dynamic>?;
              activities.add(_ActivityItem(
                type: _ActivityType.payment,
                storeName: store?['name'] as String? ?? '',
                amount: (p['amount'] as num?)?.toDouble() ?? 0,
                createdAt: p['created_at'] as String? ?? '',
              ));
            }
            activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final recent = activities.take(20).toList();

            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
              children: [
                _buildHeader(t),
                const SizedBox(height: 16),
                _buildPeriodPicker(t),
                const SizedBox(height: 16),

                // Hero: total sales for the period
                Text('إجمالي المبيعات',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Money(orderTotal, size: MoneySize.hero),
                const SizedBox(height: 10),
                // Borderless stat row
                Row(
                  children: [
                    _stat(t, 'طلبات',
                        Text(
                          '$orderCount',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        )),
                    const SizedBox(width: 18),
                    _stat(
                        t,
                        'محصّل',
                        Money(paymentTotal,
                            tint: MoneyTint.success, showUnit: false)),
                    const SizedBox(width: 18),
                    _stat(t, 'متوسط الطلب',
                        Money(avgOrder, showUnit: false)),
                  ],
                ),
                const SizedBox(height: 20),

                // Recent activity (all-time, latest 20)
                const SectionLabel('النشاط الأخير'),
                if (recent.isEmpty)
                  EmptyState(
                    title: l10n.noActivity,
                    message: 'يظهر هنا آخر الطلبات والدفعات',
                  )
                else
                  SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < recent.length; i++)
                          _buildActivityRow(
                            t,
                            recent[i],
                            showDivider: i < recent.length - 1,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Session action: deactivate / activate
                OutlinedButton(
                  onPressed: () => _toggleActive(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        widget.active ? t.danger : t.textPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(widget.active
                      ? l10n.deactivateUser
                      : l10n.activateUser),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(TawziiTokens t) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              Text(
                widget.roleLabel,
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
            ],
          ),
        ),
        StatusDot(
          widget.active ? StatusKind.success : StatusKind.neutral,
        ),
      ],
    );
  }

  Widget _buildPeriodPicker(TawziiTokens t) {
    Widget option(String label, _Period value) {
      final selected = _period == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _period = value),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? t.surface : null,
              borderRadius: BorderRadius.circular(999),
              border: selected ? Border.all(color: t.border) : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? t.textPrimary : t.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          option('اليوم', _Period.today),
          const SizedBox(width: 4),
          option('الأسبوع', _Period.week),
          const SizedBox(width: 4),
          option('الشهر', _Period.month),
        ],
      ),
    );
  }

  Widget _stat(TawziiTokens t, String label, Widget value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: t.textSecondary)),
        const SizedBox(width: 5),
        value,
      ],
    );
  }

  Widget _buildActivityRow(
    TawziiTokens t,
    _ActivityItem item, {
    required bool showDivider,
  }) {
    final isOrder = item.type == _ActivityType.order;
    String formattedDate = '';
    try {
      final dt = DateTime.parse(item.createdAt).toLocal();
      formattedDate = DateFormat('dd/MM HH:mm').format(dt);
    } catch (_) {
      formattedDate = item.createdAt;
    }

    return TawziiRow(
      leading:
          StatusDot(isOrder ? StatusKind.neutral : StatusKind.success),
      title: isOrder ? 'طلب — ${item.storeName}' : 'دفعة — ${item.storeName}',
      subtitle: '\u2066$formattedDate\u2069',
      showDivider: showDivider,
      trailing: Money(
        item.amount,
        tint: isOrder ? MoneyTint.neutral : MoneyTint.success,
        showUnit: false,
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    if (widget.active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deactivateUser),
          content: Text(l10n.confirmDeactivate),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      final repo = ref.read(userRepositoryProvider)!;
      if (widget.active) {
        await repo.deactivate(widget.userId);
      } else {
        await repo.activate(widget.userId);
      }
      ref.invalidate(allUsersProvider);
      ref.invalidate(driversOnlyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                widget.active ? l10n.deactivateUser : l10n.activateUser),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }
}

enum _ActivityType { order, payment }

class _ActivityItem {
  final _ActivityType type;
  final String storeName;
  final double amount;
  final String createdAt;

  const _ActivityItem({
    required this.type,
    required this.storeName,
    required this.amount,
    required this.createdAt,
  });
}
