import 'package:care_nav/src/navigation/local_navigation_repository.dart';
import 'package:care_nav/src/navigation/navigation_controller.dart';
import 'package:care_nav/src/navigation/navigation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationController', () {
    test('filters destinations by search query', () {
      final controller = NavigationController(LocalNavigationRepository());

      controller.updateQuery('약국');

      expect(controller.filteredDestinations, hasLength(1));
      expect(controller.filteredDestinations.single.name, '약국');
    });

    test('plans a route to a destination from the selected origin', () async {
      final controller = NavigationController(LocalNavigationRepository());
      final pharmacy = controller.destinations.firstWhere(
        (destination) => destination.name == '약국',
      );

      controller.updateOrigin('정문');
      await controller.selectDestination(pharmacy);

      expect(controller.activeRoute?.destination.name, '약국');
      expect(controller.activeRoute?.origin, '정문');
      expect(controller.activeRoute?.steps, isNotEmpty);
      expect(
        controller.activeRoute!.steps.map((step) => step.instruction).join(' '),
        contains('정문'),
      );
    });

    test(
      'elderly friendly routes prefer elevators over shorter stairs',
      () async {
        final controller = NavigationController(LocalNavigationRepository());
        final imaging = controller.destinations.firstWhere(
          (destination) => destination.name == '영상의학과',
        );

        await controller.selectDestination(imaging);

        final features = controller.activeRoute!.steps.map(
          (step) => step.feature,
        );
        expect(features, contains(AccessibilityFeature.elevator));
        expect(features, isNot(contains(AccessibilityFeature.stairs)));
      },
    );

    test('advances through route steps and completes navigation', () async {
      final controller = NavigationController(LocalNavigationRepository());
      final imaging = controller.destinations.firstWhere(
        (destination) => destination.name == '영상의학과',
      );

      await controller.selectDestination(imaging);

      while (!controller.isRouteComplete) {
        controller.advanceStep();
      }

      expect(controller.isRouteComplete, isTrue);
      expect(controller.currentInstruction, '목적지에 도착했습니다.');
    });
  });
}
