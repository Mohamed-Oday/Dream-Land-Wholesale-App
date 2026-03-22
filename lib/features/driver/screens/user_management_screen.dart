import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/driver/providers/user_management_provider.dart';
import 'package:tawzii/features/driver/screens/driver_performance_screen.dart';

class UserManagementScreen extends ConsumerWidget {
  final bool isOwner;

  const UserManagementScreen({super.key, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final usersAsync =
        ref.watch(isOwner ? allUsersProvider : driversOnlyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? l10n.users : l10n.drivers),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.error, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () {
                  ref.invalidate(allUsersProvider);
                  ref.invalidate(driversOnlyProvider);
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outlined,
                      size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l10n.noUsers, style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allUsersProvider);
              ref.invalidate(driversOnlyProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final name = user['name'] as String? ?? '';
                final username = user['username'] as String? ?? '';
                final role = user['role'] as String? ?? 'driver';
                final active = user['active'] as bool? ?? true;

                final isAdmin = role == 'admin';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                  onTap: role == 'driver'
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverPerformanceScreen(
                                driverId: user['id'] as String,
                                driverName: name,
                              ),
                            ),
                          )
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: isAdmin
                        ? colorScheme.tertiaryContainer
                        : colorScheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isAdmin
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Text(username,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          )),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isAdmin
                                    ? colorScheme.tertiary
                                    : colorScheme.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAdmin ? l10n.admin : l10n.driver,
                            style: TextStyle(
                              color: isAdmin
                                  ? colorScheme.tertiary
                                  : colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (active ? AppColors.success : AppColors.error)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          active ? l10n.active : l10n.inactive,
                          style: TextStyle(
                            color:
                                active ? AppColors.success : AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'deactivate') {
                            _confirmDeactivate(
                                context, ref, user['id'] as String);
                          } else if (action == 'activate') {
                            _handleActivate(
                                context, ref, user['id'] as String);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (active)
                            PopupMenuItem(
                              value: 'deactivate',
                              child: Row(
                                children: [
                                  Icon(Icons.block,
                                      size: 18, color: colorScheme.error),
                                  const SizedBox(width: 8),
                                  Text(l10n.deactivateUser),
                                ],
                              ),
                            )
                          else
                            PopupMenuItem(
                              value: 'activate',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 18, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Text(l10n.activateUser),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ));
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'driver';

    showDialog(
      context: context,
      builder: (ctx) {
        var loading = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.createUser),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwner) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        labelText: l10n.selectRole,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
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
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: nameCtrl,
                    enabled: !loading,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.error : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameCtrl,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.error;
                      if (v.trim().contains(' ')) return l10n.usernameNoSpaces;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    enabled: !loading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.error;
                      if (v.length < 6) return l10n.passwordMinLength;
                      return null;
                    },
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!,
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 13)),
                  ],
                ],
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
                          final repo = ref.read(userRepositoryProvider)!;
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
                              SnackBar(content: Text(l10n.userCreated)),
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.confirm),
              ),
            ],
          ),
        );
      },
    );

    // Controllers disposed when dialog closes (StatefulBuilder handles this)
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
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
