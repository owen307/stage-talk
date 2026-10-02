import 'package:alpaca_stage_talk/src/alpaca_link.dart';
import 'package:alpaca_stage_talk/src/device_effects.dart';
import 'package:alpaca_stage_talk/src/envelope.dart';
import 'package:alpaca_stage_talk/src/stage_talk_page.dart';
import 'package:alpaca_stage_talk/src/talk_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('product name is Stage Talk and presets send', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final transport = _PageTransport();
    final controller = TalkController(
      transport: transport,
      prefs: await SharedPreferences.getInstance(),
      effects: DeviceEffects(),
    );
    await controller.start();
    await tester.pumpWidget(StageTalkApp(controller: controller));
    await tester.pump();

    expect(find.text('Stage Talk'), findsWidgets);
    expect(find.text('ALPACA'), findsNothing);
    expect(find.textContaining('Alpaca'), findsNothing);

    await tester.tap(find.byKey(const Key('preset-stand-by')));
    await tester.pump();
    expect(transport.sent.single.text, 'Stand by');
    expect(find.text('Stand by'), findsWidgets);

    await tester.tap(find.byKey(const Key('about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-title')), findsOneWidget);
    expect(find.text('Stage Talk'), findsWidgets);
    expect(find.textContaining('Alpaca Link'), findsOneWidget);
  });

  testWidgets('phone width keeps Stage Talk on one screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final controller = TalkController(
      transport: _PageTransport(),
      prefs: await SharedPreferences.getInstance(),
      effects: DeviceEffects(),
    );
    await controller.start();
    await tester.pumpWidget(StageTalkApp(controller: controller));
    await tester.pump();
    expect(find.byKey(const Key('product-title')), findsOneWidget);
    expect(find.text('ALPACA'), findsNothing);
    await tester.tap(find.byKey(const Key('preset-mic-2')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
  });
}

class _PageTransport implements TalkTransport {
  final sent = <TalkEnvelope>[];

  @override
  Stream<TalkEnvelope> get incoming => const Stream.empty();

  @override
  Future<LinkStatus> start() async {
    return const LinkStatus(ok: true, ips: ['127.0.0.1'], multicast: true);
  }

  @override
  int send(TalkEnvelope envelope) {
    sent.add(envelope);
    return 24;
  }

  @override
  Future<void> close() async {}
}
