import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixease/l10n/app_localizations.dart';

import '../../models/dtc_info.dart';
import '../../services/dtc_lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';

class DtcLookupScreen extends StatefulWidget {
  const DtcLookupScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<DtcLookupScreen> createState() => _DtcLookupScreenState();
}

class _DtcLookupScreenState extends State<DtcLookupScreen> {
  final _searchCtrl = TextEditingController();
  DtcCategory? _filter;
  List<DtcInfo> _results = [];
  String? _expandedCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchCtrl.text = widget.initialQuery!;
    }
    _runSearch();
  }

  void _runSearch() {
    setState(() {
      _results = DtcLookupService.search(
        _searchCtrl.text,
        category: _filter,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dtcLookupTitle)),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.dtcSearchHint, style: tt.titleLarge),
                  const SizedBox(height: 6),
                  Text(l10n.dtcSearchHelp, style: tt.bodySmall),
                  const SizedBox(height: 12),
                  NeuTextField(
                    hint: 'P0420, P03*, misfire',
                    icon: Icons.search_rounded,
                    controller: _searchCtrl,
                    onChanged: (_) => _runSearch(),
                    onSubmitted: (_) => _runSearch(),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () {
                            setState(() => _filter = null);
                            _runSearch();
                          },
                        ),
                        ...DtcCategory.values.map(
                          (cat) => _FilterChip(
                            label: _categoryShort(cat),
                            selected: _filter == cat,
                            onTap: () {
                              setState(() => _filter = cat);
                              _runSearch();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.trim().isEmpty
                            ? 'Type a code to search — e.g. P0420 or P04*'
                            : 'No codes matched "${_searchCtrl.text.trim()}"',
                        style: tt.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final info = _results[index];
                        final expanded = _expandedCode == info.code;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DtcInfoTile(
                            info: info,
                            expanded: expanded,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _expandedCode = expanded ? null : info.code;
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryShort(DtcCategory cat) => switch (cat) {
        DtcCategory.powertrain => 'P — Engine',
        DtcCategory.chassis => 'C — Chassis',
        DtcCategory.body => 'B — Body',
        DtcCategory.network => 'U — Network',
      };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class DtcInfoTile extends StatelessWidget {
  const DtcInfoTile({
    super.key,
    required this.info,
    this.expanded = false,
    this.onTap,
  });

  final DtcInfo info;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final severityColor = switch (info.severity) {
      DtcSeverity.critical => const Color(0xFFFF5252),
      DtcSeverity.warning => const Color(0xFFFFB74D),
      DtcSeverity.info => AppColors.accent,
    };

    return GestureDetector(
      onTap: onTap,
      child: NeuPane(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    info.code,
                    style: tt.titleMedium?.copyWith(color: AppColors.accent),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    info.severityLabel,
                    style: tt.bodySmall?.copyWith(
                      color: severityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(info.description, style: tt.bodyMedium),
            Text(info.categoryLabel, style: tt.bodySmall),
            if (expanded) ...[
              if (info.commonCauses.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Common causes', style: tt.titleMedium),
                ...info.commonCauses.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $c', style: tt.bodySmall),
                  ),
                ),
              ],
              if (info.possibleFixes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Possible fixes', style: tt.titleMedium),
                ...info.possibleFixes.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $f', style: tt.bodySmall),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact list of DTC codes with descriptions for dashboards/reports.
class DtcCodeList extends StatelessWidget {
  const DtcCodeList({
    super.key,
    required this.codes,
    this.emptyLabel = 'None',
    this.tappable = true,
  });

  final List<String> codes;
  final String emptyLabel;
  final bool tappable;

  void _openLookup(BuildContext context, String code) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DtcLookupScreen(initialQuery: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) {
      return Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall);
    }
    final infos = DtcLookupService.describeCodes(codes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infos.map((info) {
        final tile = DtcInfoTile(info: info);
        if (!tappable) return tile;
        return GestureDetector(
          onTap: () => _openLookup(context, info.code),
          child: tile,
        );
      }).toList(),
    );
  }
}
