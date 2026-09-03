import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/numeric_keypad.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/core/utils/order_calculator.dart';
import 'package:tawzii/core/utils/package_stock.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver_loads/providers/driver_load_providers.dart';
import '../../products/providers/product_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../models/line_item.dart';
import '../providers/order_provider.dart';
import '../providers/order_sync_provider.dart';
import '../../receipts/screens/receipt_screen.dart';

/// Field-Kit create-order screen (canvas 3a + 3d).
///
/// Favorites grid in the thumb zone, searchable load-aware catalog,
/// pinned running total + one amber CTA, 56px targets. Offline is a working
/// state: failed/offline saves land in the local sync queue.
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _QueuedOrderInfo {
  const _QueuedOrderInfo({
    required this.storeName,
    required this.total,
    required this.itemCount,
  });

  final String storeName;
  final double total;
  final int itemCount;
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  String? _selectedStoreId;
  String _selectedStoreName = '';
  double? _storeBalance;
  final List<LineItem> _lineItems = [];
  final _searchController = TextEditingController();
  double _discount = 0;
  bool _isLoading = false;
  bool _isOffline = false;
  bool _saveFailed = false;
  String? _activeProductId;
  _QueuedOrderInfo? _lastQueued;
  Timer? _connectivityTimer;
  bool _checkingConnectivity = false;

  @override
  void initState() {
    super.initState();
    _loadLastStore();
    _loadDraft(); // Load draft order if exists
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Connectivity + sync-queue replay
  // ------------------------------------------------------------------

  Future<void> _checkConnectivity() async {
    if (_checkingConnectivity) return;
    _checkingConnectivity = true;
    try {
      final online = await hasNetwork();
      if (!mounted) return;
      if (online == _isOffline) {
        setState(() => _isOffline = !online);
      }
      if (online) {
        final queue = ref.read(offlineOrderQueueProvider);
        if (await queue.pendingCount() > 0) {
          final synced = await queue.processPending();
          if (!mounted) return;
          ref.invalidate(pendingOrderSyncCountProvider);
          if (synced > 0) {
            ref.invalidate(productListProvider);
            ref.invalidate(orderListProvider);
            ref.invalidate(allOrdersProvider);
            ref.invalidate(driverCurrentLoadProvider);
          }
        }
      }
    } finally {
      _checkingConnectivity = false;
    }
  }

  // ------------------------------------------------------------------
  // Store persistence (unchanged behavior)
  // ------------------------------------------------------------------

  Future<void> _loadLastStore() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStoreId = prefs.getString('last_store_id');
    final lastStoreName = prefs.getString('last_store_name');
    if (lastStoreId != null && lastStoreName != null && mounted) {
      setState(() {
        _selectedStoreId = lastStoreId;
        _selectedStoreName = lastStoreName;
      });
    }
  }

  Future<void> _saveLastStore(String storeId, String storeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_store_id', storeId);
    await prefs.setString('last_store_name', storeName);
  }

  // ------------------------------------------------------------------
  // Draft order persistence (Feature 2)
  // ------------------------------------------------------------------

  static const _draftKeys = {
    'lineItems': 'draft_order_line_items',
    'storeId': 'draft_order_store_id',
    'storeName': 'draft_order_store_name',
    'discount': 'draft_order_discount',
    'storeBalance': 'draft_order_store_balance',
    'timestamp': 'draft_order_timestamp',
  };

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final lineItemsJson = _lineItems.map((item) => {
      'productId': item.productId,
      'productName': item.productName,
      'unitPrice': item.unitPrice,
      'quantity': item.quantity,
      'unitsPerPackage': item.unitsPerPackage,
      'hasReturnablePackaging': item.hasReturnablePackaging,
      'stockOnHand': item.stockOnHand,
      'allowPiece': item.allowPiece,
      'piecesQuantity': item.piecesQuantity,
    }).toList();

    await prefs.setString(_draftKeys['lineItems']!, jsonEncode(lineItemsJson));
    // The store is deliberately not part of the draft (see _loadDraft); any
    // store keys left by older builds are dropped here.
    await prefs.remove(_draftKeys['storeId']!);
    await prefs.remove(_draftKeys['storeName']!);
    await prefs.remove(_draftKeys['storeBalance']!);
    if (_discount > 0) {
      await prefs.setDouble(_draftKeys['discount']!, _discount);
    }
    await prefs.setString(_draftKeys['timestamp']!, DateTime.now().toIso8601String());
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_draftKeys['timestamp']!);
    if (timestampStr == null) return;

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return;

    // Check if draft is older than 24 hours
    if (DateTime.now().difference(timestamp).inHours > 24) {
      await _clearDraft();
      return;
    }

    final lineItemsStr = prefs.getString(_draftKeys['lineItems']!);
    if (lineItemsStr == null || lineItemsStr.isEmpty) return;

    final List<dynamic> lineItemsJson = jsonDecode(lineItemsStr);
    if (lineItemsJson.isEmpty) return;

    // Show restore dialog
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreDraftTitle),
        content: Text(l10n.restoreDraftMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );

    if (shouldRestore != true) {
      await _clearDraft();
      return;
    }

    final lineItems = lineItemsJson.map((json) => LineItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
      unitsPerPackage: json['unitsPerPackage'] as int?,
      hasReturnablePackaging: json['hasReturnablePackaging'] as bool? ?? false,
      stockOnHand: (json['stockOnHand'] as num?)?.toDouble() ?? 0.0,
      allowPiece: (json['allowPiece'] ?? json['soldByPiece']) as bool? ?? false,
      piecesQuantity: json['piecesQuantity'] as int? ?? 0,
    )).toList();

    final discount = prefs.getDouble(_draftKeys['discount']!) ?? 0.0;

    // A restored draft brings back the lines and the discount only. The
    // store is chosen afresh every time so a draft can never be confirmed
    // against the store it happened to be started for.
    setState(() {
      _lineItems.clear();
      _lineItems.addAll(lineItems);
      _selectedStoreId = null;
      _selectedStoreName = '';
      _discount = discount;
      _storeBalance = null;
    });
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKeys['lineItems']!);
    await prefs.remove(_draftKeys['storeId']!);
    await prefs.remove(_draftKeys['storeName']!);
    await prefs.remove(_draftKeys['discount']!);
    await prefs.remove(_draftKeys['storeBalance']!);
    await prefs.remove(_draftKeys['timestamp']!);
  }

  // Call this after successful order submission
  Future<void> _clearDraftOnSubmit() async {
    await _clearDraft();
  }

  // Call _saveDraft() in _updateLine, _pickStore, _editDiscount, and on dispose

  // ------------------------------------------------------------------
  // Totals
  // ------------------------------------------------------------------

  double get _subtotal => calculateSubtotal(_lineItems);
  double get _taxPercentage => 0;
  double get _taxAmount => calculateTax(_subtotal, _taxPercentage);
  double get _discountAmount => _discount;
  double get _total => calculateTotal(_subtotal, _taxAmount, _discountAmount);
  bool get _hasDiscount => _discountAmount > 0;
  int get _itemCount => _lineItems.length;
  bool get _canSubmit =>
      _selectedStoreId != null && _lineItems.isNotEmpty && !_isLoading;

  LineItem? _findItem(String productId) {
    for (final item in _lineItems) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  int _getPackages(String productId) => _findItem(productId)?.quantity ?? 0;
  int _getPieces(String productId) => _findItem(productId)?.piecesQuantity ?? 0;

  /// True while the current build has an active driver load. Set from build.
  ///
  /// Warehouse stock never caps a sale (a product that exists in the warehouse
  /// may still read 0 in the app; the database clamps the deduction at zero).
  /// A driver's load is a physical pool, so it still caps.
  bool _hasActiveLoad = false;

  /// Upper bound for a quantity that is not capped by a load.
  static const int _kUncapped = 9999;

  /// Upsert a cart line, updating packages and/or pieces independently.
  /// Pass only the field being changed; the other is preserved.
  void _updateLine(
    String productId, {
    int? packages,
    int? pieces,
    required double maxStock,
    required Map<String, dynamic> product,
  }) {
    final allowPiece = product['sell_by_piece'] == true;
    final upkg = product['units_per_package'] as int?;
    final existing = _findItem(productId);

    var newPackages = packages ?? existing?.quantity ?? 0;
    var newPieces = pieces ?? existing?.piecesQuantity ?? 0;

    // Only a driver's load caps the sale. Stock is fractional packages: whole
    // packages are capped by the whole packages on the load; loose pieces
    // take whatever units are left over.
    if (_hasActiveLoad) {
      newPackages = newPackages.clamp(0, wholePackages(maxStock));
      final piecesCap =
          allowPiece ? loosePiecesAfter(maxStock, newPackages, upkg) : 0;
      newPieces = newPieces.clamp(0, piecesCap);
    } else {
      newPackages = newPackages.clamp(0, _kUncapped);
      newPieces = allowPiece ? newPieces.clamp(0, _kUncapped) : 0;
    }

    setState(() {
      _saveFailed = false;
      _lastQueued = null;
      if (newPackages <= 0 && newPieces <= 0) {
        _lineItems.removeWhere((item) => item.productId == productId);
        if (_activeProductId == productId) _activeProductId = null;
      } else {
        final line = LineItem(
          productId: productId,
          productName: product['name'] ?? '',
          unitPrice: (product['unit_price'] as num).toDouble(),
          quantity: newPackages,
          unitsPerPackage: upkg,
          hasReturnablePackaging: product['has_returnable_packaging'] == true,
          stockOnHand: maxStock,
          allowPiece: allowPiece,
          piecesQuantity: newPieces,
        );
        final idx =
            _lineItems.indexWhere((item) => item.productId == productId);
        if (idx >= 0) {
          _lineItems[idx] = line;
        } else {
          _lineItems.add(line);
        }
        _activeProductId = productId;
      }
    });
    _saveDraft(); // Auto-save draft after quantity change
  }

  Future<void> _editPackages(
    String productId,
    double maxStock,
    Map<String, dynamic> product,
  ) async {
    final current = _getPackages(productId);
    final v = await showKeypadSheet(
      context,
      title: 'الكمية (عبوات)',
      initialValue: current > 0 ? current.toDouble() : null,
      hardened: true,
    );
    if (v == null || !mounted) return;
    _updateLine(productId,
        packages: v.round(), maxStock: maxStock, product: product);
  }

  Future<void> _editPieces(
    String productId,
    double maxStock,
    Map<String, dynamic> product,
  ) async {
    final current = _getPieces(productId);
    final v = await showKeypadSheet(
      context,
      title: 'الكمية (قطع)',
      initialValue: current > 0 ? current.toDouble() : null,
      hardened: true,
    );
    if (v == null || !mounted) return;
    _updateLine(productId,
        pieces: v.round(), maxStock: maxStock, product: product);
  }

  Future<void> _editDiscount() async {
    final l10n = AppLocalizations.of(context)!;
    final v = await showKeypadSheet(
      context,
      title: l10n.discountAmount,
      initialValue: _discount > 0 ? _discount : null,
      allowDecimal: true,
      hardened: true,
    );
    if (v == null || !mounted) return;
    if (v < 0 || v > _subtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.discountExceedsSubtotal)),
      );
      return;
    }
    setState(() => _discount = v);
  }

  // ------------------------------------------------------------------
  // Store picker
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>?> _showStorePicker(
      BuildContext context, List<Map<String, dynamic>> stores) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? stores
                : stores.where((s) {
                    final name = (s['name'] as String? ?? '').toLowerCase();
                    return name.contains(query);
                  }).toList();

            return Padding(
              padding: EdgeInsetsDirectional.only(
                start: 12,
                end: 12,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: 4, top: 4, bottom: 8),
                    child: SectionLabel(l10n.selectStore,
                        padding: EdgeInsets.zero),
                  ),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم المتجر…',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final s = filtered[index];
                        final balance =
                            (s['credit_balance'] as num?)?.toDouble() ?? 0;
                        final address = (s['address'] ?? '').toString();
                        return TawziiRow(
                          leading: StatusDot(
                            balance > 0
                                ? StatusKind.danger
                                : StatusKind.neutral,
                          ),
                          title: s['name'] ?? '',
                          subtitle: address.isNotEmpty ? address : null,
                          trailing: Money(
                            balance,
                            tint: balance > 0
                                ? MoneyTint.danger
                                : MoneyTint.neutral,
                          ),
                          onTap: () => Navigator.pop(ctx, s),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickStore(List<Map<String, dynamic>> stores) async {
    if (_isLoading) return;
    final selected = await _showStorePicker(context, stores);
    if (selected == null || !mounted) return;
    setState(() {
      _selectedStoreId = selected['id'] as String;
      _selectedStoreName = selected['name'] ?? '';
      _storeBalance = (selected['credit_balance'] as num?)?.toDouble() ?? 0;
    });
    _saveLastStore(selected['id'] as String, selected['name'] ?? '');
    _saveDraft(); // Auto-save draft after store selection
  }

  // ------------------------------------------------------------------
  // Submit
  // ------------------------------------------------------------------

  List<Map<String, dynamic>> _buildLineItemMaps() {
    return _lineItems
        .map((item) => {
              'product_id': item.productId,
              'quantity': item.quantity,
              'pieces_quantity': item.piecesQuantity,
              'sold_by_piece': item.soldByPiece,
              'units_per_package': item.unitsPerPackage,
              'unit_price': item.packagePrice,
              'line_total': item.lineTotal,
            })
        .toList();
  }

  bool _looksLikeNetworkError(Object e) {
    final s = e.toString();
    return e is SocketException ||
        e is TimeoutException ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable');
  }

  Future<void> _confirmAndSubmit() async {
    if (!_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmOrderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmOrderMessage),
            const SizedBox(height: 16),
            _SummaryRow(label: l10n.stores, value: _selectedStoreName),
            _SummaryRow(label: l10n.items, value: '\u2066${_lineItems.length}\u2069'),
            const Divider(),
            _SummaryMoneyRow(label: l10n.total, amount: _total, bold: true),
          ],
        ),
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

    if (confirmed != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _saveFailed = false;
    });

    final lineItemMaps = _buildLineItemMaps();

    // Offline is a contract, not an error — queue directly.
    if (_isOffline) {
      await _queueOffline(lineItemMaps);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = ref.read(orderRepositoryProvider)!;

      final orderData = await repo.create(
        storeId: _selectedStoreId!,
        subtotal: _subtotal,
        taxPercentage: _taxPercentage,
        taxAmount: _taxAmount,
        discount: _discountAmount,
        discountStatus: _hasDiscount ? 'pending' : 'none',
        total: _total,
        lineItems: lineItemMaps,
      );

      if (!mounted) return;

      orderData['stores'] = {'name': _selectedStoreName};
      orderData['order_lines'] = _lineItems
          .map((item) => {
                'products': {
                  'name': item.productName,
                  'units_per_package': item.unitsPerPackage,
                  'unit_price': item.unitPrice,
                },
                'quantity': item.quantity,
                'pieces_quantity': item.piecesQuantity,
                'sold_by_piece': item.soldByPiece,
                'unit_price': item.packagePrice,
                'line_total': item.lineTotal,
              })
          .toList();

      ref.invalidate(productListProvider);
      ref.invalidate(orderListProvider);
      ref.invalidate(allOrdersProvider);
      ref.invalidate(driverCurrentLoadProvider);

      try {
        final notifService = ref.read(notificationServiceProvider);
        final userName = ref.read(currentUserProvider)?.name ?? '';
        final userBusinessId = ref.read(currentUserProvider)?.businessId ?? '';
        notifService.sendNotification(
          eventType: 'new_order',
          data: {'driver': userName, 'store': _selectedStoreName},
        );
        if (_hasDiscount) {
          notifService.sendNotification(
            eventType: 'discount_pending',
            data: {
              'driver': userName,
              'amount': _discountAmount.toStringAsFixed(2),
              'store': _selectedStoreName,
            },
          );
        }
        notifService.checkAndNotifyLowStock(
          productIds: _lineItems.map((i) => i.productId).toList(),
          businessId: userBusinessId,
        );
      } catch (e) {
        debugPrint('Order notification failed (non-blocking): $e');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen.order(orderData: orderData),
        ),
      );
    } on SocketException catch (_) {
      await _queueOffline(lineItemMaps);
    } on PostgrestException catch (e) {
      debugPrint('Order save PostgrestException: ${e.message} / ${e.details}');
      if (mounted) {
        final msg = e.message;
        if (msg.contains('permission denied') ||
            msg.contains('new row violates row-level security')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تعطيل حسابك — تواصل مع المالك'),
            ),
          );
          ref
              .read(notificationServiceProvider)
              .unregisterToken(Supabase.instance.client);
          ref.read(authServiceProvider).signOut();
          return;
        }
        setState(() => _saveFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveError}: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Order save error: $e');
      if (_looksLikeNetworkError(e)) {
        await _queueOffline(lineItemMaps);
      } else if (mounted) {
        setState(() => _saveFailed = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _queueOffline(List<Map<String, dynamic>> lineItemMaps) async {
    final queue = ref.read(offlineOrderQueueProvider);
    await queue.enqueue(
      storeId: _selectedStoreId!,
      storeName: _selectedStoreName,
      subtotal: _subtotal,
      taxPercentage: _taxPercentage,
      taxAmount: _taxAmount,
      discount: _discountAmount,
      discountStatus: _hasDiscount ? 'pending' : 'none',
      total: _total,
      lineItems: lineItemMaps,
    );
    if (!mounted) return;
    setState(() {
      _isOffline = true;
      _saveFailed = false;
      _lastQueued = _QueuedOrderInfo(
        storeName: _selectedStoreName,
        total: _total,
        itemCount: _lineItems.length,
      );
      _lineItems.clear();
      _discount = 0;
      _activeProductId = null;
    });
    ref.invalidate(pendingOrderSyncCountProvider);
  }

  Future<void> _queueCurrentAndReset() async {
    if (_lineItems.isEmpty || _selectedStoreId == null) return;
    setState(() => _isLoading = true);
    await _queueOffline(_buildLineItemMaps());
    if (mounted) setState(() => _isLoading = false);
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final storesAsync = ref.watch(storeListProvider);
    final productsAsync = ref.watch(productListProvider);
    final loadAsync = ref.watch(driverCurrentLoadProvider);
    final pendingSync =
        ref.watch(pendingOrderSyncCountProvider).valueOrNull ?? 0;

    // Resolve balance for a store restored from prefs.
    final stores = storesAsync.valueOrNull;
    double? balance = _storeBalance;
    if (balance == null && _selectedStoreId != null && stores != null) {
      for (final s in stores) {
        if (s['id'] == _selectedStoreId) {
          balance = (s['credit_balance'] as num?)?.toDouble() ?? 0;
          break;
        }
      }
    }

    // Load-aware stock: remaining per product on the active load.
    final Map<String, int> loadStock = {};
    final List<String> loadOrder = [];
    final loadData = loadAsync.valueOrNull;
    final hasActiveLoad = loadData != null;
    _hasActiveLoad = hasActiveLoad;
    if (loadData != null) {
      final items = loadData['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        final pid = m['product_id'] as String;
        final loaded = (m['quantity_loaded'] as num?)?.toInt() ?? 0;
        final sold = (m['quantity_sold'] as num?)?.toInt() ?? 0;
        loadStock[pid] = loaded - sold;
        loadOrder.add(pid);
      }
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isOffline) ...[
                      OfflineBanner(
                        hardened: true,
                        pendingCount: pendingSync > 0 ? pendingSync : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildHeader(t, l10n, stores, balance),
                    if (storesAsync.hasError) ...[
                      const SizedBox(height: 8),
                      SurfaceCard(
                        child: ErrorRetryRow(
                          onRetry: () => ref.invalidate(storeListProvider),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildSearchField(t),
                    const SizedBox(height: 14),
                    if (_saveFailed) ...[
                      _buildSaveFailedCard(t),
                      const SizedBox(height: 12),
                    ],
                    if (_lastQueued != null) ...[
                      _buildQueuedCard(t),
                      const SizedBox(height: 12),
                    ],
                    productsAsync.when(
                      loading: () =>
                          const SkeletonList(count: 6, hardened: true),
                      error: (e, _) => SurfaceCard(
                        child: ErrorRetryRow(
                          onRetry: () => ref.invalidate(productListProvider),
                        ),
                      ),
                      data: (products) => _buildCatalog(
                        t,
                        products,
                        hasActiveLoad: hasActiveLoad,
                        loadStock: loadStock,
                        loadOrder: loadOrder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(t),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Header
  // ------------------------------------------------------------------

  Widget _buildHeader(
    TawziiTokens t,
    AppLocalizations l10n,
    List<Map<String, dynamic>>? stores,
    double? balance,
  ) {
    return Row(
      children: [
        _SquareIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: stores == null ? null : () => _pickStore(stores),
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedStoreName.isEmpty
                      ? l10n.selectStore
                      : _selectedStoreName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: t.textPrimary,
                  ),
                ),
                if (_selectedStoreId != null && balance != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الرصيد: ',
                        style:
                            TextStyle(fontSize: 12, color: t.textSecondary),
                      ),
                      Money(
                        balance,
                        tint: balance > 0
                            ? MoneyTint.danger
                            : MoneyTint.neutral,
                        numberStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'اضغط لاختيار المتجر',
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (stores != null)
          TextButton(
            onPressed: _isLoading ? null : () => _pickStore(stores),
            child: const Text('تغيير', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSearchField(TawziiTokens t) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        enabled: !_isLoading,
        style: TextStyle(fontSize: 16, color: t.textPrimary),
        decoration: InputDecoration(
          hintText: 'ابحث في الكتالوج…',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: 14, vertical: 14),
          suffixIcon: _searchController.text.isEmpty
              ? Icon(Icons.search, color: t.textMuted)
              : IconButton(
                  icon: Icon(Icons.close, color: t.textMuted),
                  onPressed: () => setState(_searchController.clear),
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 3d state cards
  // ------------------------------------------------------------------

  Widget _buildQueuedCard(TawziiTokens t) {
    final q = _lastQueued!;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطلب — ${q.storeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.textPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'حُفظ الآن · ',
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                    Money(
                      q.total,
                      numberStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const UnsyncedBadge(hardened: true),
        ],
      ),
    );
  }

  Widget _buildSaveFailedCard(TawziiTokens t) {
    // Neutral — danger is reserved for debt (canvas 3d).
    return SurfaceCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فشل حفظ الطلب',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'لن تفقد شيئاً — الطلب ما زال محفوظاً هنا. أعد المحاولة أو '
            'أضفه لقائمة الانتظار ليُرسل تلقائياً',
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _isLoading ? null : _submit,
                style: TextButton.styleFrom(
                  backgroundColor: t.surfaceAlt,
                  foregroundColor: t.textPrimary,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('إعادة المحاولة الآن'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isLoading ? null : _queueCurrentAndReset,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('حفظ للمزامنة لاحقاً'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Catalog: cart card + favorites grid (or search results)
  // ------------------------------------------------------------------

  /// Available stock in PACKAGES. Warehouse stock is fractional (loose pieces
  /// consume part of a package); a driver's load is always whole packages.
  ({double available, bool notInLoad}) _availability(
    Map<String, dynamic> p, {
    required bool hasActiveLoad,
    required Map<String, int> loadStock,
  }) {
    final productId = p['id'] as String;
    if (hasActiveLoad) {
      final loadRemaining = loadStock[productId];
      if (loadRemaining == null) {
        return (available: 0.0, notInLoad: true);
      }
      return (available: loadRemaining.toDouble(), notInLoad: false);
    }
    return (available: stockOf(p), notInLoad: false);
  }

  /// Nothing sellable left — no whole package, and no loose piece this product
  /// is allowed to sell.
  bool _isDepleted(Map<String, dynamic> p, double available) {
    final upp = (p['units_per_package'] as num?)?.toInt();
    return p['sell_by_piece'] == true
        ? isOutOfStock(available, upp)
        : wholePackages(available) <= 0;
  }

  Widget _buildCatalog(
    TawziiTokens t,
    List<Map<String, dynamic>> products, {
    required bool hasActiveLoad,
    required Map<String, int> loadStock,
    required List<String> loadOrder,
  }) {
    if (products.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return EmptyState(
        title: l10n.noData,
        message: 'أضف منتجات من حساب المالك أولاً',
      );
    }

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      final results = products
          .where((p) => (p['name'] as String? ?? '').contains(query))
          .toList();
      if (results.isEmpty) {
        return const EmptyState(
          title: 'لا نتائج',
          message: 'جرّب اسماً آخر أو تحقق من الإملاء',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < results.length; i++) ...[
            _buildCatalogRow(t, results[i],
                hasActiveLoad: hasActiveLoad, loadStock: loadStock),
            if (i < results.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    // The whole catalog. With an active load, the loaded products come first
    // (most recently loaded at the top), then everything else.
    final byId = {for (final p in products) p['id'] as String: p};
    final favs = <Map<String, dynamic>>[];
    if (hasActiveLoad) {
      for (final pid in loadOrder) {
        final p = byId[pid];
        if (p != null) favs.add(p);
      }
    }
    final loaded = {for (final p in favs) p['id'] as String};
    favs.addAll(products.where((p) => !loaded.contains(p['id'] as String)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lineItems.isNotEmpty) ...[
          _buildCartCard(t, byId,
              hasActiveLoad: hasActiveLoad, loadStock: loadStock),
          const SizedBox(height: 8),
          _buildDiscountRow(t),
          const SizedBox(height: 8),
        ],
        const SectionLabel('الكتالوج'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 88,
            crossAxisSpacing: 8,
            mainAxisSpacing: 14,
          ),
          itemCount: favs.length,
          itemBuilder: (context, index) => _buildFavoriteCell(t, favs[index],
              hasActiveLoad: hasActiveLoad, loadStock: loadStock),
        ),
      ],
    );
  }

  Widget _buildCartCard(
    TawziiTokens t,
    Map<String, Map<String, dynamic>> byId, {
    required bool hasActiveLoad,
    required Map<String, int> loadStock,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(
          color: isLight ? t.borderStrong : t.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _lineItems.length; i++) ...[
            _buildCartRow(t, _lineItems[i], byId,
                hasActiveLoad: hasActiveLoad, loadStock: loadStock),
            if (i < _lineItems.length - 1)
              Divider(height: 1, thickness: 1, color: t.surfaceAlt),
          ],
        ],
      ),
    );
  }

  Widget _buildCartRow(
    TawziiTokens t,
    LineItem item,
    Map<String, Map<String, dynamic>> byId, {
    required bool hasActiveLoad,
    required Map<String, int> loadStock,
  }) {
    final product = byId[item.productId];
    final isActive = _activeProductId == item.productId;
    final avail = product == null
        ? (available: item.stockOnHand, notInLoad: false)
        : _availability(product,
            hasActiveLoad: hasActiveLoad, loadStock: loadStock);
    // The load pool is not yet reduced by this uncommitted cart, so the
    // pool itself is the cap. Warehouse stock does not cap (see _updateLine).
    final maxQty = avail.available;
    final maxPackages = hasActiveLoad ? wholePackages(maxQty) : _kUncapped;
    // Loose pieces draw from the units left after the whole packages on load.
    final piecesMax = !item.allowPiece
        ? 0
        : hasActiveLoad
            ? loosePiecesAfter(maxQty, item.quantity, item.unitsPerPackage)
            : _kUncapped;

    return InkWell(
      onTap: _isLoading
          ? null
          : () => setState(() =>
              _activeProductId = isActive ? null : item.productId),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    _lineSummary(item),
                    style: TextStyle(
                      fontSize: 12,
                      color: t.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isActive && product != null)
              (item.allowPiece
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStepperRow(
                          t,
                          label: 'عبوات',
                          value: item.quantity,
                          maxValue: maxPackages,
                          onSet: (v) => _updateLine(item.productId,
                              packages: v, maxStock: maxQty, product: product),
                          onEdit: () =>
                              _editPackages(item.productId, maxQty, product),
                        ),
                        const SizedBox(height: 6),
                        _buildStepperRow(
                          t,
                          label: 'قطع',
                          value: item.piecesQuantity,
                          maxValue: piecesMax,
                          onSet: (v) => _updateLine(item.productId,
                              pieces: v, maxStock: maxQty, product: product),
                          onEdit: () =>
                              _editPieces(item.productId, maxQty, product),
                        ),
                      ],
                    )
                  : _buildStepper(
                      t,
                      value: item.quantity,
                      maxValue: maxPackages,
                      onSet: (v) => _updateLine(item.productId,
                          packages: v, maxStock: maxQty, product: product),
                      onEdit: () =>
                          _editPackages(item.productId, maxQty, product),
                    ))
            else
              Money(
                item.lineTotal,
                numberStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _iso(Object v) =>
      '${String.fromCharCode(0x2066)}$v${String.fromCharCode(0x2069)}';

  String _lineSummary(LineItem item) {
    final parts = <String>[];
    if (item.quantity > 0) {
      parts.add('${_iso(item.quantity)} عبوة');
    }
    if (item.piecesQuantity > 0) {
      parts.add('${_iso(item.piecesQuantity)} قطعة');
    }
    return parts.join(' + ');
  }

  Widget _buildStepperRow(
    TawziiTokens t, {
    required String label,
    required int value,
    required int maxValue,
    required void Function(int) onSet,
    VoidCallback? onEdit,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _buildStepper(t,
            value: value, maxValue: maxValue, onSet: onSet, onEdit: onEdit),
      ],
    );
  }

  Widget _buildStepper(
    TawziiTokens t, {
    required int value,
    required int maxValue,
    required void Function(int) onSet,
    VoidCallback? onEdit,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(
          icon: Icons.remove,
          enabled: !_isLoading && value > 0,
          onTap: () => onSet(value - 1),
          onLongPress: () => onSet(value - 5),
        ),
        InkWell(
          onTap: _isLoading ? null : onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 4, vertical: 10),
            alignment: Alignment.center,
            child: Text(
              _iso(value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        _SquareIconButton(
          icon: Icons.add,
          filled: true,
          enabled: !_isLoading && value < maxValue,
          onTap: () => onSet(value + 1),
          onLongPress: () => onSet(value + 5),
        ),
      ],
    );
  }

  Widget _buildDiscountRow(TawziiTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: _isLoading ? null : _editDiscount,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text(_hasDiscount ? l10n.discount : l10n.discountAmount),
            ),
            const Spacer(),
            if (_hasDiscount)
              Money(-_discountAmount, tint: MoneyTint.warning),
          ],
        ),
        if (_hasDiscount)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Text(
              l10n.requiresOwnerApproval,
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildCatalogRow(
    TawziiTokens t,
    Map<String, dynamic> p, {
    required bool hasActiveLoad,
    required Map<String, int> loadStock,
  }) {
    final productId = p['id'] as String;
    final avail = _availability(p,
        hasActiveLoad: hasActiveLoad, loadStock: loadStock);
    final qty = _getPackages(productId);
    final maxQty = avail.available;
    // Depleted warehouse stock only labels the card ("نفذ"); it never blocks
    // the sale. A product missing from the driver's load still does.
    final isDisabled = avail.notInLoad;
    final price = (p['unit_price'] as num).toDouble();
    final upkg = p['units_per_package'] as int?;
    final packagePrice = upkg != null ? price * upkg : price;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(
            color: isLight ? t.borderStrong : t.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: isDisabled || _isLoading
                    ? null
                    : () => _updateLine(productId, packages: qty + 1, maxStock: maxQty, product: p),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: t.textPrimary,
                      ),
                    ),
                    _buildStockLine(t, packagePrice,
                        depleted: _isDepleted(p, maxQty),
                        notInLoad: avail.notInLoad,
                        available: avail.available),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!isDisabled)
              _buildStepper(
                t,
                value: qty,
                maxValue: wholePackages(maxQty),
                onSet: (v) => _updateLine(productId,
                    packages: v, maxStock: maxQty, product: p),
                onEdit: () => _editPackages(productId, maxQty, p),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockLine(
    TawziiTokens t,
    double packagePrice, {
    required bool depleted,
    required bool notInLoad,
    required double available,
  }) {
    final String suffix;
    final Color suffixColor;
    if (notInLoad) {
      suffix = 'غير محمّل';
      suffixColor = t.textMuted;
    } else if (depleted) {
      suffix = 'نفذ';
      suffixColor = t.danger;
    } else {
      suffix = '';
      suffixColor = t.textSecondary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Money(
          packagePrice,
          numberStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
          ),
        ),
        if (suffix.isNotEmpty)
          Text(
            ' · $suffix',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: suffixColor,
            ),
          )
        else ...[
          Text(
            ' · متبقي ',
            style: TextStyle(fontSize: 12, color: t.textSecondary),
          ),
          Text(
            '\u2066${formatStockNumber(available)}\u2069',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: available <= 3 ? t.warning : t.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFavoriteCell(
    TawziiTokens t,
    Map<String, dynamic> p, {
    required bool hasActiveLoad,
    required Map<String, int> loadStock,
  }) {
    final productId = p['id'] as String;
    final avail = _availability(p,
        hasActiveLoad: hasActiveLoad, loadStock: loadStock);
    final qty = _getPackages(productId);
    final maxQty = avail.available;
    // Depleted warehouse stock only labels the card ("نفذ"); it never blocks
    // the sale. A product missing from the driver's load still does.
    final isDisabled = avail.notInLoad;
    final inCart = _findItem(productId) != null;
    final price = (p['unit_price'] as num).toDouble();
    final upkg = p['units_per_package'] as int?;
    final packagePrice = upkg != null ? price * upkg : price;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selectedBorder = isLight ? t.accentHover : t.accent;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1,
            child: Material(
              color: t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: inCart
                      ? selectedBorder
                      : (isLight ? t.borderStrong : t.border),
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: isDisabled || _isLoading
                    ? null
                    : () => _updateLine(productId, packages: qty + 1, maxStock: maxQty, product: p),
                onLongPress: isDisabled || _isLoading
                    ? null
                    : () => _editPackages(productId, maxQty, p),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 13, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _buildStockLine(t, packagePrice,
                          depleted: _isDepleted(p, maxQty),
                          notInLoad: avail.notInLoad,
                          available: avail.available),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (inCart)
          PositionedDirectional(
            top: -9,
            end: 12,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding:
                  const EdgeInsetsDirectional.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _iso(qty > 0 ? qty : _getPieces(productId)),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.onAccent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Pinned bottom bar — running total + the one amber CTA
  // ------------------------------------------------------------------

  Widget _buildBottomBar(TawziiTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.borderStrong, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _canSubmit ? _confirmAndSubmit : null,
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
                            'تأكيد الطلب (${_iso(_itemCount)})',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الإجمالي',
                    style: TextStyle(fontSize: 11, color: t.textSecondary),
                  ),
                  Money(
                    _total,
                    numberStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 48px square Field-Kit button: outlined 2px borderStrong, or amber-filled.
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    this.onTap,
    this.onLongPress,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final Color bg;
    final Color fg;
    if (!enabled) {
      bg = filled ? t.surfaceAlt : t.surface;
      fg = t.disabledFg;
    } else if (filled) {
      bg = t.accent;
      fg = t.onAccent;
    } else {
      bg = t.surface;
      fg = t.textSecondary;
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: filled && enabled
            ? BorderSide.none
            : BorderSide(color: t.borderStrong, width: 2),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _SummaryMoneyRow extends StatelessWidget {
  const _SummaryMoneyRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Money(
            amount,
            decimals: true,
            numberStyle: bold
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
        ],
      ),
    );
  }
}
