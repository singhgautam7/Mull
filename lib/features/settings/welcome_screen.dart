import 'package:flutter/widgets.dart';

import '../onboarding/onboarding_flow.dart';

/// The `/welcome` route. The flow lives in `features/onboarding`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingFlow();
}
