import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';

enum SubscriptionTier { free, premium, pro }

class PlanInfo {
  const PlanInfo({
    required this.tier,
    required this.name,
    required this.price,
    required this.interval,
    required this.features,
    required this.limits,
    this.badge,
    this.recommended = false,
  });

  final SubscriptionTier tier;
  final String name;
  final String price;
  final String interval;
  final List<String> features;
  final PlanLimits limits;
  final String? badge;
  final bool recommended;
}

class PlanLimits {
  const PlanLimits({
    required this.diagnosticsPerMonth,
    required this.photosPerDiagnosis,
    required this.hasRadarChart,
    required this.hasGeminiLive,
    required this.hasExportPdf,
    required this.hasPrioritySupport,
    required this.hasMultiVehicle,
  });

  final int diagnosticsPerMonth;
  final int photosPerDiagnosis;
  final bool hasRadarChart;
  final bool hasGeminiLive;
  final bool hasExportPdf;
  final bool hasPrioritySupport;
  final bool hasMultiVehicle;
}

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  SubscriptionTier _tier = SubscriptionTier.free;
  int _diagnosticsThisMonth = 0;
  DateTime _monthStart = DateTime(DateTime.now().year, DateTime.now().month);

  SubscriptionTier get tier => _tier;
  PlanInfo get currentPlan => plans.firstWhere((p) => p.tier == _tier);
  PlanLimits get limits => currentPlan.limits;
  int get diagnosticsThisMonth => _diagnosticsThisMonth;
  int get diagnosticsRemaining =>
      (limits.diagnosticsPerMonth - _diagnosticsThisMonth)
          .clamp(0, limits.diagnosticsPerMonth);
  bool get isUnlimited => limits.diagnosticsPerMonth >= 9999;

  bool get canDiagnose =>
      _diagnosticsThisMonth < limits.diagnosticsPerMonth;

  String get tierLabel => switch (_tier) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.premium => 'Premium',
        SubscriptionTier.pro => 'Pro',
      };

  String get tierBadge => switch (_tier) {
        SubscriptionTier.free => '',
        SubscriptionTier.premium => 'PRO',
        SubscriptionTier.pro => 'ELITE',
      };

  static const plans = <PlanInfo>[
    PlanInfo(
      tier: SubscriptionTier.free,
      name: 'Free',
      price: '\$0',
      interval: 'forever',
      badge: null,
      features: [
        '3 diagnostics per month',
        'Up to 2 photos per diagnosis',
        'Basic health scores',
        'Symptom-based analysis',
        '1 vehicle',
      ],
      limits: PlanLimits(
        diagnosticsPerMonth: 3,
        photosPerDiagnosis: 2,
        hasRadarChart: false,
        hasGeminiLive: false,
        hasExportPdf: false,
        hasPrioritySupport: false,
        hasMultiVehicle: false,
      ),
    ),
    PlanInfo(
      tier: SubscriptionTier.premium,
      name: 'Premium',
      price: '\$4.99',
      interval: '/month',
      badge: 'POPULAR',
      recommended: true,
      features: [
        '25 diagnostics per month',
        'Up to 8 photos per diagnosis',
        'Radar health chart',
        'Detailed component breakdown',
        'Up to 5 vehicles',
        'Export PDF reports',
      ],
      limits: PlanLimits(
        diagnosticsPerMonth: 25,
        photosPerDiagnosis: 8,
        hasRadarChart: true,
        hasGeminiLive: false,
        hasExportPdf: true,
        hasPrioritySupport: false,
        hasMultiVehicle: true,
      ),
    ),
    PlanInfo(
      tier: SubscriptionTier.pro,
      name: 'Pro',
      price: '\$9.99',
      interval: '/month',
      badge: 'BEST VALUE',
      features: [
        'Unlimited diagnostics',
        'Unlimited photos',
        'Gemini Live video diagnosis',
        'Radar + advanced analytics',
        'Unlimited vehicles',
        'Export PDF reports',
        'Priority AI processing',
        'Priority support',
      ],
      limits: PlanLimits(
        diagnosticsPerMonth: 9999,
        photosPerDiagnosis: 99,
        hasRadarChart: true,
        hasGeminiLive: true,
        hasExportPdf: true,
        hasPrioritySupport: true,
        hasMultiVehicle: true,
      ),
    ),
  ];

  void recordDiagnosis() {
    _resetMonthIfNeeded();
    _diagnosticsThisMonth++;
    notifyListeners();
    _syncToRemote();
  }

  /// Simulate a purchase — in production, this is driven by Google Play Billing callback.
  Future<bool> purchase(SubscriptionTier newTier) async {
    _tier = newTier;
    notifyListeners();
    await _syncToRemote();
    return true;
  }

  Future<void> restore() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final uid = SupabaseConfig.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await SupabaseConfig.client
          .from('subscriptions')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row != null) {
        _tier = SubscriptionTier.values.byName(
            row['tier'] as String? ?? 'free');
        _diagnosticsThisMonth = row['diagnostics_used'] as int? ?? 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _resetMonthIfNeeded() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    if (thisMonth.isAfter(_monthStart)) {
      _monthStart = thisMonth;
      _diagnosticsThisMonth = 0;
    }
  }

  Future<void> _syncToRemote() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final uid = SupabaseConfig.client.auth.currentUser?.id;
      if (uid == null) return;
      await SupabaseConfig.client.from('subscriptions').upsert({
        'user_id': uid,
        'tier': _tier.name,
        'diagnostics_used': _diagnosticsThisMonth,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
