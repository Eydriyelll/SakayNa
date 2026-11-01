/// Build-time config via --dart-define / --dart-define-from-file.
class AppConfig {
  static const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
  static const mapboxStyle = String.fromEnvironment('MAPBOX_STYLE', defaultValue: 'streets-v12');

  /// Per-device monthly cap for Mapbox Directions calls (free tier is 100,000/month in total).
  static const mapboxMonthlyCap = int.fromEnvironment('MAPBOX_MONTHLY_CAP', defaultValue: 1500);

  static bool get hasMapbox =>
      mapboxToken.startsWith('pk.') && !mapboxToken.contains('PASTE_YOUR_PUBLIC_TOKEN');

  /// Mapbox Static Tiles (512px, hence zoomOffset -1). Falls back to OSM when no token is set.
  static String get tileUrl => hasMapbox
      ? 'https://api.mapbox.com/styles/v1/mapbox/$mapboxStyle/tiles/512/{z}/{x}/{y}?access_token=$mapboxToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static double get tileSize => hasMapbox ? 512 : 256;
  static double get zoomOffset => hasMapbox ? -1 : 0;
}
