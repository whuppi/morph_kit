// End-to-end journeys through the example app's full navigation topology.
// These cover the paths that are risky to change in the package itself:
// overlay-mode details under nested tab routers, URL sync, resize-across-
// breakpoint state preservation, and selectedIdExists auto-dismiss.

import 'package:adaptive_layouts_example/main.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' hide ModalRoute;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  StackRouter rootRouter(WidgetTester tester) =>
      tester.element(find.byType(RootShellScreen)).router.root;

  const expanded = Size(1200, 800);
  const compact = Size(420, 800);

  group('expanded (side-by-side)', () {
    testWidgets('boots into tickets list with empty detail pane', (
      tester,
    ) async {
      await pumpApp(tester, size: expanded);

      expect(find.text('Webhook drops events'), findsOneWidget);
      expect(find.text('Select a ticket'), findsOneWidget);
      // Rail, not bottom nav, at this width.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets(
      'selecting a ticket opens the side-by-side detail and syncs URL',
      (tester) async {
        await pumpApp(tester, size: expanded);

        await tester.tap(find.text('Webhook drops events'));
        await tester.pumpAndSettle();

        expect(find.byType(TicketPane), findsOneWidget);
        expect(rootRouter(tester).currentPath, '/work/tickets/ticket-hooks');

        // Close via the X (side-by-side affordance).
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(TicketPane), findsNothing);
        expect(rootRouter(tester).currentPath, '/work/tickets');
      },
    );
  });

  group('compact (overlay)', () {
    testWidgets('detail slides over and back dismisses', (tester) async {
      await pumpApp(tester, size: compact);

      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.text('Webhook drops events'));
      await tester.pumpAndSettle();

      expect(find.byType(TicketPane), findsOneWidget);
      expect(rootRouter(tester).currentPath, '/work/tickets/ticket-hooks');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(TicketPane), findsNothing);
      expect(rootRouter(tester).currentPath, '/work/tickets');
    });

    testWidgets(
      'overlay is suppressed when another domain takes over (URL navigation)',
      (tester) async {
        await pumpApp(tester, size: compact);

        await tester.tap(find.text('Webhook drops events'));
        await tester.pumpAndSettle();
        expect(find.byType(TicketPane), findsOneWidget);

        // Navigate away by URL while the ticket overlay is open. The tickets
        // tab stays mounted (tab router preserves state) — its overlay must not
        // linger over the ops domain.
        rootRouter(tester).navigatePath('/ops/monitor');
        await tester.pumpAndSettle();
        // One extra frame for paint-visibility suppression to settle.
        await tester.pump();

        expect(find.text('Idle — no active deploy'), findsOneWidget);
        expect(find.byType(TicketPane), findsNothing);
      },
    );
  });

  group('resize across the breakpoint', () {
    testWidgets('detail pane state survives expanded ↔ compact', (
      tester,
    ) async {
      await pumpApp(tester, size: expanded);

      await tester.tap(find.text('Webhook drops events'));
      await tester.pumpAndSettle();

      // Type a comment draft without posting it.
      await tester.enterText(find.byType(TextField), 'draft in progress');
      await tester.pump();

      await resize(tester, compact);
      expect(find.byType(TicketPane), findsOneWidget);
      expect(find.text('draft in progress'), findsOneWidget);

      await resize(tester, expanded);
      expect(find.byType(TicketPane), findsOneWidget);
      expect(find.text('draft in progress'), findsOneWidget);
    });
  });

  group('directory segments', () {
    testWidgets('chips switch segments and move the highlight', (tester) async {
      await pumpApp(tester, size: expanded);

      await tester.tap(find.text('Directory'));
      await tester.pumpAndSettle();
      expect(find.text('Noah'), findsOneWidget);

      await tester.tap(find.text('Teams'));
      await tester.pumpAndSettle();

      // Teams content shown, people content gone.
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Noah'), findsNothing);

      // The tapped chip is now the highlighted one (filled icon variant).
      expect(find.byIcon(Icons.groups), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });

  group('selectedIdExists', () {
    testWidgets('deleting the open entity auto-dismisses its detail', (
      tester,
    ) async {
      await pumpApp(tester, size: expanded);

      // Directory > People segment.
      await tester.tap(find.text('Directory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noah'));
      await tester.pumpAndSettle();
      expect(find.byType(DemoDetailPane), findsOneWidget);

      await tester.tap(find.text('Delete (auto-dismisses this pane)'));
      await tester.pumpAndSettle();

      expect(find.byType(DemoDetailPane), findsNothing);
      expect(find.text('Noah'), findsNothing);
    });
  });

  group('modals', () {
    testWidgets('new ticket modal creates a ticket and navigates into it', (
      tester,
    ) async {
      await pumpApp(tester, size: expanded);

      await tester.tap(find.text('New ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Create ticket'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Flaky sync test');
      await tester.tap(find.text('Create ticket'));
      await tester.pumpAndSettle();

      // Modal gone, new ticket selected in the list-detail.
      expect(find.text('Create ticket'), findsNothing);
      expect(find.byType(TicketPane), findsOneWidget);
      expect(
        rootRouter(tester).currentPath,
        startsWith('/work/tickets/ticket-'),
      );
    });
  });
}
