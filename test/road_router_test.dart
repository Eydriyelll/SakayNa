import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parapo_transpo/core/config/app_config.dart';
import 'package:parapo_transpo/core/services/road_router.dart';
import 'package:parapo_transpo/models/route_leg.dart';
import 'package:parapo_transpo/models/transit_mode.dart';

void main() {
  test(
    'road snapping uses actual route stops, not sampled points',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final coordinates = request.url.pathSegments.last
            .split(';')
            .map((pair) => pair.split(',').map(double.parse).toList())
            .toList();
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distance': 1000,
                'geometry': {
                  'coordinates': [coordinates.first, coordinates.last],
                },
              },
            ],
          }),
          200,
        );
      });
      final router = RoadRouter(preferences, client: client);
      final leg = RouteLeg(
        mode: TransitMode.pujTraditional,
        instruction: 'Test road route',
        fromName: 'Start',
        toName: 'Finish',
        distanceKm: 3,
        polyline: [
          for (var i = 0; i < 27; i++)
            LatLng(14.2 + i * 0.001, 121.1 + i * 0.001),
        ],
        routeLabel: 'Test PUJ',
      );

      final route = await router.refine(TransitRoute(legs: [leg]));

      expect(requests, hasLength(2));
      expect(requests.first.url.pathSegments.last.split(';'), hasLength(25));
      expect(requests.last.url.pathSegments.last.split(';'), hasLength(3));
      expect(route.allRoadSnapped, isTrue);
      expect(route.totalKm, 2);
    },
    skip: !AppConfig.hasMapbox,
  );
}
