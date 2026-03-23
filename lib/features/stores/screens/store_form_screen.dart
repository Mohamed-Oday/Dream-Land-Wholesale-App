import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../providers/store_provider.dart';

class StoreFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? store;

  const StoreFormScreen({super.key, this.store});

  bool get isEditing => store != null;

  @override
  ConsumerState<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends ConsumerState<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _contactController;
  bool _isLoading = false;
  String? _errorMessage;
  double? _selectedLat;
  double? _selectedLng;
  LatLng _mapCenter = const LatLng(36.75, 3.06);
  bool _locationResolved = false;

  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _addressController = TextEditingController(text: s?['address'] ?? '');
    _phoneController = TextEditingController(text: s?['phone'] ?? '');
    _contactController =
        TextEditingController(text: s?['contact_person'] ?? '');
    _selectedLat = (s?['gps_lat'] as num?)?.toDouble();
    _selectedLng = (s?['gps_lng'] as num?)?.toDouble();
    if (_selectedLat != null && _selectedLng != null) {
      _mapCenter = LatLng(_selectedLat!, _selectedLng!);
      _locationResolved = true;
    } else {
      _resolveCurrentLocation();
    }
  }

  Future<void> _resolveCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _mapCenter = LatLng(pos.latitude, pos.longitude);
          _locationResolved = true;
        });
      }
    } catch (_) {
      // Fall back to Algiers default — no error needed
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(storeRepositoryProvider)!;

      if (widget.isEditing) {
        await repo.update(widget.store!['id'], {
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'contact_person': _contactController.text.trim(),
          'gps_lat': _selectedLat,
          'gps_lng': _selectedLng,
        });
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          contactPerson: _contactController.text.trim(),
          gpsLat: _selectedLat,
          gpsLng: _selectedLng,
        );
      }

      ref.invalidate(storeListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في الحفظ: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final hasMarker = _selectedLat != null && _selectedLng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل المتجر' : 'إضافة متجر'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المتجر',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'اختياري',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: 'اختياري',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'جهة الاتصال',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'اختياري',
                ),
              ),

              // --- Map Location Picker ---
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.map_outlined,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.storeLocation,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!hasMarker)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.tapToSetLocation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: hasMarker
                          ? LatLng(_selectedLat!, _selectedLng!)
                          : _mapCenter,
                      initialZoom: hasMarker || _locationResolved ? 15 : 13,
                      onTap: (_, point) {
                        if (!_isLoading) {
                          setState(() {
                            _selectedLat = point.latitude;
                            _selectedLng = point.longitude;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dreamland.tawzii',
                      ),
                      if (hasMarker)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_selectedLat!, _selectedLng!),
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.location_pin,
                                color: AppColors.error,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      const SimpleAttributionWidget(
                        source: Text('OpenStreetMap contributors'),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasMarker)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(l10n.removeLocation),
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                              _selectedLat = null;
                              _selectedLng = null;
                            }),
                  ),
                ),

              const SizedBox(height: 8),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.isEditing ? 'حفظ التعديلات' : 'إضافة المتجر',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
