import 'package:latlong2/latlong.dart';

enum AccessibilityFeature {
  walkway,
  elevator,
  escalator,
  stairs,
  ramp,
  outdoor,
}

class MobilityProfile {
  const MobilityProfile({
    this.elevatorPenalty = 1,
    this.escalatorPenalty = 8,
    this.stairsPenalty = 1000,
    this.rampPenalty = 2,
    this.walkwayPenalty = 1,
  });

  const MobilityProfile.elderlyFriendly()
    : elevatorPenalty = 1,
      escalatorPenalty = 100,
      stairsPenalty = 1000,
      rampPenalty = 2,
      walkwayPenalty = 1;

  final double elevatorPenalty;
  final double escalatorPenalty;
  final double stairsPenalty;
  final double rampPenalty;
  final double walkwayPenalty;

  double penaltyFor(AccessibilityFeature feature) {
    return switch (feature) {
      AccessibilityFeature.elevator => elevatorPenalty,
      AccessibilityFeature.escalator => escalatorPenalty,
      AccessibilityFeature.stairs => stairsPenalty,
      AccessibilityFeature.ramp => rampPenalty,
      AccessibilityFeature.walkway ||
      AccessibilityFeature.outdoor => walkwayPenalty,
    };
  }
}

class CareDestination {
  const CareDestination({
    required this.id,
    required this.name,
    required this.category,
    required this.floor,
    required this.landmark,
    required this.location,
    required this.entryNodeId,
  });

  final String id;
  final String name;
  final String category;
  final String floor;
  final String landmark;
  final LatLng location;
  final String entryNodeId;
}

class NavigationStep {
  const NavigationStep({
    required this.instruction,
    required this.detail,
    required this.minutes,
    required this.feature,
  });

  final String instruction;
  final String detail;
  final int minutes;
  final AccessibilityFeature feature;
}

class RouteSegment {
  const RouteSegment({
    required this.title,
    required this.steps,
    required this.path,
    required this.distanceMeters,
  });

  final String title;
  final List<NavigationStep> steps;
  final List<LatLng> path;
  final int distanceMeters;

  int get totalMinutes {
    return steps.fold(0, (total, step) => total + step.minutes);
  }
}

class PlannedRoute {
  const PlannedRoute({
    required this.origin,
    required this.originLocation,
    required this.destination,
    required this.segments,
    required this.path,
    required this.distanceMeters,
    required this.accessibilitySummary,
    required this.usedFallback,
  });

  final String origin;
  final LatLng originLocation;
  final CareDestination destination;
  final List<RouteSegment> segments;
  final List<LatLng> path;
  final int distanceMeters;
  final String accessibilitySummary;
  final bool usedFallback;

  List<NavigationStep> get steps {
    return [for (final segment in segments) ...segment.steps];
  }

  int get totalMinutes {
    return steps.fold(0, (total, step) => total + step.minutes);
  }
}

class IndoorNode {
  const IndoorNode({
    required this.id,
    required this.name,
    required this.floor,
    required this.location,
  });

  final String id;
  final String name;
  final String floor;
  final LatLng location;
}

class IndoorEdge {
  const IndoorEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.feature,
    required this.distanceMeters,
    required this.instruction,
  });

  final String fromNodeId;
  final String toNodeId;
  final AccessibilityFeature feature;
  final int distanceMeters;
  final String instruction;
}

class IndoorFacilityGraph {
  const IndoorFacilityGraph({
    required this.entryNodeId,
    required this.nodes,
    required this.edges,
    required this.destinations,
  });

  final String entryNodeId;
  final List<IndoorNode> nodes;
  final List<IndoorEdge> edges;
  final List<CareDestination> destinations;
}
