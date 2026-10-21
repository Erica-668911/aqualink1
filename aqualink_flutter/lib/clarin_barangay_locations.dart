import 'package:latlong2/latlong.dart' show LatLng;

class ClarinBarangayLocations {
  static const Map<String, LatLng> all = {
    'Bacani': LatLng(9.9700, 124.0378),
    'Bogtongbod': LatLng(9.9368, 124.0550),
    'Bonbon': LatLng(9.9645, 124.0170),
    'Bontud': LatLng(9.9479, 124.0337),
    'Buacao': LatLng(9.9538, 124.0018),
    'Buangan': LatLng(9.9354, 124.0245),
    'Cabog': LatLng(9.9158, 124.0476),
    'Caboy': LatLng(9.9519, 124.0590),
    'Caluwasan': LatLng(9.9505, 124.0697),
    'Candajec': LatLng(9.9501, 124.0224),
    'Cantoyoc': LatLng(9.9652, 124.0593),
    'Comaang': LatLng(9.9656, 124.0331),
    'Danahao': LatLng(9.9183, 124.0250),
    'Katipunan': LatLng(9.9392, 124.0101),
    'Lajog': LatLng(9.9547, 124.0084),
    'Mataub': LatLng(9.9521, 124.0515),
    'Nahawan': LatLng(9.9720, 124.0471),
    'Poblacion Centro': LatLng(9.9623, 124.0237),
    'Poblacion Norte': LatLng(9.9645, 124.0222),
    'Poblacion Sur': LatLng(9.9597, 124.0241),
    'Tangaran': LatLng(9.9724, 124.0303),
    'Tontunan': LatLng(9.9439, 124.0523),
    'Tubod': LatLng(9.9223, 124.0386),
    'Villaflor': LatLng(9.9547, 124.0644),
  };

  static LatLng? fromLandmark(String? landmark) {
    final candidate = (landmark ?? '').trim();
    if (candidate.isEmpty) {
      return null;
    }

    final normalized = candidate.toLowerCase();
    for (final entry in all.entries) {
      final key = entry.key.toLowerCase();
      if (normalized.contains(key) || key.contains(normalized)) {
        return entry.value;
      }
    }
    return null;
  }

  static LatLng? fromName(String? barangay) {
    if (barangay == null || barangay.trim().isEmpty) {
      return null;
    }

    final normalized = barangay.trim();
    return all[normalized] ??
        all.entries.firstWhere(
          (entry) => entry.key.toLowerCase() == normalized.toLowerCase(),
          orElse: () => const MapEntry('', LatLng(0, 0)),
        ).value;
  }
}
