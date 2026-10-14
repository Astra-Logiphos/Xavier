import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_client.dart';
import 'theme_config.dart';

/// Cheap health requests only. Business state is refreshed by UI events.
class ConnectionMonitor with WidgetsBindingObserver {
  final ApiClient api;
  final void Function(bool) onChange;
  final Future<void> Function() onResume;
  Timer? timer;
  bool disposed = false, foreground = true, inFlight = false;
  int failures = 0;
  bool? last;
  ConnectionMonitor(this.api, this.onChange, this.onResume);
  void start() {
    WidgetsBinding.instance.addObserver(this);
    schedule();
  }

  void schedule() {
    timer?.cancel();
    if (disposed || !foreground || api.baseUrl.isEmpty) return;
    final delays =
        ThemeConfig.values['performance']['healthBackoffSeconds'] as List;
    timer = Timer(
        Duration(
            seconds:
                (delays[failures.clamp(0, delays.length - 1)] as num).toInt()),
        probe);
  }

  Future<void> probe() async {
    if (disposed || !foreground || inFlight || api.baseUrl.isEmpty) return;
    inFlight = true;
    bool healthy;
    try {
      healthy = (await api.request(
              'GET',
              '/health',
              null,
              Duration(
                  milliseconds:
                      ThemeConfig.number('performance', 'healthTimeoutMs')
                          .round())))['ok'] ==
          true;
    } catch (_) {
      healthy = false;
    }
    inFlight = false;
    if (disposed) return;
    failures = healthy ? 0 : failures + 1;
    if (foreground && healthy != last) {
      last = healthy;
      onChange(healthy);
    }
    schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = foreground;
    foreground = state == AppLifecycleState.resumed;
    if (foreground && !wasVisible) {
      failures = 0;
      onResume();
    }
    schedule();
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
