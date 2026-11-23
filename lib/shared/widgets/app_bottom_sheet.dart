import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icon_button.dart';
import 'app_button.dart';

/// The one sheet shell: drag handle, 28dp top radius, safe area, scrollable
/// body, optional pinned actions. Word detail, idiom detail, notes, add to
/// list, create list and the mix sheet all sit in it.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.title,
    this.description,
    this.headerAction,
    this.actions,
    this.showClose = true,
    this.scrollable = true,
    this.expand = false,
    this.scrollController,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? description;

  /// Sits left of the close button ("SAVED" on the note sheet).
  final Widget? headerAction;

  /// Pinned under the body, outside the scroll area.
  final Widget? actions;
  final bool showClose;
  final bool scrollable;

  /// A tall sheet whose body is the only thing that scrolls.
  final bool expand;
  final ScrollController? scrollController;

  bool get _hasHeader => title != null || description != null;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: child,
    );

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 6, Space.lg, Space.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(title!, style: MullType.sheetTitle.copyWith(color: c.onSurface)),
                if (description != null) ...<Widget>[
                  if (title != null) const SizedBox(height: 5),
                  Text(
                    description!,
                    style: MullType.bodySmall.copyWith(height: 1.5, color: c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          ?headerAction,
          if (showClose)
            AppIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
              semanticLabel: 'Close',
            ),
        ],
      ),
    );

    final Widget column = Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: Space.md),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: c.outline, borderRadius: Radii.fullR),
        ),
        const SizedBox(height: Space.sm),
        if (_hasHeader) ...<Widget>[
          header,
          if (expand) Divider(color: c.outline, height: 1),
        ],
        const SizedBox(height: Space.md),
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: scrollable
              ? SingleChildScrollView(controller: scrollController, child: body)
              : body,
        ),
        if (actions != null) ...<Widget>[
          if (expand) Divider(color: c.outline, height: 1),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: actions,
          ),
        ],
        const SizedBox(height: Space.screen),
      ],
    );

    final double h = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: expand
          ? BoxConstraints(minHeight: h * 0.9, maxHeight: h * 0.9)
          : BoxConstraints(maxHeight: h * 0.9),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.sheetR,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: column),
    );
  }
}

/// Opens [builder] in the shared sheet shell. Everything that presents a
/// sheet goes through here so none of them drift apart. Sheets never stack
/// more than two deep.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? description,
  Widget? headerAction,
  Widget? actions,
  bool showClose = true,
  bool expand = false,
  bool scrollable = true,
}) {
  // The root navigator, so a sheet covers the floating nav.
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  return nav.push(
    _SheetRoute<T>(
      capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
      barrierLabel: MaterialLocalizations.of(context).scrimLabel,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Scrim to 40%, HANDOFF `sheet.present`.
      modalBarrierColor: context.colors.onSurface.withValues(alpha: 0.4),
      sheetAnimationStyle: sheetStyle(context),
      // The sheet slides as one layer; its content is not repainted.
      builder: (BuildContext context) => RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: AppBottomSheet(
            title: title,
            description: description,
            headerAction: headerAction,
            actions: actions,
            showClose: showClose,
            expand: expand,
            scrollable: scrollable,
            child: Builder(builder: builder),
          ),
        ),
      ),
    ),
  );
}

/// Starts its slide once the sheet's first frame is built. Flutter starts the
/// clock on push, so a heavy first frame (the word sheet: 28 to 126 ms on the
/// AVD) spent the fastest part of the slide before anything showed, and the
/// sheet popped instead of sliding.
class _SheetRoute<T> extends ModalBottomSheetRoute<T> {
  _SheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.backgroundColor,
    super.modalBarrierColor,
    super.sheetAnimationStyle,
  });

  @override
  TickerFuture didPush() {
    final TickerFuture future = super.didPush();
    if (controller case final AnimationController c when c.isAnimating) {
      c.stop();
      WidgetsBinding.instance.endOfFrame.then((_) {
        // Popped or moved meanwhile: leave it.
        if (isActive && !c.isAnimating && c.value == 0 && c.status == AnimationStatus.forward) c.forward();
      });
    }
    return future;
  }
}

/// A confirmation that names what will be lost. Returns true on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final MullColors c = context.colors;
  final bool? ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    animationStyle: dialogStyle(context),
    barrierColor: c.onSurface.withValues(alpha: 0.4),
    builder: (BuildContext ctx) => Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.sheetR,
        side: BorderSide(color: c.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: MullType.sheetTitle.copyWith(color: c.onSurface)),
            const SizedBox(height: Space.md),
            Text(message, style: MullType.body.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Space.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: Space.sm,
              children: <Widget>[
                AppButton(
                  label: 'Cancel',
                  type: AppButtonType.secondary,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                AppButton(
                  label: confirmLabel,
                  type: AppButtonType.danger,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
