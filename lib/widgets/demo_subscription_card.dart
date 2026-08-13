import 'package:flutter/material.dart';

import '../services/subscription_service.dart';
import '../services/theme_service.dart';
import 'neuomorphic.dart';

/// Demo-only control to switch Mock_Free / Mock_Pass / Mock_Pro tiers.
class DemoSubscriptionCard extends StatelessWidget {
  const DemoSubscriptionCard({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final DemoSubscriptionState state;
  final Future<void> Function(DemoSubscriptionState state) onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return NeuPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo subscription tier', style: tt.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Switch mock entitlement states to test free, pass, and pro gates.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in DemoSubscriptionState.values)
                ChoiceChip(
                  label: Text(_label(option)),
                  selected: option == state,
                  onSelected: (_) => onChanged(option),
                  selectedColor:
                      FxColors.accent(context).withValues(alpha: 0.16),
                  backgroundColor:
                      FxColors.surfaceHighlight(context).withValues(alpha: 0.35),
                  labelStyle: tt.bodySmall?.copyWith(
                    color: option == state
                        ? FxColors.accent(context)
                        : FxColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(DemoSubscriptionState state) => switch (state) {
        DemoSubscriptionState.mockFree => 'Mock_Free',
        DemoSubscriptionState.mockPass => 'Mock_Pass',
        DemoSubscriptionState.mockPro => 'Mock_Pro',
      };
}
