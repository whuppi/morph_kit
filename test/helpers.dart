import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a [MaterialApp] with the window sized to [size]
/// logical pixels (device pixel ratio 1.0, reset on teardown).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1000, 800),
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(textDirection: textDirection, child: child),
    ),
  );
}

/// Resizes the test window and pumps until settled.
Future<void> resizeWindow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// A stateful pane that proves instance survival: shows `count: N` and
/// increments on tap. If the widget is rebuilt from scratch, the count
/// resets to zero — so a surviving count proves reparenting.
class CounterPane extends StatefulWidget {
  const CounterPane({super.key, this.label = 'count'});

  final String label;

  @override
  State<CounterPane> createState() => _CounterPaneState();
}

class _CounterPaneState extends State<CounterPane> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count++),
      child: ColoredBox(
        color: const Color(0xFF222222),
        child: Center(child: Text('${widget.label}: $_count')),
      ),
    );
  }
}
