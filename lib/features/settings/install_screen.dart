import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// HANDOFF 3.14, install state: a quiet full-screen moment with a display
/// line and a sentence. No percentage, no progress bar, no cancel.
class InstallScreen extends StatelessWidget {
  const InstallScreen({this.entryCount, super.key});

  /// The bundled entry count, when known before the install starts.
  final int? entryCount;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final String count = entryCount == null ? 'Every entry' : '$entryCount entries';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Setting the dictionary down on your phone.',
                style: MullType.display.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: Space.lg),
              Text(
                '$count, unpacked once. After this it never needs the network again.',
                style: MullType.body.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
