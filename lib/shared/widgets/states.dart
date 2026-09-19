import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_button.dart';

/// A small abstract stack of word cards. Never an illustration of a person,
/// never an emoji.
class MullMark extends StatelessWidget {
  const MullMark({this.danger = false, super.key});

  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    BoxDecoration slab({Color? fill, bool outlined = false}) => BoxDecoration(
      color: fill ?? c.surfaceContainer,
      borderRadius: Radii.chipR,
      border: outlined ? Border.all(color: danger ? c.danger : c.outline) : null,
    );
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: <Widget>[
          Positioned(left: 4, top: 6, child: Container(width: 56, height: 20, decoration: slab(fill: danger ? c.dangerContainer : c.primaryContainer))),
          Positioned(right: 0, top: 32, child: Container(width: 44, height: 20, decoration: slab(outlined: true))),
          Positioned(left: 12, bottom: 24, child: Container(width: 60, height: 20, decoration: slab(outlined: true))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: danger ? c.danger : c.primary,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing here yet: the display line, one or two sentences, one outlined
/// action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showMark = true,
    this.danger = false,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showMark;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 60, 34, Space.bottomSafe),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showMark) ...<Widget>[MullMark(danger: danger), const SizedBox(height: Space.xl)],
            Text(
              title,
              textAlign: TextAlign.center,
              style: MullType.display.copyWith(fontSize: 26, height: 1.2, color: c.onSurface),
            ),
            const SizedBox(height: Space.row),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MullType.body.copyWith(fontSize: 14.5, height: 1.6, color: c.onSurfaceVariant),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: Space.screen),
              AppButton(label: actionLabel!, onPressed: onAction, type: AppButtonType.outlined),
            ],
          ],
        ),
      ),
    );
  }
}

/// Same shape as empty, `danger` only on the icon, one retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: 'That did not load',
    message: message,
    danger: true,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// A 2dp `primary` hairline at 60% opacity, shown only if a query exceeds
/// 120 ms. No spinners, no skeleton shimmer in search. The wait is built in:
/// pass [visible] for the whole load and the hairline holds back on its own,
/// so a local query that answers in a frame never flashes it.
class LoadingHairline extends StatefulWidget {
  const LoadingHairline({required this.visible, super.key});

  final bool visible;

  static const Duration grace = Duration(milliseconds: 120);

  @override
  State<LoadingHairline> createState() => _LoadingHairlineState();
}

class _LoadingHairlineState extends State<LoadingHairline> {
  Timer? _grace;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LoadingHairline old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) _sync();
  }

  void _sync() {
    _grace?.cancel();
    if (widget.visible) {
      _grace = Timer(LoadingHairline.grace, () {
        if (mounted) setState(() => _shown = true);
      });
    } else {
      _shown = false;
    }
  }

  @override
  void dispose() {
    _grace?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: Motion.of(context, Motion.fast),
    opacity: _shown && widget.visible ? 0.6 : 0,
    child: Container(height: 2, color: context.colors.primary),
  );
}

/// A muted bar standing in for a line of text while a section settles.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({this.width = 120, this.height = 10, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHigh,
      borderRadius: Radii.chipR,
    ),
  );
}

/// A card the size and shape of a [TopicCard], holding its place until the
/// progress and shelf streams have emitted, so nothing jumps when they land.
/// Still, not shimmering: loading is never the dominant impression.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.minHeight = 96, super.key});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonLine(width: 30, height: 30),
          SizedBox(height: Space.row),
          SkeletonLine(width: 96, height: 12),
          SizedBox(height: Space.sm),
          SkeletonLine(width: 64, height: 9),
        ],
      ),
    );
  }
}

/// A row the size of a [BandRow] or [ListRow] inside a container.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    child: Row(
      spacing: Space.md,
      children: <Widget>[
        SkeletonLine(width: 12, height: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonLine(width: 110, height: 12),
              SizedBox(height: 6),
              SkeletonLine(width: 180, height: 9),
              SizedBox(height: Space.sm),
              SkeletonLine(width: double.infinity, height: 3),
            ],
          ),
        ),
      ],
    ),
  );
}
