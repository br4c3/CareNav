import 'package:latlong2/latlong.dart';

import 'navigation_models.dart';

abstract class NavigationRepository {
  List<String> get origins;

  List<CareDestination> get destinations;

  LatLng originLocation(String origin);

  Future<PlannedRoute> planRoute({
    required String origin,
    LatLng? currentLocation,
    required CareDestination destination,
    MobilityProfile profile,
  });
}
