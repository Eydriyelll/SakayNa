import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/fare_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../models/place.dart';
import '../../providers/app_providers.dart';
import '../../widgets/mode_badge.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripHistoryProvider);
    final places = ref.watch(routeEngineProvider).places;
    final fmt = DateFormat('MMM d, y · h:mm a');
    final regular = trips.fold<int>(0, (s, t) => s + t.regularTotal);
    final discounted = trips.fold<int>(0, (s, t) => s + t.discountedTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip history'),
        actions: [
          if (trips.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all trips?'),
                    content: const Text(
                        'This removes every saved trip from this device.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(96, 44)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) ref.read(tripHistoryProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: trips.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 56),
                  SizedBox(height: 12),
                  Text('No trips yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                      'Tap "Start trip" on the map to save a trip with its fare.',
                      textAlign: TextAlign.center),
                ]),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(child: _Stat('Trips', '${trips.length}')),
                        Expanded(child: _Stat('Regular total', pesos(regular))),
                        Expanded(
                            child: _Stat('With 20% off', pesos(discounted))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final t in trips)
                    Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade700,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) =>
                          ref.read(tripHistoryProvider.notifier).remove(t.id),
                      child: Card(
                        child: ExpansionTile(
                          title: Text('${t.originName} → ${t.destName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${fmt.format(t.createdAt)} · ${t.totalKm.toStringAsFixed(1)} km\n'
                              'Regular ${pesos(t.regularTotal)}  ·  20% off ${pesos(t.discountedTotal)}'),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          children: [
                            for (final l in t.lines)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: Row(children: [
                                  ModeBadge(l.mode),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(l.label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis)),
                                  Text(pesos(l.regularCentavos),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ]),
                              ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Jeepney: ${t.pujChoice ?? 'as routed'} · Tricycle: ${t.tricycleService}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.replay,
                                    color: AppColors.primary),
                                label: const Text('Plan again'),
                                onPressed: () {
                                  Place? restore(
                                    String id,
                                    String name,
                                    String? city,
                                    LatLng? position,
                                  ) {
                                    if (places[id] case final place?) {
                                      return place;
                                    }
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
                                    ref
                                        .read(destinationProvider.notifier)
                                        .state = d;
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
