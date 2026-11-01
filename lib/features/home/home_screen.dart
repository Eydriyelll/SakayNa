import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/app_config.dart';
import '../../core/services/fare_engine.dart';
import '../../core/services/route_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fare_result.dart';
import '../../models/place.dart';
import '../../models/route_leg.dart';
import '../../models/transit_mode.dart';
import '../../models/trip_record.dart';
import '../../providers/app_providers.dart';
import '../../widgets/mode_badge.dart';
import '../../widgets/place_picker.dart';
import '../history/history_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _map = MapController();

  void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        fn();
      } catch (_) {}
    });
  }

  Future<void> _chooseMapPin() async {
    final target = await showModalBottomSheet<MapPinTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
            title: Text('Choose a location on the map'),
            subtitle: Text('Select which trip point you want to pin.'),
          ),
          ListTile(
            leading: const Icon(Icons.trip_origin, color: Colors.green),
            title: const Text('Pin starting point'),
            onTap: () => Navigator.pop(context, MapPinTarget.origin),
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: Color(0xFFE64A19)),
            title: const Text('Pin destination'),
            onTap: () => Navigator.pop(context, MapPinTarget.destination),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (target == null || !mounted) return;
    ref.read(mapPinTargetProvider.notifier).state = target;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap the map to pin your ${target == MapPinTarget.origin ? 'starting point' : 'destination'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final pinTarget = ref.watch(mapPinTargetProvider);

    // Fit the map again when road-snapped geometry replaces the estimate.
    ref.listen<TransitRoute?>(routeProvider, (prev, next) {
      if (next == null) return;
      final pts = [for (final l in next.legs) ...l.polyline];
      if (pts.length < 2) return;
      _afterFrame(() => _map.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: EdgeInsets.fromLTRB(40, 100, 40, screenH * 0.52),
          )));
    });
    // Center on a single selected place.
    void centerOn(Place? p) {
      if (p == null) return;
      if (ref.read(originProvider) != null &&
          ref.read(destinationProvider) != null) {
        return;
      }
      _afterFrame(() => _map.move(p.position, 14.5));
    }

    ref.listen<Place?>(originProvider, (prev, next) => centerOn(next));
    ref.listen<Place?>(destinationProvider, (prev, next) => centerOn(next));

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _MapLayer(controller: _map)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _RoundButton(
                  icon: Icons.history,
                  tooltip: 'Trip history',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen())),
                ),
                const SizedBox(width: 12),
                _RoundButton(
                  icon: Icons.add_location_alt_outlined,
                  tooltip: 'Choose a location on the map',
                  onTap: _chooseMapPin,
                ),
                const SizedBox(width: 12),
                const _BrandChip(),
              ]),
            ),
          ),
        ),
        if (pinTarget != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: AppColors.primary,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          'Tap the map to pin your ${pinTarget == MapPinTarget.origin ? 'starting point' : 'destination'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel pin selection',
                        onPressed: () => ref
                            .read(mapPinTargetProvider.notifier)
                            .state = null,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox.expand(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.22,
                  maxChildSize: 0.92,
                  snap: true,
                  builder: (context, controller) =>
                      TripPlannerPanel(scrollController: controller),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- map

class _MapLayer extends ConsumerWidget {
  const _MapLayer({required this.controller});
  final MapController controller;

  void _select(WidgetRef ref, Place p) {
    if (ref.read(originProvider) == null) {
      ref.read(originProvider.notifier).state = p;
    } else {
      ref.read(destinationProvider.notifier).state = p;
    }
  }

  void _pin(WidgetRef ref, BuildContext context, LatLng position) {
    final target = ref.read(mapPinTargetProvider);
    if (target == null) return;

    final locations = ref.read(routeEngineProvider).placeList;
    final nearest = locations.reduce((a, b) {
      final distanceA =
          const Distance().as(LengthUnit.Meter, position, a.position);
      final distanceB =
          const Distance().as(LengthUnit.Meter, position, b.position);
      return distanceA <= distanceB ? a : b;
    });
    final distanceMeters =
        const Distance().as(LengthUnit.Meter, position, nearest.position);
    if (distanceMeters > 6000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Pins are currently supported in Cabuyao and Santa Rosa.'),
        ),
      );
      return;
    }

    final label = target == MapPinTarget.origin
        ? 'Pinned starting point'
        : 'Pinned destination';
    final pin = Place(
      id: 'pin_${target.name}_${DateTime.now().microsecondsSinceEpoch}',
      name:
          '$label (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})',
      city: nearest.city,
      kind: PlaceKind.landmark,
      position: position,
    );
    final provider =
        target == MapPinTarget.origin ? originProvider : destinationProvider;
    ref.read(provider.notifier).state = pin;
    ref.read(mapPinTargetProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);
    final origin = ref.watch(originProvider);
    final dest = ref.watch(destinationProvider);
    final stops = ref
        .watch(routeEngineProvider)
        .placeList
        .where((p) => p.kind != PlaceKind.barangay);

    final markers = <Marker>[
      for (final p in stops)
        Marker(
          point: p.position,
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () {
              if (ref.read(mapPinTargetProvider) != null) {
                _pin(ref, context, p.position);
              } else {
                _select(ref, p);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: const Icon(Icons.directions_bus,
                  size: 16, color: AppColors.primary),
            ),
          ),
        ),
      if (route != null)
        for (var i = 1; i < route.legs.length; i++)
          Marker(
            point: route.legs[i].polyline.first,
            width: 34,
            height: 34,
            child: Icon(Icons.swap_horiz_rounded,
                size: 30, color: route.legs[i].mode.color),
          ),
      if (origin != null)
        Marker(
          point: origin.position,
          width: 40,
          height: 40,
          child:
              Icon(Icons.trip_origin, size: 32, color: Colors.green.shade700),
        ),
      if (dest != null)
        Marker(
          point: dest.position,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child:
              const Icon(Icons.location_on, size: 42, color: Color(0xFFE64A19)),
        ),
    ];

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: const LatLng(14.2900, 121.1180),
        initialZoom: 12.2,
        minZoom: 9,
        maxZoom: 19,
        onTap: (_, position) => _pin(ref, context, position),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.tileUrl,
          tileSize: AppConfig.tileSize,
          zoomOffset: AppConfig.zoomOffset,
          userAgentPackageName: 'ph.parapo.sakayna',
        ),
        if (route != null)
          PolylineLayer(polylines: [
            for (final l in route.legs)
              Polyline(
                points: l.polyline,
                strokeWidth: 6,
                color: l.mode.color,
                borderStrokeWidth: 1.5,
                borderColor: Colors.black54,
              ),
          ]),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            if (AppConfig.hasMapbox) const TextSourceAttribution('Mapbox'),
            const TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.primary),
        onPressed: onTap,
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.directions_bus_filled, size: 18, color: AppColors.accent),
          SizedBox(width: 8),
          Text('SakayNa!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- panel

class TripPlannerPanel extends ConsumerWidget {
  const TripPlannerPanel({required this.scrollController, super.key});
  final ScrollController scrollController;

  Future<void> _startTrip(BuildContext context, WidgetRef ref,
      TransitRoute route, FareBreakdown fare) async {
    final o = ref.read(originProvider);
    final d = ref.read(destinationProvider);
    if (o == null || d == null) return;
    final now = DateTime.now();
    final override = ref.read(pujOverrideProvider);
    final record = TripRecord(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      originId: o.id,
      originName: o.name,
      destId: d.id,
      destName: d.name,
      totalKm: route.totalKm,
      lines: fare.lines.map(TripLine.fromFareLine).toList(),
      regularTotal: fare.regularTotal,
      discountedTotal: fare.discountedTotal,
      pujChoice: override?.label,
      tricycleService: ref.read(tricycleServiceProvider).name,
      originPosition: o.position,
      destPosition: d.position,
      originCity: o.city,
      destCity: d.city,
    );
    await _saveTrip(context, ref, record);
  }

  Future<void> _saveTrip(
      BuildContext context, WidgetRef ref, TripRecord record) async {
    try {
      await ref.read(tripHistoryProvider.notifier).add(record);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip saved to your history')),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while saving a trip to history'),
      ));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this trip to history.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(originProvider);
    final dest = ref.watch(destinationProvider);
    final route = ref.watch(routeProvider);
    final fare = ref.watch(fareProvider);
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 14,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const _Inputs(),
              if (route != null && fare != null)
                _RouteSection(route: route, fare: fare)
              else
                _IdleSection(noRoute: origin != null && dest != null),
            ],
          ),
        ),
        if (route != null && fare != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Start trip  ·  ${pesos(fare.regularTotal)}'),
                onPressed: () => _startTrip(context, ref, route, fare),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Inputs extends ConsumerWidget {
  const _Inputs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(originProvider);
    final dest = ref.watch(destinationProvider);
    final places = ref.watch(routeEngineProvider).placeList;
    final cs = Theme.of(context).colorScheme;

    Future<void> choose(StateController<Place?> target, String title) async {
      final p = await pickPlace(context, places, title: title);
      if (p != null) target.state = p;
    }

    Widget row(IconData icon, Color color, String hint, Place? value,
        VoidCallback onTap, VoidCallback onClear) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value?.name ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w800,
                  color: value == null ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
            if (value != null)
              InkWell(
                onTap: onClear,
                customBorder: const CircleBorder(),
                child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 18)),
              ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(
          child: Column(children: [
            row(
                Icons.trip_origin,
                Colors.green.shade700,
                'Where are you starting?',
                origin,
                () => choose(
                    ref.read(originProvider.notifier), 'Search starting point'),
                () => ref.read(originProvider.notifier).state = null),
            const Divider(height: 1),
            row(
                Icons.location_on,
                const Color(0xFFE64A19),
                'Where to?',
                dest,
                () => choose(ref.read(destinationProvider.notifier),
                    'Search destination'),
                () => ref.read(destinationProvider.notifier).state = null),
          ]),
        ),
        IconButton(
          tooltip: 'Swap',
          icon: const Icon(Icons.swap_vert),
          onPressed: () {
            ref.read(originProvider.notifier).state = dest;
            ref.read(destinationProvider.notifier).state = origin;
          },
        ),
      ]),
    );
  }
}

class _IdleSection extends ConsumerWidget {
  const _IdleSection({required this.noRoute});
  final bool noRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripHistoryProvider);
    final stops = ref
        .watch(routeEngineProvider)
        .placeList
        .where((p) => p.kind != PlaceKind.barangay)
        .toList();
    final recents = <String, TripRecord>{};
    for (final t in trips) {
      recents.putIfAbsent('${t.originId}>${t.destId}', () => t);
    }
    final places = ref.watch(routeEngineProvider).places;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      if (noRoute)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No route found between these two places yet.'),
        ),
      Text('Popular stops', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in stops)
          ActionChip(
            avatar: Icon(
                p.kind == PlaceKind.terminal
                    ? Icons.directions_bus
                    : Icons.place,
                size: 16),
            label: Text(p.name),
            onPressed: () {
              if (ref.read(originProvider) == null) {
                ref.read(originProvider.notifier).state = p;
              } else {
                ref.read(destinationProvider.notifier).state = p;
              }
            },
          ),
      ]),
      if (recents.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Recent trips', style: Theme.of(context).textTheme.titleMedium),
        for (final t in recents.values.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text('${t.originName} → ${t.destName}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(pesos(t.regularTotal)),
            onTap: () {
              Place? restore(
                String id,
                String name,
                String? city,
                LatLng? position,
              ) {
                final existing = places[id];
                if (existing != null) return existing;
                if (position == null) return null;
                return Place(
                  id: id,
                  name: name,
                  city: city ?? 'Cabuyao',
                  kind: PlaceKind.landmark,
                  position: position,
                );
              }

              final o = restore(
                t.originId,
                t.originName,
                t.originCity,
                t.originPosition,
              );
              final d = restore(
                t.destId,
                t.destName,
                t.destCity,
                t.destPosition,
              );
              if (o != null && d != null) {
                ref.read(originProvider.notifier).state = o;
                ref.read(destinationProvider.notifier).state = d;
              }
            },
          ),
      ],
    ]);
  }
}

class _RouteSection extends ConsumerWidget {
  const _RouteSection({required this.route, required this.fare});
  final TransitRoute route;
  final FareBreakdown fare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(pujOverrideProvider);
    final trike = ref.watch(tricycleServiceProvider);
    final loading = ref.watch(roadLoadingProvider);
    final paidLegCount = route.paidLegs.length;
    final transfers = paidLegCount > 0 ? paidLegCount - 1 : 0;
    final hasPuj = route.legs.any((l) =>
        l.mode == TransitMode.pujTraditional ||
        l.mode == TransitMode.pujModern);
    final hasTrike = route.legs.any((l) => l.mode == TransitMode.tricycle);
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Row(children: [
        Text(
            '${route.totalKm.toStringAsFixed(1)} km · $transfers transfer${transfers == 1 ? '' : 's'}',
            style: titleStyle),
        const Spacer(),
        if (loading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final mode in route.legs.map((leg) => leg.mode).toSet())
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: mode.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                mode == TransitMode.walk ? 'Walk (free)' : mode.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
        ],
      ),
      const SizedBox(height: 8),
      for (final leg in route.legs)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ModeBadge(leg.mode),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                leg.mode == TransitMode.walk
                    ? '${leg.instruction}  (${leg.distanceKm.toStringAsFixed(1)} km · ~${RouteEngine.walkingMinutes(leg.distanceKm)} min)'
                    : '${leg.instruction}  (${leg.distanceKm.toStringAsFixed(1)} km)',
              ),
            ),
          ]),
        ),
      if (!route.allVerified)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Beta route data - confirm the jeepney sign or TODA with the driver.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ]),
        ),
      if (!route.allRoadSnapped)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.alt_route, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppConfig.hasMapbox
                      ? 'Some roads could not be matched. The unsnapped line is approximate; confirm the route before travelling.'
                      : 'Street-following routes need a configured Mapbox token. This line is approximate and may cross blocks or buildings.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      if (hasPuj) ...[
        const SizedBox(height: 16),
        Text('Jeepney type', style: titleStyle),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final opt in <TransitMode?>[
            null,
            TransitMode.pujTraditional,
            TransitMode.pujModern
          ])
            ChoiceChip(
              label: Text(opt == null ? 'As routed' : opt.label),
              selected: override == opt,
              onSelected: (_) =>
                  ref.read(pujOverrideProvider.notifier).state = opt,
            ),
        ]),
      ],
      if (hasTrike) ...[
        const SizedBox(height: 16),
        Text('Tricycle service', style: titleStyle),
        const SizedBox(height: 8),
        SegmentedButton<TricycleService>(
          segments: const [
            ButtonSegment(value: TricycleService.shared, label: Text('Shared')),
            ButtonSegment(
                value: TricycleService.special, label: Text('Special')),
          ],
          selected: {trike},
          onSelectionChanged: (s) =>
              ref.read(tricycleServiceProvider.notifier).state = s.first,
        ),
      ],
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: _TotalCard(
                title: 'Regular',
                amount: fare.regularTotal,
                color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            title: '20% off',
            subtitle: 'Student · Senior · PWD',
            amount: fare.discountedTotal,
            color: AppColors.discount,
            footer: 'Save ${pesos(fare.savings)}',
          ),
        ),
      ]),
      const SizedBox(height: 8),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Fare breakdown'),
        children: [
          for (final l in fare.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                ModeBadge(l.mode),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(l.label,
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pesos(l.regularCentavos),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                      l.discountApplies
                          ? pesos(l.discountedCentavos)
                          : 'no discount',
                      style: const TextStyle(
                          color: AppColors.discount, fontSize: 12)),
                ]),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Fares are estimates from LTFRB jeepney rates and road distance. Tricycle fares follow local '
        'TODA ordinances and use placeholder values in this build - always check the fare matrix posted '
        'in the vehicle. Map data © ${AppConfig.hasMapbox ? 'Mapbox, ' : ''}OpenStreetMap contributors.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.title,
    required this.amount,
    required this.color,
    this.subtitle,
    this.footer,
  });
  final String title;
  final String? subtitle;
  final String? footer;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        Text(subtitle ?? ' ',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Align(
            key: ValueKey(amount),
            alignment: Alignment.centerLeft,
            child: FittedBox(
              child: Text(pesos(amount),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        Text(footer ?? ' ',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }
}
