import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/location/providers/location_provider.dart';

class DriverMapScreen extends ConsumerStatefulWidget {
  const DriverMapScreen({super.key});

  @override
  ConsumerState<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends ConsumerState<DriverMapScreen> {
  final MapController _mapController = MapController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(driverLocationsProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fitBounds(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) return;

    final points = locations
        .map((loc) => LatLng(
              (loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble(),
            ))
        .toList();

    if (points.length == 1) {
      _mapController.move(points.first, 14.0);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(64),
        ),
      );
    }
  }

  void _showDriverDetails(
    BuildContext context,
    Map<String, dynamic> location,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final driverName = location['driver_name'] as String? ?? '';
    final timestamp = DateTime.tryParse(location['timestamp'] as String? ?? '');
    final minutesAgo = timestamp != null
        ? DateTime.now().toUtc().difference(timestamp).inMinutes
        : 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(driverName, style: theme.textTheme.titleMedium),
          subtitle: Text(
            l10n.lastSeenAgo(minutesAgo),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.location_on,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locations = ref.watch(driverLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.map)),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(36.7, 3.0),
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dreamland.tawzii',
              ),
              // Driver markers
              locations.when(
                data: (locs) {
                  // Fit bounds on first load
                  if (locs.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fitBounds(locs);
                    });
                  }
                  return MarkerLayer(
                    markers: locs.map((loc) {
                      final lat = (loc['lat'] as num).toDouble();
                      final lng = (loc['lng'] as num).toDouble();
                      final name = loc['driver_name'] as String? ?? '';
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showDriverDetails(context, loc),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: colorScheme.primary,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const MarkerLayer(markers: []),
                error: (_, _) => const MarkerLayer(markers: []),
              ),
              // OSM attribution (required by tile usage policy)
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),

          // Empty state overlay
          locations.when(
            data: (locs) {
              if (locs.isNotEmpty) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noActiveDrivers,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.invalidate(driverLocationsProvider),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
