import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/store_provider.dart';
import 'store_detail_screen.dart';
import 'store_form_screen.dart';

class StoreListScreen extends ConsumerWidget {
  const StoreListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storeListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('المتاجر')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreFormScreen()),
          );
          ref.invalidate(storeListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: storesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('خطأ في تحميل المتاجر', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(storeListProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('لا توجد متاجر', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('اضغط + لإضافة متجر جديد',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(storeListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final s = stores[index];
                final balance = (s['credit_balance'] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.store,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(s['name'] ?? ''),
                  subtitle: Text(
                    [
                      if ((s['address'] ?? '').toString().isNotEmpty) s['address'],
                      if ((s['phone'] ?? '').toString().isNotEmpty) s['phone'],
                    ].join(' · '),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${balance.toStringAsFixed(2)} د.ج',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: balance > 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                      Text('الرصيد', style: theme.textTheme.labelSmall),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreDetailScreen(
                            storeId: s['id'] as String),
                      ),
                    );
                  },
                ));
              },
            ),
          );
        },
      ),
    );
  }
}
