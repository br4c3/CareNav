import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'navigation_models.dart';
import 'navigation_repository.dart';

class NavigationController extends ChangeNotifier {
  NavigationController(this._repository)
    : _origin = _repository.origins.first,
      _filteredDestinations = const [];

  final NavigationRepository _repository;
  String _query = '';
  String _origin;
  List<CareDestination> _filteredDestinations;
  PlannedRoute? _activeRoute;
  int _currentStepIndex = 0;
  LatLng? _currentLocation;
  var _isPlanning = false;
  String? _errorMessage;

  List<String> get origins => _repository.origins;

  List<CareDestination> get destinations => _repository.destinations;

  List<CareDestination> get filteredDestinations => _filteredDestinations;

  String get query => _query;

  String get origin => _origin;

  PlannedRoute? get activeRoute => _activeRoute;

  int get currentStepIndex => _currentStepIndex;

  LatLng? get currentLocation => _currentLocation;

  bool get isPlanning => _isPlanning;

  String? get errorMessage => _errorMessage;

  bool get hasActiveRoute => _activeRoute != null;

  bool get isRouteComplete {
    final route = _activeRoute;
    return route != null && _currentStepIndex >= route.steps.length;
  }

  String get currentInstruction {
    final route = _activeRoute;
    if (route == null) {
      return '목적지를 선택하세요.';
    }
    if (isRouteComplete) {
      return '목적지에 도착했습니다.';
    }
    return route.steps[_currentStepIndex].instruction;
  }

  NavigationStep? get currentStep {
    final route = _activeRoute;
    if (route == null || isRouteComplete) {
      return null;
    }
    return route.steps[_currentStepIndex];
  }

  void updateOrigin(String origin) {
    if (!_repository.origins.contains(origin)) {
      return;
    }
    _origin = origin;
    final route = _activeRoute;
    if (route != null) {
      selectDestination(route.destination);
    } else {
      notifyListeners();
    }
  }

  void updateQuery(String query) {
    _query = query;
    final normalizedQuery = query.trim().toLowerCase();
    _filteredDestinations = normalizedQuery.isEmpty
        ? const []
        : _repository.destinations.where((destination) {
            final target =
                '${destination.name} ${destination.category} ${destination.floor}'
                    .toLowerCase();
            return target.contains(normalizedQuery);
          }).toList();
    notifyListeners();
  }

  Future<void> useGpsLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = '위치 서비스를 사용할 수 없어 선택한 출발 위치로 안내합니다.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _errorMessage = '위치 권한이 없어 선택한 출발 위치로 안내합니다.';
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);
      _origin = '현재 위치';
      _errorMessage = null;
      notifyListeners();
    } catch (_) {
      _errorMessage = '현재 위치를 가져오지 못해 선택한 출발 위치로 안내합니다.';
      notifyListeners();
    }
  }

  Future<void> selectDestination(CareDestination destination) async {
    _isPlanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeRoute = await _repository.planRoute(
        origin: _origin,
        currentLocation: _origin == '현재 위치' ? _currentLocation : null,
        destination: destination,
        profile: const MobilityProfile.elderlyFriendly(),
      );
      _currentStepIndex = 0;
    } catch (_) {
      _errorMessage = '경로를 계산하지 못했습니다. 출발 위치를 다시 선택해 주세요.';
    } finally {
      _isPlanning = false;
      notifyListeners();
    }
  }

  void advanceStep() {
    final route = _activeRoute;
    if (route == null || isRouteComplete) {
      return;
    }
    _currentStepIndex += 1;
    notifyListeners();
  }

  void clearRoute() {
    _activeRoute = null;
    _currentStepIndex = 0;
    notifyListeners();
  }
}
