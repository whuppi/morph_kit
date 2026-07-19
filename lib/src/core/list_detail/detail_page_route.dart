import 'package:flutter/material.dart';

/// The real page route that presents the detail in
/// `CompactDetailMode.route`.
///
/// Uses [MaterialRouteTransitionMixin] — the exact transition machinery
/// [MaterialPageRoute] runs on — so the app's [PageTransitionsTheme]
/// applies: platform transitions, predictive back, Cupertino edge swipes,
/// none of it reimplemented here. A plain [PageRoute] base (instead of
/// [MaterialPageRoute] itself) only because that class asserts
/// `opaque == true`, and this route must not be opaque.
class DetailPageRoute extends PageRoute<void>
    with MaterialRouteTransitionMixin<void> {
  /// Creates the detail route.
  DetailPageRoute({
    required WidgetBuilder builder,
    this.instantEntrance = false,
  }) : _builder = builder;

  final WidgetBuilder _builder;

  /// Skips the entrance animation for pushes that restore an
  /// already-visible detail (resize swaps, deep links, tab re-shows).
  /// Exits always animate for real.
  final bool instantEntrance;

  @override
  Widget buildContent(BuildContext context) => _builder(context);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      instantEntrance ? Duration.zero : super.transitionDuration;

  /// Non-opaque so the layout below keeps painting: the paint-visibility
  /// probe is what detects "this tab was navigated away from under the
  /// route" — an opaque route would blind the probe and un-paint the very
  /// layout that owns the route, suppressing it in a loop.
  @override
  bool get opaque => false;
}
