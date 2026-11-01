// Refines approximate place coordinates in lib/data/transit_network.dart using
// the Mapbox Geocoding API (free tier: 100,000 temporary requests / month; this
// script makes about 45).
//
//   MAPBOX_TOKEN=pk.xxx dart run tools/geocode_places.dart          (preview only)
//   MAPBOX_TOKEN=pk.xxx dart run tools/geocode_places.dart --write  (update the file)
//
// Windows PowerShell:  $env:MAPBOX_TOKEN="pk.xxx"; dart run tools/geocode_places.dart
// Results that move a place more than 4 km are rejected and reported (probably a bad match).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

double _meters(double la1, double lo1, double la2, double lo2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final a = math.pow(math.sin(rad(la2 - la1) / 2), 2) +
      math.cos(rad(la1)) * math.cos(rad(la2)) * math.pow(math.sin(rad(lo2 - lo1) / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

Future<void> main(List<String> args) async {
  final token = Platform.environment['MAPBOX_TOKEN'] ?? '';
  if (token.isEmpty) {
    stderr.writeln('Set the MAPBOX_TOKEN environment variable first.');
    exit(1);
  }
  final write = args.contains('--write');
  final file = File('lib/data/transit_network.dart');
  final src = file.readAsStringSync();
  final re = RegExp(r"_([btl])\('([a-z_]+)',\s*'([^']+)',\s*'([^']+)',\s*([0-9.]+),\s*([0-9.]+)\)");
  final matches = re.allMatches(src).toList();
  final edits = <(int, int, String)>[];

  for (final m in matches) {
    final kind = m.group(1)!;
    final id = m.group(2)!;
    final name = m.group(3)!;
    final city = m.group(4)!;
    final lat = double.parse(m.group(5)!);
    final lng = double.parse(m.group(6)!);
    final q = kind == 'b' ? 'Barangay $name, $city, Laguna, Philippines' : '$name, $city, Laguna, Philippines';
    final uri = Uri.https('api.mapbox.com', '/search/geocode/v6/forward', {
      'q': q,
      'country': 'ph',
      'proximity': '121.12,14.28',
      'limit': '1',
      'access_token': token,
    });
    try {
      final res = await http.get(uri);
      final feats = (jsonDecode(res.body)['features'] as List?) ?? [];
      if (res.statusCode != 200 || feats.isEmpty) {
        stdout.writeln('MISS  $id  ($q)');
        continue;
      }
      final c = feats.first['geometry']['coordinates'] as List;
      final nlng = (c[0] as num).toDouble();
      final nlat = (c[1] as num).toDouble();
      final moved = _meters(lat, lng, nlat, nlng);
      if (moved > 4000) {
        stdout.writeln('SKIP  $id  moved ${moved.round()} m (rejected)');
        continue;
      }
      stdout.writeln('OK    $id  moved ${moved.round()} m -> ${nlat.toStringAsFixed(4)}, ${nlng.toStringAsFixed(4)}');
      edits.add((
        m.start,
        m.end,
        "_$kind('$id', '$name', '$city', ${nlat.toStringAsFixed(4)}, ${nlng.toStringAsFixed(4)})"
      ));
    } catch (e) {
      stdout.writeln('ERR   $id  $e');
    }
  }

  if (write && edits.isNotEmpty) {
    var out = src;
    for (final e in edits.reversed) {
      out = out.replaceRange(e.$1, e.$2, e.$3);
    }
    file.writeAsStringSync(out);
    stdout.writeln('\nUpdated ${edits.length} places in ${file.path}. Re-run the app to see them.');
  } else {
    stdout.writeln('\nPreview only. Add --write to update ${file.path}.');
  }
}
