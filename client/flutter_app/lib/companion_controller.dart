import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_client.dart';

class CompanionController with WidgetsBindingObserver {
  final ApiClient api;
  final void Function(List<Map<String, dynamic>>) onEvents;
  final Stopwatch active = Stopwatch()..start();
  final String session = DateTime.now().microsecondsSinceEpoch.toString();
  Timer? timer;
  bool visible = true, pending = false, disposed = false;
  int interval = 60;
  CompanionController(this.api, this.onEvents);
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final config = await api.request('GET', '/companion/config');
      interval = (config['tick_seconds'] as num).round();
      await tick('open');
    } catch (_) {}
    schedule();
  }

  void schedule() {
    timer?.cancel();
    if (!disposed && visible) {
      timer = Timer(Duration(seconds: interval), () async {
        await tick('tick');
        schedule();
      });
    }
  }

  Future<void> tick(String event) async {
    if (disposed || !visible || pending || api.baseUrl.isEmpty) return;
    pending = true;
    try {
      final result = await api.request('POST', '/companion/tick', {
        'event': event,
        'session_id': session,
        'active_seconds': active.elapsed.inSeconds
      });
      interval = (result['next_check_seconds'] as num? ?? interval)
          .ceil()
          .clamp(1, 86400);
      if (!disposed) {
        onEvents(List<Map<String, dynamic>>.from(result['events']));
      }
    } catch (_) {
    } finally {
      pending = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    visible = state == AppLifecycleState.resumed;
    if (visible) {
      active.start();
      unawaited(tick('tick'));
      schedule();
    } else {
      active.stop();
      timer?.cancel();
    }
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    active.stop();
    WidgetsBinding.instance.removeObserver(this);
  }
}
