import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parapo_transpo/core/theme/app_theme.dart';
import 'package:parapo_transpo/data/transit_network.dart';
import 'package:parapo_transpo/features/home/home_screen.dart';
import 'package:parapo_transpo/providers/app_providers.dart';

void main() {
  testWidgets('route fare panel renders without layout exceptions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final places = TransitNetwork.placeMap;
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(preferences),
    ]);
    addTearDown(container.dispose);
    container.read(originProvider.notifier).state = places['mamatid']!;
    container.read(destinationProvider.notifier).state = places['balibago']!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 430,
              height: 900,
              child: TripPlannerPanel(scrollController: scrollController),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Fare breakdown'), findsOneWidget);
  });
}
