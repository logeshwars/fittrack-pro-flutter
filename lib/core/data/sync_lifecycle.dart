import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_providers.dart';

/// Keeps the outbox draining: on app resume, on sign-in, and periodically.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _flush());
    WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
  }

  void _flush() {
    if (!mounted) return;
    final engine = ref.read(syncEngineProvider);
    if (engine != null) unawaited(engine.flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flush();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A new user id (sign-in / account switch) triggers an immediate flush.
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (next != null && next != previous) _flush();
    });
    return widget.child;
  }
}
