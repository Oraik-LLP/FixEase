enum DtcCategory { powertrain, chassis, body, network }

enum DtcSeverity { critical, warning, info }

class DtcInfo {
  const DtcInfo({
    required this.code,
    required this.description,
    required this.category,
    this.severity = DtcSeverity.warning,
    this.commonCauses = const [],
    this.possibleFixes = const [],
  });

  final String code;
  final String description;
  final DtcCategory category;
  final DtcSeverity severity;
  final List<String> commonCauses;
  final List<String> possibleFixes;

  String get categoryLabel => switch (category) {
        DtcCategory.powertrain => 'Powertrain',
        DtcCategory.chassis => 'Chassis',
        DtcCategory.body => 'Body',
        DtcCategory.network => 'Network',
      };

  String get severityLabel => switch (severity) {
        DtcSeverity.critical => 'Critical',
        DtcSeverity.warning => 'Warning',
        DtcSeverity.info => 'Info',
      };

  static DtcCategory categoryFromCode(String code) {
    if (code.isEmpty) return DtcCategory.powertrain;
    return switch (code[0].toUpperCase()) {
      'C' => DtcCategory.chassis,
      'B' => DtcCategory.body,
      'U' => DtcCategory.network,
      _ => DtcCategory.powertrain,
    };
  }
}
