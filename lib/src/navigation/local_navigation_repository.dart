import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'navigation_models.dart';
import 'navigation_repository.dart';

class LocalNavigationRepository implements NavigationRepository {
  LocalNavigationRepository({
    OutdoorRouteRepository? outdoorRouteRepository,
    IndoorGraphRepository? indoorGraphRepository,
  }) : _outdoorRouteRepository =
           outdoorRouteRepository ??
           OpenRouteServiceRepository.fromEnvironment(),
       _indoorGraphRepository =
           indoorGraphRepository ??
           FirestoreIndoorGraphRepository.withFallback();

  final OutdoorRouteRepository _outdoorRouteRepository;
  final IndoorGraphRepository _indoorGraphRepository;

  @override
  List<String> get origins => const ['현재 위치', '정문', '로비', '주차장'];

  static const _originLocations = {
    '현재 위치': LatLng(37.5796, 126.9990),
    '정문': LatLng(37.5792, 126.9986),
    '로비': LatLng(37.5797, 126.9991),
    '주차장': LatLng(37.5787, 126.9981),
  };

  @override
  List<CareDestination> get destinations =>
      LocalIndoorGraphRepository.graph.destinations;

  @override
  LatLng originLocation(String origin) {
    return _originLocations[origin] ?? _originLocations['현재 위치']!;
  }

  @override
  Future<PlannedRoute> planRoute({
    required String origin,
    LatLng? currentLocation,
    required CareDestination destination,
    MobilityProfile profile = const MobilityProfile.elderlyFriendly(),
  }) async {
    final graph = await _indoorGraphRepository.loadGraph();
    final effectiveOrigin = currentLocation ?? originLocation(origin);
    final outdoorSegment = await _outdoorRouteRepository.route(
      from: effectiveOrigin,
      to: _entranceLocation(graph),
    );
    final indoorSegment = _planIndoorSegment(
      graph: graph,
      destination: destination,
      profile: profile,
    );
    final segments = [outdoorSegment, indoorSegment];
    final path = [for (final segment in segments) ...segment.path];

    return PlannedRoute(
      origin: origin,
      originLocation: effectiveOrigin,
      destination: destination,
      segments: segments,
      path: path,
      distanceMeters: segments.fold(
        0,
        (total, segment) => total + segment.distanceMeters,
      ),
      accessibilitySummary:
          '계단은 피하고 엘리베이터를 우선 안내합니다. 엘리베이터가 없을 때만 에스컬레이터를 사용합니다.',
      usedFallback:
          outdoorSegment.title.contains('간이') ||
          graph == LocalIndoorGraphRepository.graph,
    );
  }

  LatLng _entranceLocation(IndoorFacilityGraph graph) {
    return graph.nodes
        .firstWhere(
          (node) => node.id == graph.entryNodeId,
          orElse: () => graph.nodes.first,
        )
        .location;
  }

  RouteSegment _planIndoorSegment({
    required IndoorFacilityGraph graph,
    required CareDestination destination,
    required MobilityProfile profile,
  }) {
    final nodeById = {for (final node in graph.nodes) node.id: node};
    final path = _shortestAccessiblePath(
      graph: graph,
      fromNodeId: graph.entryNodeId,
      toNodeId: destination.entryNodeId,
      profile: profile,
    );
    final steps = <NavigationStep>[];
    final points = <LatLng>[];
    var distanceMeters = 0;

    for (final edge in path) {
      final from = nodeById[edge.fromNodeId]!;
      final to = nodeById[edge.toNodeId]!;
      if (points.isEmpty) {
        points.add(from.location);
      }
      points.add(to.location);
      distanceMeters += edge.distanceMeters;
      steps.add(
        NavigationStep(
          instruction: edge.instruction,
          detail: _detailFor(edge.feature),
          minutes: max(1, (edge.distanceMeters / 60).ceil()),
          feature: edge.feature,
        ),
      );
    }

    steps.add(
      NavigationStep(
        instruction: '${destination.name}에 도착했습니다.',
        detail: destination.landmark,
        minutes: 0,
        feature: AccessibilityFeature.walkway,
      ),
    );

    return RouteSegment(
      title: '시설 내부 안내',
      steps: steps,
      path: points.isEmpty ? [destination.location] : points,
      distanceMeters: distanceMeters,
    );
  }

  List<IndoorEdge> _shortestAccessiblePath({
    required IndoorFacilityGraph graph,
    required String fromNodeId,
    required String toNodeId,
    required MobilityProfile profile,
  }) {
    final byFrom = <String, List<IndoorEdge>>{};
    for (final edge in graph.edges) {
      byFrom.putIfAbsent(edge.fromNodeId, () => []).add(edge);
      byFrom
          .putIfAbsent(edge.toNodeId, () => [])
          .add(
            IndoorEdge(
              fromNodeId: edge.toNodeId,
              toNodeId: edge.fromNodeId,
              feature: edge.feature,
              distanceMeters: edge.distanceMeters,
              instruction: edge.instruction,
            ),
          );
    }

    final distances = <String, double>{fromNodeId: 0};
    final previous = <String, IndoorEdge>{};
    final unvisited = graph.nodes.map((node) => node.id).toSet();

    while (unvisited.isNotEmpty) {
      final current = unvisited.reduce((a, b) {
        return (distances[a] ?? double.infinity) <=
                (distances[b] ?? double.infinity)
            ? a
            : b;
      });
      if (current == toNodeId || distances[current] == null) {
        break;
      }
      unvisited.remove(current);

      for (final edge in byFrom[current] ?? const <IndoorEdge>[]) {
        if (!unvisited.contains(edge.toNodeId)) {
          continue;
        }
        final score =
            distances[current]! +
            edge.distanceMeters +
            profile.penaltyFor(edge.feature);
        if (score < (distances[edge.toNodeId] ?? double.infinity)) {
          distances[edge.toNodeId] = score;
          previous[edge.toNodeId] = edge;
        }
      }
    }

    final path = <IndoorEdge>[];
    var cursor = toNodeId;
    while (previous.containsKey(cursor)) {
      final edge = previous[cursor]!;
      path.insert(0, edge);
      cursor = edge.fromNodeId;
    }
    return path;
  }

  String _detailFor(AccessibilityFeature feature) {
    return switch (feature) {
      AccessibilityFeature.elevator => '계단 대신 엘리베이터를 우선 이용합니다.',
      AccessibilityFeature.escalator => '엘리베이터가 멀거나 없을 때 에스컬레이터를 이용합니다.',
      AccessibilityFeature.stairs => '대체 경로가 없을 때만 계단을 이용합니다.',
      AccessibilityFeature.ramp => '경사가 완만한 경사로입니다.',
      AccessibilityFeature.walkway => '평지 이동 구간입니다.',
      AccessibilityFeature.outdoor => '외부 보행 구간입니다.',
    };
  }
}

abstract class OutdoorRouteRepository {
  Future<RouteSegment> route({required LatLng from, required LatLng to});
}

class OpenRouteServiceRepository implements OutdoorRouteRepository {
  OpenRouteServiceRepository({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  factory OpenRouteServiceRepository.fromEnvironment() {
    return OpenRouteServiceRepository(
      apiKey: const String.fromEnvironment('ORS_API_KEY'),
    );
  }

  final String apiKey;
  final http.Client _client;

  @override
  Future<RouteSegment> route({required LatLng from, required LatLng to}) async {
    if (apiKey.isEmpty) {
      return _fallbackRoute(from: from, to: to);
    }

    try {
      final response = await _client
          .post(
            Uri.parse(
              'https://api.openrouteservice.org/v2/directions/wheelchair/geojson',
            ),
            headers: {
              'Authorization': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'coordinates': [
                [from.longitude, from.latitude],
                [to.longitude, to.latitude],
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackRoute(from: from, to: to);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final feature =
          (json['features'] as List<dynamic>).first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final summary = properties['summary'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final path = coordinates.map((coordinate) {
        final values = coordinate as List<dynamic>;
        return LatLng(
          (values[1] as num).toDouble(),
          (values[0] as num).toDouble(),
        );
      }).toList();

      return RouteSegment(
        title: '외부 보행 안내',
        path: path,
        distanceMeters: (summary['distance'] as num).round(),
        steps: [
          NavigationStep(
            instruction: '현재 위치에서 시설 입구까지 이동하세요.',
            detail: '보행 보조에 유리한 외부 경로를 우선 사용합니다.',
            minutes: max(1, ((summary['duration'] as num) / 60).ceil()),
            feature: AccessibilityFeature.outdoor,
          ),
        ],
      );
    } catch (_) {
      return _fallbackRoute(from: from, to: to);
    }
  }

  RouteSegment _fallbackRoute({required LatLng from, required LatLng to}) {
    final distance = const Distance().as(LengthUnit.Meter, from, to).round();
    return RouteSegment(
      title: '외부 간이 안내',
      path: [from, to],
      distanceMeters: distance,
      steps: [
        NavigationStep(
          instruction: '현재 위치에서 시설 입구 방향으로 이동하세요.',
          detail: '외부 라우팅 API 키가 없거나 연결할 수 없어 간이 경로를 표시합니다.',
          minutes: max(1, (distance / 60).ceil()),
          feature: AccessibilityFeature.outdoor,
        ),
      ],
    );
  }
}

abstract class IndoorGraphRepository {
  Future<IndoorFacilityGraph> loadGraph();
}

class FirestoreIndoorGraphRepository implements IndoorGraphRepository {
  FirestoreIndoorGraphRepository({
    required IndoorGraphRepository fallback,
    FirebaseFirestore? firestore,
  }) : _fallback = fallback,
       _firestore = firestore;

  factory FirestoreIndoorGraphRepository.withFallback() {
    return FirestoreIndoorGraphRepository(
      fallback: LocalIndoorGraphRepository(),
    );
  }

  final IndoorGraphRepository _fallback;
  final FirebaseFirestore? _firestore;

  @override
  Future<IndoorFacilityGraph> loadGraph() async {
    if (Firebase.apps.isEmpty) {
      return _fallback.loadGraph();
    }

    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final facility = await firestore
          .collection('facilities')
          .doc('default')
          .get();
      final nodes = await facility.reference.collection('nodes').get();
      final edges = await facility.reference.collection('edges').get();
      final destinations = await facility.reference
          .collection('destinations')
          .get();

      if (!facility.exists || nodes.docs.isEmpty || destinations.docs.isEmpty) {
        return _fallback.loadGraph();
      }

      return IndoorFacilityGraph(
        entryNodeId: (facility.data()?['entryNodeId'] as String?) ?? 'entrance',
        nodes: nodes.docs.map((doc) => _nodeFrom(doc.id, doc.data())).toList(),
        edges: edges.docs.map((doc) => _edgeFrom(doc.data())).toList(),
        destinations: destinations.docs
            .map((doc) => _destinationFrom(doc.id, doc.data()))
            .toList(),
      );
    } catch (_) {
      return _fallback.loadGraph();
    }
  }

  IndoorNode _nodeFrom(String id, Map<String, dynamic> data) {
    return IndoorNode(
      id: id,
      name: data['name'] as String? ?? id,
      floor: data['floor'] as String? ?? '1층',
      location: LatLng(
        (data['lat'] as num?)?.toDouble() ?? 37.5796,
        (data['lng'] as num?)?.toDouble() ?? 126.9990,
      ),
    );
  }

  IndoorEdge _edgeFrom(Map<String, dynamic> data) {
    return IndoorEdge(
      fromNodeId: data['from'] as String? ?? '',
      toNodeId: data['to'] as String? ?? '',
      feature: _featureFrom(data['type'] as String?),
      distanceMeters: (data['distanceMeters'] as num?)?.round() ?? 0,
      instruction: data['instruction'] as String? ?? '안내 경로를 따라 이동하세요.',
    );
  }

  CareDestination _destinationFrom(String id, Map<String, dynamic> data) {
    return CareDestination(
      id: id,
      name: data['name'] as String? ?? id,
      category: data['category'] as String? ?? '목적지',
      floor: data['floor'] as String? ?? '1층',
      landmark: data['landmark'] as String? ?? '',
      entryNodeId: data['entryNodeId'] as String? ?? 'entrance',
      location: LatLng(
        (data['lat'] as num?)?.toDouble() ?? 37.5796,
        (data['lng'] as num?)?.toDouble() ?? 126.9990,
      ),
    );
  }

  AccessibilityFeature _featureFrom(String? value) {
    return switch (value) {
      'elevator' => AccessibilityFeature.elevator,
      'escalator' => AccessibilityFeature.escalator,
      'stairs' => AccessibilityFeature.stairs,
      'ramp' => AccessibilityFeature.ramp,
      'outdoor' => AccessibilityFeature.outdoor,
      _ => AccessibilityFeature.walkway,
    };
  }
}

class LocalIndoorGraphRepository implements IndoorGraphRepository {
  static const graph = IndoorFacilityGraph(
    entryNodeId: 'entrance',
    nodes: [
      IndoorNode(
        id: 'entrance',
        name: '정문',
        floor: '1층',
        location: LatLng(37.5792, 126.9986),
      ),
      IndoorNode(
        id: 'lobby',
        name: '로비',
        floor: '1층',
        location: LatLng(37.5797, 126.9991),
      ),
      IndoorNode(
        id: 'elevator_1f',
        name: '엘리베이터 1층',
        floor: '1층',
        location: LatLng(37.5799, 126.9992),
      ),
      IndoorNode(
        id: 'elevator_2f',
        name: '엘리베이터 2층',
        floor: '2층',
        location: LatLng(37.5803, 126.9995),
      ),
      IndoorNode(
        id: 'escalator_1f',
        name: '에스컬레이터 1층',
        floor: '1층',
        location: LatLng(37.5796, 126.9994),
      ),
      IndoorNode(
        id: 'escalator_2f',
        name: '에스컬레이터 2층',
        floor: '2층',
        location: LatLng(37.5801, 126.9997),
      ),
      IndoorNode(
        id: 'stairs_1f',
        name: '계단 1층',
        floor: '1층',
        location: LatLng(37.5795, 126.9990),
      ),
      IndoorNode(
        id: 'stairs_2f',
        name: '계단 2층',
        floor: '2층',
        location: LatLng(37.5800, 126.9993),
      ),
      IndoorNode(
        id: 'reception',
        name: '접수',
        floor: '1층',
        location: LatLng(37.5797, 126.9992),
      ),
      IndoorNode(
        id: 'pharmacy',
        name: '약국',
        floor: '1층',
        location: LatLng(37.5794, 127.0002),
      ),
      IndoorNode(
        id: 'imaging',
        name: '영상의학과',
        floor: '2층',
        location: LatLng(37.5806, 126.9998),
      ),
      IndoorNode(
        id: 'lab',
        name: '검사실',
        floor: '2층',
        location: LatLng(37.5802, 127.0005),
      ),
      IndoorNode(
        id: 'parking',
        name: '주차 정산',
        floor: 'B1',
        location: LatLng(37.5786, 126.9978),
      ),
    ],
    edges: [
      IndoorEdge(
        fromNodeId: 'entrance',
        toNodeId: 'lobby',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 45,
        instruction: '정문에서 로비까지 평지 통로로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'lobby',
        toNodeId: 'reception',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 18,
        instruction: '로비 오른쪽 접수 창구로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'lobby',
        toNodeId: 'pharmacy',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 70,
        instruction: '로비에서 원무과 옆 약국 방향으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'lobby',
        toNodeId: 'elevator_1f',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 25,
        instruction: '로비에서 중앙 엘리베이터 앞으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'elevator_1f',
        toNodeId: 'elevator_2f',
        feature: AccessibilityFeature.elevator,
        distanceMeters: 8,
        instruction: '엘리베이터를 타고 2층으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'elevator_2f',
        toNodeId: 'imaging',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 55,
        instruction: '2층 엘리베이터 앞에서 영상의학과 방향으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'elevator_2f',
        toNodeId: 'lab',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 60,
        instruction: '2층 엘리베이터 앞에서 검사실 방향으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'lobby',
        toNodeId: 'escalator_1f',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 12,
        instruction: '로비에서 에스컬레이터 앞으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'escalator_1f',
        toNodeId: 'escalator_2f',
        feature: AccessibilityFeature.escalator,
        distanceMeters: 8,
        instruction: '에스컬레이터를 타고 2층으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'escalator_2f',
        toNodeId: 'imaging',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 35,
        instruction: '에스컬레이터에서 내려 영상의학과로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'lobby',
        toNodeId: 'stairs_1f',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 5,
        instruction: '로비 옆 계단 앞으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'stairs_1f',
        toNodeId: 'stairs_2f',
        feature: AccessibilityFeature.stairs,
        distanceMeters: 8,
        instruction: '계단을 이용해 2층으로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'stairs_2f',
        toNodeId: 'imaging',
        feature: AccessibilityFeature.walkway,
        distanceMeters: 20,
        instruction: '계단에서 내려 영상의학과로 이동하세요.',
      ),
      IndoorEdge(
        fromNodeId: 'entrance',
        toNodeId: 'parking',
        feature: AccessibilityFeature.ramp,
        distanceMeters: 120,
        instruction: '완만한 경사로를 따라 주차 정산소로 이동하세요.',
      ),
    ],
    destinations: [
      CareDestination(
        id: 'reception',
        name: '접수',
        category: '업무',
        floor: '1층',
        landmark: '정문 오른쪽 안내 데스크',
        location: LatLng(37.5797, 126.9992),
        entryNodeId: 'reception',
      ),
      CareDestination(
        id: 'pharmacy',
        name: '약국',
        category: '편의',
        floor: '1층',
        landmark: '원무과 옆',
        location: LatLng(37.5794, 127.0002),
        entryNodeId: 'pharmacy',
      ),
      CareDestination(
        id: 'imaging',
        name: '영상의학과',
        category: '진료',
        floor: '2층',
        landmark: '중앙 엘리베이터 앞',
        location: LatLng(37.5806, 126.9998),
        entryNodeId: 'imaging',
      ),
      CareDestination(
        id: 'lab',
        name: '검사실',
        category: '진료',
        floor: '2층',
        landmark: '채혈실 맞은편',
        location: LatLng(37.5802, 127.0005),
        entryNodeId: 'lab',
      ),
      CareDestination(
        id: 'parking',
        name: '주차 정산',
        category: '편의',
        floor: 'B1',
        landmark: '지하주차장 출구 앞',
        location: LatLng(37.5786, 126.9978),
        entryNodeId: 'parking',
      ),
    ],
  );

  @override
  Future<IndoorFacilityGraph> loadGraph() async => graph;
}
