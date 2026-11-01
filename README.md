# SakayNa!

SakayNa! is a single-screen commuter guide and fare estimator for Cabuyao and
Santa Rosa, Laguna. It includes a searchable place picker, route alternatives
by PUJ type, shared/special tricycle pricing, automatic fare estimates, and
on-device trip history.

## Map and usage costs

The app uses Mapbox tiles and Directions only when a public Mapbox token is
provided at build time. Without a token it falls back to OpenStreetMap tiles
and straight-line route geometry. Mapbox's free allowance is account-wide;
the per-device Directions request limit is only an additional safeguard and
cannot guarantee that a multi-user production app will stay within a free
allowance. To ensure the app makes no Mapbox requests, build without a token.
If you enable Mapbox, restrict the public token to your app/site and monitor
usage and billing limits in the Mapbox account.

For local development, copy `config/dev.example.json` to `config/dev.json`,
replace its placeholder token only if you want to use Mapbox, and run:

```sh
flutter run -d chrome --dart-define-from-file=config/dev.json
```

`config/dev.json` is ignored by Git. Do not commit a real token.

## Data coverage

The place picker includes all 18 Cabuyao and all 18 Santa Rosa barangays, plus
the terminal/landmark stops currently represented in the local network.
However, most coordinates, feeder links, and PUJ corridors are estimates. The
network includes the St. James Hospital and Mariquita Pueblo SB PUJ stops shown
in the supplied map reference, along with an identified PUDTODA link and
estimated barangay TODA access links; it is not a verified inventory of every
operating TODA stand or PUJ terminal. Walking access is offered to nearby
network stops up to 1 km and 10 minutes at an estimated 5 km/h; otherwise the
route can use estimated tricycle access. See the header comment in
`lib/data/transit_network.dart`. Confirm routes and fares with local operators
before relying on them; TODA fare rates are placeholders pending official local
fare matrices.

Mapbox road geometry improves visual routing but does not verify that a
specific PUJ or TODA service operates along that road. Route/fare results are
estimates, not turn-by-turn navigation or official fare quotations.

When road routing is enabled, Mapbox receives the selected stop coordinates
and snaps each represented transit stop to nearby drivable roads. A route is
marked approximate whenever any leg cannot be matched or Mapbox is not
configured. Users can choose **Choose a location on the map**, select whether
to pin the start or destination, and tap the map; pinned points connect to the
nearest represented stop and are stored with saved trips for replay.
