import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The toast: inverse surface, 180 ms in from the bottom edge, 140 ms out,
/// four-second undo window on anything destructive. Bookmarks and note saves
/// never raise one.
class SnackMessage {
  const SnackMessage({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  Duration get duration => actionLabel == null ? const Duration(seconds: 3) : const Duration(seconds: 4);
}

class _Entry {
  _Entry(this.message) : id = ++_seq;

  static int _seq = 0;
  final SnackMessage message;
  final int id;
}

abstract final class AppSnackbar {
  static final ValueNotifier<List<_Entry>> _entries = ValueNotifier<List<_Entry>>(const <_Entry>[]);
  static OverlayEntry? _layer;

  static void show(BuildContext context, SnackMessage message) {
    // One at a time: a new strip replaces whatever is up.
    _entries.value = <_Entry>[_Entry(message)];
    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;
    if (_layer == null || !_layer!.mounted) {
      _layer = OverlayEntry(builder: (BuildContext _) => const _SnackLayer());
      overlay.insert(_layer!);
    }
  }

  static void info(BuildContext context, String text) => show(context, SnackMessage(text: text));

  /// Something destructive, with its undo.
  static void undo(BuildContext context, String text, VoidCallback onUndo) =>
      show(context, SnackMessage(text: text, actionLabel: 'Undo', onAction: onUndo));

  static void _remove(int id) =>
      _entries.value = _entries.value.where((_Entry e) => e.id != id).toList(growable: false);
}

class _SnackLayer extends StatelessWidget {
  const _SnackLayer();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_Entry>>(
      valueListenable: AppSnackbar._entries,
      builder: (BuildContext context, List<_Entry> entries, Widget? _) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Positioned(
          left: Space.md,
          right: Space.md,
          // Above the floating nav pill.
          bottom: MediaQuery.paddingOf(context).bottom + 96,
          child: _AnimatedStrip(key: ValueKey<int>(entries.last.id), entry: entries.last),
        );
      },
    );
  }
}

class _AnimatedStrip extends StatefulWidget {
  const _AnimatedStrip({required this.entry, super.key});

  final _Entry entry;

  @override
  State<_AnimatedStrip> createState() => _AnimatedStripState();
}

class _AnimatedStripState extends State<_AnimatedStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.snackEnter,
    reverseDuration: Motion.snackExit,
  )..forward();
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.entry.message.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    if (mounted) await _enter.reverse();
    AppSnackbar._remove(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final SnackMessage m = widget.entry.message;
    final bool reduced = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _enter,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: _enter.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 16 * (1 - _enter.value)),
          child: child,
        ),
      ),
      child: Dismissible(
        key: ValueKey<int>(widget.entry.id),
        direction: DismissDirection.down,
        onDismissed: (_) => AppSnackbar._remove(widget.entry.id),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
              decoration: BoxDecoration(
                color: c.inverseSurface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                spacing: Space.md,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      m.text,
                      style: MullType.label.copyWith(fontSize: 13, color: c.onInverseSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (m.actionLabel != null)
                    TextButton(
                      onPressed: () {
                        m.onAction?.call();
                        unawaited(_dismiss());
                      },
                      child: Text(
                        m.actionLabel!.toUpperCase(),
                        style: MullType.label.copyWith(color: c.primary, letterSpacing: 0.24).weight(700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
