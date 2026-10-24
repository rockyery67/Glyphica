import 'package:flutter/material.dart';

/// Reduced-motion feedback stays visible without a looping animation or a
/// fabricated progress percentage.
class WorkIndicator extends StatelessWidget {
  const WorkIndicator({super.key});
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? Semantics(
          label: 'Working',
          child: SizedBox(
            height: 2,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        )
      : const LinearProgressIndicator(minHeight: 2);
}
