// End-to-end journeys through the example app's full navigation topology.
// These cover the paths that are risky to change in the package itself:
// overlay-mode details under nested tab routers, URL sync, resize-across-
// breakpoint state preservation, and selectedIdExists auto-dismiss.

import 'package:morph_kit/morph_kit.dart';
import 'package:morph_kit_example/main.dart';
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

    testWidgets('typed text survives the dialog ↔ sheet swap on resize', (
      tester,
    ) async {
      await pumpApp(tester, size: expanded);

      await tester.tap(find.text('New ticket'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Half-typed title');

      // Shrink across the breakpoint: the dialog route is atomically
      // replaced by a real bottom sheet route — same content element.
      await resize(tester, compact);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Half-typed title'), findsOneWidget);

      // Grow back: sheet becomes a dialog again, text still intact.
      await resize(tester, expanded);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Half-typed title'), findsOneWidget);

      // The result future survived both swaps: create → navigates.
      await tester.tap(find.text('Create ticket'));
      await tester.pumpAndSettle();
      expect(find.byType(TicketPane), findsOneWidget);
      expect(
        rootRouter(tester).currentPath,
        startsWith('/work/tickets/ticket-'),
      );
    });
  });

  group('package settings', () {
    testWidgets(
      'route mode: expanded detail, leave via TOP TABS, shrink, return → routed',
      (tester) async {
        addTearDown(() {
          PackageSettings.instance.update(
            (s) => s.compactDetailMode = CompactDetailMode.overlay,
          );
        });
        await pumpApp(tester, size: expanded);

        // The mode is flipped on the RUNNING app via the ⚙ panel — live
        // layouts must wire route mode in didUpdateWidget, not initState.
        await tester.tap(find.byTooltip('Package settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('route'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Webhook drops events'));
        await tester.pumpAndSettle();
        expect(find.byType(TicketPane), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(TicketPane),
            matching: find.byType(TextField),
          ),
          'draft comment',
        );
        await tester.pump();

        // Leave through the top tab bar (TabBarView detaches Tickets).
        await tester.tap(find.text('Directory'));
        await tester.pumpAndSettle();

        await resize(tester, compact);

        await tester.tap(find.text('Tickets'));
        await tester.pumpAndSettle();

        final rootNavigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        expect(find.byType(TicketPane), findsOneWidget);
        expect(rootNavigator.canPop(), isTrue); // routed, never inline
        // The pane instance survived hide → hidden resize → routed return.
        expect(find.text('draft comment'), findsOneWidget);
      },
    );

    testWidgets(
      'route mode: expanded detail, leave via NAV RAIL, shrink, return → routed',
      (tester) async {
        PackageSettings.instance.update(
          (s) => s.compactDetailMode = CompactDetailMode.route,
        );
        addTearDown(() {
          PackageSettings.instance.update(
            (s) => s.compactDetailMode = CompactDetailMode.overlay,
          );
        });
        await pumpApp(tester, size: expanded);

        await tester.tap(find.text('Webhook drops events'));
        await tester.pumpAndSettle();
        expect(find.byType(TicketPane), findsOneWidget);

        // Leave through the primary destinations (IndexedStack keeps Work
        // mounted and laid out, just unpainted).
        await tester.tap(find.text('Ops'));
        await tester.pumpAndSettle();

        await resize(tester, compact);

        // Back via the bottom nav (compact width now).
        await tester.tap(find.text('Work'));
        await tester.pumpAndSettle();

        final rootNavigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        expect(find.byType(TicketPane), findsOneWidget);
        expect(rootNavigator.canPop(), isTrue); // routed, never inline
      },
    );

    testWidgets('route mode gives the compact detail a real page route', (
      tester,
    ) async {
      addTearDown(() {
        PackageSettings.instance.update(
          (s) => s.compactDetailMode = CompactDetailMode.overlay,
        );
      });
      await pumpApp(tester, size: compact);

      // Flip the mode from the ⚙ panel (itself an adaptive modal).
      await tester.tap(find.byTooltip('Package settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('route'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute(); // close the panel
      await tester.pumpAndSettle();

      final rootNavigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      expect(rootNavigator.canPop(), isFalse);

      await tester.tap(find.text('Webhook drops events'));
      await tester.pumpAndSettle();
      expect(find.byType(TicketPane), findsOneWidget);
      expect(rootRouter(tester).currentPath, '/work/tickets/ticket-hooks');
      // The distinguishing observable vs overlay mode: a REAL route now
      // sits on the root navigator. (Overlay mode would pass the back
      // assertions below via PopScope — this is what proves route-ness.)
      expect(rootNavigator.canPop(), isTrue);

      // The status strip lives in MaterialApp.builder — above the
      // Navigator — so the pushed detail cannot cover it and its actions
      // stay live. Opening the panel proves it is on top and tappable.
      await tester.tap(find.byTooltip('Package settings'));
      await tester.pumpAndSettle();
      expect(find.text('Layout'), findsOneWidget);
      await tester.binding.handlePopRoute(); // close the panel
      await tester.pumpAndSettle();
      expect(find.byType(TicketPane), findsOneWidget); // detail still routed

      // REAL system back pops the real route; the URL syncs through the
      // controller exactly as in the other modes.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TicketPane), findsNothing);
      expect(rootRouter(tester).currentPath, '/work/tickets');
    });
  });
}
