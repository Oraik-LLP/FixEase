import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/subscription/paywall_screen.dart';
import '../screens/vehicle/add_vehicle_screen.dart';
import '../screens/vehicle/my_vehicles_screen.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import 'neuomorphic.dart';

/// Side menu (reference-style hamburger) — switches main tabs and holds future links.
class FixEaseDrawer extends StatelessWidget {
  const FixEaseDrawer({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectTab;

  static const _items = <({int index, IconData icon, String label})>[
    (index: 0, icon: Icons.home_rounded, label: 'Home'),
    (index: 1, icon: Icons.support_rounded, label: 'Diagnose'),
    (index: 2, icon: Icons.insights_rounded, label: 'Reports'),
    (index: 3, icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/logo/fixease_logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.build_rounded,
                          color: AppColors.accent,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FixEase',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Car diagnostics',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Color(0x22FFFFFF), height: 1),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final item in _items)
                    _DrawerTile(
                      icon: item.icon,
                      label: item.label,
                      selected: currentIndex == item.index,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelectTab(item.index);
                      },
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: NeuPane(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'More',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          _DrawerLink(
                            icon: Icons.directions_car_rounded,
                            label: 'My vehicles',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const MyVehiclesScreen(),
                                ),
                              );
                            },
                          ),
                          _DrawerLink(
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Add vehicle',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AddVehicleScreen(),
                                ),
                              );
                            },
                          ),
                          _DrawerLink(
                            icon: Icons.workspace_premium_rounded,
                            label: SubscriptionService.instance.tier ==
                                    SubscriptionTier.free
                                ? 'Upgrade plan'
                                : SubscriptionService.instance.tierLabel,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PaywallScreen(),
                                ),
                              );
                            },
                          ),
                          _DrawerLink(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & safety',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.accent.withValues(alpha: 0.18)
        : Colors.transparent;
    final fg = selected ? AppColors.accent : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Icon(icon, color: fg, size: 24),
          title: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15,
              letterSpacing: -0.2,
              color: selected ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
