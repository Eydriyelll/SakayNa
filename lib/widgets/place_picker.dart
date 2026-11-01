import 'package:flutter/material.dart';
import '../models/place.dart';

Future<Place?> pickPlace(BuildContext context, List<Place> places, {required String title}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _PickerSheet(places: places, title: title),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.places, required this.title});
  final List<Place> places;
  final String title;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final shown = widget.places
        .where((p) => p.name.toLowerCase().contains(q) || p.city.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final groups = <String, List<Place>>{
      'Terminals & landmarks': shown.where((p) => p.kind != PlaceKind.barangay).toList(),
      'Cabuyao barangays': shown.where((p) => p.kind == PlaceKind.barangay && p.city == 'Cabuyao').toList(),
      'Santa Rosa barangays': shown.where((p) => p.kind == PlaceKind.barangay && p.city == 'Santa Rosa').toList(),
    };
    final items = <Object>[];
    groups.forEach((header, list) {
      if (list.isNotEmpty) {
        items.add(header);
        items.addAll(list);
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: widget.title, prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No matching place'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      if (it is String) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(it,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        );
                      }
                      final p = it as Place;
                      return ListTile(
                        leading: Icon(p.kind == PlaceKind.barangay
                            ? Icons.holiday_village_outlined
                            : (p.kind == PlaceKind.terminal ? Icons.directions_bus_filled_outlined : Icons.place_outlined)),
                        title: Text(p.name),
                        subtitle: Text(p.subtitle),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
