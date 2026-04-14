import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.requiredFeature});
  final String? requiredFeature;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  SubscriptionTier _selected = SubscriptionTier.premium;
  bool _purchasing = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final current = SubscriptionService.instance.tier;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    FixEaseStepBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (current != SubscriptionTier.free)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.accent.withValues(alpha: 0.15),
                        ),
                        child: Text(
                          SubscriptionService.instance.tierLabel,
                          style: tt.bodySmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.accent,
                                    AppColors.accent.withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 32,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text('Upgrade FixEase',
                                style: tt.headlineMedium),
                            const SizedBox(height: 6),
                            if (widget.requiredFeature != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFFFF9800)
                                      .withValues(alpha: 0.15),
                                ),
                                child: Text(
                                  '${widget.requiredFeature} requires an upgrade',
                                  style: tt.bodySmall?.copyWith(
                                    color: const Color(0xFFFF9800),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Text(
                                'Unlock unlimited diagnostics and premium features',
                                style: tt.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      for (final plan in SubscriptionService.plans) ...[
                        _PlanCard(
                          plan: plan,
                          isSelected: _selected == plan.tier,
                          isCurrent: current == plan.tier,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = plan.tier);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 8),

                      // comparison table
                      _ComparisonTable(),

                      const SizedBox(height: 24),

                      if (_selected != current)
                        _purchasing
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.accent,
                                  ),
                                ),
                              )
                            : NeuPrimaryButton(
                                label: _selected == SubscriptionTier.free
                                    ? 'Downgrade to Free'
                                    : 'Subscribe to ${SubscriptionService.plans.where((p) => p.tier == _selected).firstOrNull?.name ?? 'Plan'}',
                                icon: Icons.rocket_launch_rounded,
                                onPressed: _handlePurchase,
                              )
                      else
                        Center(
                          child: NeuPane(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 18, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Text('This is your current plan',
                                    style: tt.bodyMedium?.copyWith(
                                        color: AppColors.accent)),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await SubscriptionService.instance.restore();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.surface,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                content:
                                    const Text('Purchases restored'),
                              ),
                            );
                          },
                          child: Text('Restore Purchases',
                              style: tt.bodySmall?.copyWith(
                                  color: AppColors.textTertiary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    HapticFeedback.heavyImpact();
    setState(() => _purchasing = true);

    bool success = false;
    try {
      success = await SubscriptionService.instance.purchase(_selected);
    } catch (_) {
      // Purchase failed
    }

    if (!mounted) return;
    setState(() => _purchasing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            _selected == SubscriptionTier.free
                ? 'Downgraded to Free'
                : 'Welcome to ${SubscriptionService.instance.tierLabel}!',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Plan card
// ═══════════════════════════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });
  final PlanInfo plan;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final borderColor = isSelected
        ? AppColors.accent
        : isCurrent
            ? AppColors.accent.withValues(alpha: 0.3)
            : const Color(0x0CFFFFFF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.surface,
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 0.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.name, style: tt.titleLarge),
                          if (plan.badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: plan.recommended
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : const Color(0xFFFFC107)
                                        .withValues(alpha: 0.2),
                              ),
                              child: Text(
                                plan.badge!,
                                style: tt.bodySmall?.copyWith(
                                  color: plan.recommended
                                      ? AppColors.accent
                                      : const Color(0xFFFFC107),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.2),
                              ),
                              child: Text(
                                'CURRENT',
                                style: tt.bodySmall?.copyWith(
                                  color: const Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: plan.price,
                              style: tt.headlineMedium?.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                            TextSpan(
                              text: plan.interval,
                              style: tt.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textTertiary,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? AppColors.accent
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.features
                  .map((f) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(f,
                                style: tt.bodySmall?.copyWith(fontSize: 11)),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Comparison table
// ═══════════════════════════════════════════════════════════════════════════════

class _ComparisonTable extends StatelessWidget {
  static const _rows = <(String, String, String, String)>[
    ('Diagnostics/mo', '3', '25', 'Unlimited'),
    ('Photos/diagnosis', '2', '8', 'Unlimited'),
    ('Vehicles', '1', '5', 'Unlimited'),
    ('Radar chart', '—', 'Yes', 'Yes'),
    ('PDF export', '—', 'Yes', 'Yes'),
    ('Gemini Live', '—', '—', 'Yes'),
    ('Priority support', '—', '—', 'Yes'),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan Comparison', style: tt.titleMedium),
          const SizedBox(height: 14),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  _HeaderCell('Free'),
                  _HeaderCell('Premium'),
                  _HeaderCell('Pro'),
                ],
              ),
              for (final row in _rows)
                TableRow(
                  children: [
                    _LabelCell(row.$1),
                    _ValueCell(row.$2),
                    _ValueCell(row.$3, highlight: row.$3 != '—'),
                    _ValueCell(row.$4, highlight: row.$4 != '—'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _LabelCell extends StatelessWidget {
  const _LabelCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontSize: 11)),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: text == '—'
                  ? AppColors.textTertiary
                  : highlight
                      ? AppColors.accent
                      : AppColors.textPrimary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
