import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'appearance.dart';
import 'ambient_background.dart';
import 'api_client.dart';

/// Hosted Windows profile-mode probe. VM Service exports the same timeline
/// consumed by DevTools; no provider Key or user data is used here.
class PerformanceProbe extends StatefulWidget {
  const PerformanceProbe({super.key});
  @override
  State<PerformanceProbe> createState() => _PerformanceProbeState();
}

class _PerformanceProbeState extends State<PerformanceProbe> {
  final input = TextEditingController();
  final appearance = Appearance();
  final frames = <FrameTiming>[];
  final rows = List.generate(
      20,
      (i) => <String, dynamic>{
            'local_id': 'fixture-$i',
            'user': '测试消息$i',
            'reply': '嗯，我在。',
            'created_at': '2026-10-14T01:00:00Z'
          });
  bool busy = false;
  void timings(List<FrameTiming> values) => frames.addAll(values);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(timings);
    developer.registerExtension('ext.xinghui.benchmark', (_, args) async {
      final result = await measure();
      return developer.ServiceExtensionResponse.result(jsonEncode(result));
    });
  }

  Future<Map<String, dynamic>> measure() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    frames.clear();
    final before = ChatPage.listBuilds;
    final latency = <double>[];
    for (var i = 0; i < 40; i++) {
      final stopwatch = Stopwatch()..start();
      final task = developer.TimelineTask()
        ..start('input_to_frame', arguments: {'index': i});
      input.text += '星';
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      latency.add(stopwatch.elapsedMicroseconds / 1000);
      task.finish();
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
    final typingRebuilds = ChatPage.listBuilds - before;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final durations =
        frames.map((f) => f.totalSpan.inMicroseconds / 1000).toList();
    final builds =
        frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList();
    final rasters =
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList();
    double avg(List<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
    double worst(List<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final replyClock = Stopwatch()..start();
    final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8080', token: 'performance-fixture-local');
    final reply = await client
        .request('POST', '/chat', {'text': '测试你好', 'no_save': true});
    setState(() {
      rows.add({
        'local_id': 'fixture-reply',
        'user': '测试你好',
        'reply': reply['reply'],
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
    });
    await WidgetsBinding.instance.endOfFrame;
    final firstReplyMs = replyClock.elapsedMicroseconds / 1000;
    client.transport.close();
    final result = <String, dynamic>{
      'mode': 'Windows profile; VM Service / DevTools timeline',
      'typing_method':
          '40 controller editing updates, real EditableText layout/paint; no physical keyboard measurement',
      'first_reply_mock_ms': firstReplyMs,
      'samples': latency.length,
      'input_to_frame_avg_ms': avg(latency),
      'input_to_frame_worst_ms': worst(latency),
      'typing_list_rebuilds': typingRebuilds,
      'frames': frames.length,
      'frame_avg_ms': avg(durations),
      'frame_worst_ms': worst(durations),
      'build_avg_ms': avg(builds),
      'build_worst_ms': worst(builds),
      'raster_avg_ms': avg(rasters),
      'raster_worst_ms': worst(rasters)
    };
    final out = File(
        '${File(Platform.resolvedExecutable).parent.path}/performance-metrics.json');
    await out.writeAsString(jsonEncode(result), flush: true);
    return result;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(timings);
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: appearance.materialTheme,
      home: Scaffold(
          body: Stack(children: [
        Positioned.fill(child: AmbientBackground(appearance: appearance)),
        ChatPage(
            messages: ChatMessage.fromTurns(rows),
            controller: input,
            busy: busy,
            dark: appearance.dark,
            primary: appearance.skinColor('primary'),
            textColor: appearance.skinColor('text'),
            emptyText: '嗯。',
            onSend: () {},
            onAction: (_, __) async {})
      ])));
}
