import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/features/location/providers/location_provider.dart';

/// Live driver map. The map itself NEVER mirrors in RTL — tiles, markers and
/// coordinates stay in their geographic orientation.
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
    final t = TawziiTokens.of(context);

    final driverName = location['driver_name'] as String? ?? '';
    final timestamp = DateTime.tryParse(location['timestamp'] as String? ?? '');
    final minutesAgo = timestamp != null
        ? DateTime.now().toUtc().difference(timestamp).inMinutes
        : 0;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
        child: Row(
          children: [
            const StatusDot(StatusKind.success, size: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    driverName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.lastSeenAgo(minutesAgo),
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final locations = ref.watch(driverLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.map)),
      body: Stack(
        children: [
          // Map — forced LTR so geographic orientation never mirrors.
          Directionality(
            textDirection: TextDirection.ltr,
            child: FlutterMap(
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
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.accent,
                                border:
                                    Border.all(color: t.onAccent, width: 2),
                              ),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: t.onAccent,
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
          ),

          // Empty state overlay
          locations.when(
            data: (locs) {
              if (locs.isNotEmpty) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: t.scrim,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StatusDot(StatusKind.muted),
                          const SizedBox(width: 9),
                          Text(
                            l10n.noActiveDrivers,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ],
                      ),
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
