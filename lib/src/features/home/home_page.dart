import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/auth_repository.dart';
import '../../navigation/local_navigation_repository.dart';
import '../../navigation/navigation_controller.dart';
import '../../navigation/navigation_models.dart';
import '../../routing/app_routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final NavigationController _navigationController;

  @override
  void initState() {
    super.initState();
    _navigationController = NavigationController(LocalNavigationRepository());
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authRepository,
      builder: (context, child) {
        final user = widget.authRepository.currentUser;
        final displayName = user?.email ?? '게스트';

        return Scaffold(
          appBar: AppBar(
            title: const Text('CareNav'),
            actions: [
              if (user == null)
                IconButton(
                  key: const ValueKey('goToLoginButton'),
                  tooltip: '로그인',
                  onPressed: () => context.go(AppRoutes.login),
                  icon: const Icon(Icons.login),
                )
              else
                IconButton(
                  key: const ValueKey('signOutButton'),
                  tooltip: '로그아웃',
                  onPressed: widget.authRepository.signOut,
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: _navigationController,
              builder: (context, child) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _WelcomeHeader(displayName: displayName),
                    const SizedBox(height: 16),
                    _LocationAssistPanel(controller: _navigationController),
                    const SizedBox(height: 12),
                    _OriginSelector(controller: _navigationController),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('destinationSearchField'),
                      decoration: const InputDecoration(
                        labelText: '어디로 갈까요?',
                        hintText: '목적지 하나만 입력하세요. 예: 영상의학과',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _navigationController.updateQuery,
                    ),
                    const SizedBox(height: 16),
                    _MapPanel(controller: _navigationController),
                    const SizedBox(height: 16),
                    if (_navigationController.errorMessage != null) ...[
                      _StatusMessage(
                        message: _navigationController.errorMessage!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_navigationController.isPlanning) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    if (_navigationController.hasActiveRoute) ...[
                      _RoutePanel(controller: _navigationController),
                      const SizedBox(height: 16),
                    ],
                    if (_navigationController.query.trim().isNotEmpty) ...[
                      Text(
                        '검색 결과',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (final destination
                        in _navigationController.filteredDestinations)
                      _DestinationTile(
                        destination: destination,
                        onTap: () => _navigationController.selectDestination(
                          destination,
                        ),
                      ),
                    if (_navigationController.query.trim().isNotEmpty &&
                        _navigationController.filteredDestinations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Text('검색 결과가 없습니다.')),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LocationAssistPanel extends StatelessWidget {
  const _LocationAssistPanel({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('useGpsButton'),
      onPressed: controller.useGpsLocation,
      icon: const Icon(Icons.gps_fixed),
      label: const Text('현재 위치 사용'),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('routePanel'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    final route = controller.activeRoute;
    final routeColor = Theme.of(context).colorScheme.primary;
    final markerColor = Theme.of(context).colorScheme.error;
    final origin = route?.originLocation ?? const LatLng(37.5796, 126.9990);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: route?.destination.location ?? origin,
            initialZoom: route == null ? 16 : 17,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.care_nav',
            ),
            if (route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.path,
                    color: routeColor,
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: origin,
                  width: 44,
                  height: 44,
                  child: _MapMarker(
                    icon: Icons.my_location,
                    color: routeColor,
                    label: '출발',
                  ),
                ),
                for (final destination in controller.filteredDestinations)
                  Marker(
                    point: destination.location,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      key: ValueKey('mapMarker-${destination.id}'),
                      onTap: () => controller.selectDestination(destination),
                      child: _MapMarker(
                        icon: Icons.place,
                        color: markerColor,
                        label: destination.name,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.navigation_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('홈', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('$displayName 님, 목적지를 선택하면 바로 안내합니다.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginSelector extends StatelessWidget {
  const _OriginSelector({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: controller.origin,
      decoration: const InputDecoration(
        labelText: '출발 위치',
        prefixIcon: Icon(Icons.my_location),
        border: OutlineInputBorder(),
      ),
      items: [
        for (final origin in controller.origins)
          DropdownMenuItem(value: origin, child: Text(origin)),
      ],
      onChanged: (value) {
        if (value != null) {
          controller.updateOrigin(value);
        }
      },
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    final route = controller.activeRoute!;
    final step = controller.currentStep;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '경로 안내',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${route.distanceMeters}m · ${route.totalMinutes}분'),
              ],
            ),
            const SizedBox(height: 12),
            Text('${route.origin} → ${route.destination.name}'),
            const SizedBox(height: 8),
            Text(route.accessibilitySummary),
            if (route.usedFallback) ...[
              const SizedBox(height: 4),
              const Text('일부 구간은 설정된 실제 API 대신 안전한 간이 안내로 표시됩니다.'),
            ],
            const SizedBox(height: 12),
            Text(
              controller.currentInstruction,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (step != null) ...[const SizedBox(height: 4), Text(step.detail)],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: route.steps.isEmpty
                  ? 1
                  : controller.currentStepIndex / route.steps.length,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.clearRoute,
                    icon: const Icon(Icons.close),
                    label: const Text('종료'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('nextStepButton'),
                    onPressed: controller.isRouteComplete
                        ? null
                        : controller.advanceStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('다음'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.onTap});

  final CareDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: ValueKey('destinationTile-${destination.id}'),
        leading: CircleAvatar(
          child: Text(destination.floor.replaceAll('층', '')),
        ),
        title: Text(destination.name),
        subtitle: Text('${destination.category} · ${destination.landmark}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
