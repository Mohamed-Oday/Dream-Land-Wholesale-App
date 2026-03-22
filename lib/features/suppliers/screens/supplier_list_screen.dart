import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../providers/supplier_provider.dart';
import 'supplier_form_screen.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final suppliersAsync = ref.watch(supplierListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.suppliers)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SupplierFormScreen(),
            ),
          );
          ref.invalidate(supplierListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.error, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(supplierListProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l10n.noSuppliers,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط + لإضافة مورد جديد',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(supplierListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  .copyWith(bottom: 80),
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final s = suppliers[index];
                final phone = s['phone'] as String? ?? '';
                final contact = s['contact_person'] as String? ?? '';
                final subtitle = [
                  if (phone.isNotEmpty) phone,
                  if (contact.isNotEmpty) contact,
                ].join(' · ');

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.local_shipping,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(s['name'] ?? ''),
                    subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierFormScreen(supplier: s),
                        ),
                      );
                      ref.invalidate(supplierListProvider);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
