import '../models/dtc_info.dart';

/// Embedded OBD-II DTC database — 4000+ codes (P/C/B/U) with explicit overrides.
abstract final class DtcDatabase {
  static final Map<String, DtcInfo> _codes = {};
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _loadExplicitCodes();
    _generateStandardCodes();
  }

  static DtcInfo? get(String code) {
    ensureInitialized();
    final normalized = _normalize(code);
    if (normalized == null) return null;
    return _codes[normalized];
  }

  static List<DtcInfo> all() {
    ensureInitialized();
    return _codes.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  static List<DtcInfo> byCategory(DtcCategory category) {
    return all().where((c) => c.category == category).toList();
  }

  static List<DtcInfo> search(String query, {DtcCategory? category}) {
    ensureInitialized();
    final trimmed = query.trim().toUpperCase();
    if (trimmed.isEmpty) {
      final base = category == null
          ? all()
          : all().where((c) => c.category == category).toList();
      return base.take(100).toList();
    }

    final pattern = _wildcardToRegex(trimmed);
    Iterable<DtcInfo> results = _codes.values.where(
      (info) =>
          pattern.hasMatch(info.code) ||
          info.description.toUpperCase().contains(trimmed),
    );

    if (category != null) {
      results = results.where((c) => c.category == category);
    }

    final list = results.toList()
      ..sort((a, b) {
        final aExact = a.code.startsWith(trimmed.replaceAll('*', '')) ? 0 : 1;
        final bExact = b.code.startsWith(trimmed.replaceAll('*', '')) ? 0 : 1;
        if (aExact != bExact) return aExact.compareTo(bExact);
        return a.code.compareTo(b.code);
      });
    return list.take(200).toList();
  }

  static String? _normalize(String raw) {
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length != 5) return null;
    if (!RegExp(r'^[PCBU][0-9A-F]{4}$').hasMatch(code)) return null;
    return code;
  }

  static RegExp _wildcardToRegex(String query) {
    final escaped = RegExp.escape(query).replaceAll(r'\*', '.*');
    return RegExp('^$escaped', caseSensitive: false);
  }

  static void _put(
    String code,
    String description, {
    DtcSeverity severity = DtcSeverity.warning,
    List<String> causes = const [],
    List<String> fixes = const [],
  }) {
    _codes[code] = DtcInfo(
      code: code,
      description: description,
      category: DtcInfo.categoryFromCode(code),
      severity: severity,
      commonCauses: causes,
      possibleFixes: fixes,
    );
  }

  static void _loadExplicitCodes() {
    const explicit = <String, (String, DtcSeverity, List<String>, List<String>)>{
      'P0001': ('Fuel Volume Regulator Control Circuit/Open', DtcSeverity.warning, ['Faulty fuel volume regulator', 'Wiring issue'], ['Check regulator wiring', 'Replace fuel volume regulator']),
      'P0010': ('Intake Camshaft Position Actuator Circuit (Bank 1)', DtcSeverity.warning, ['VVT solenoid failure', 'Low oil level'], ['Replace VVT solenoid', 'Check oil level']),
      'P0016': ('Crankshaft/Camshaft Position Correlation (Bank 1)', DtcSeverity.critical, ['Timing chain/belt issue'], ['Inspect timing components']),
      'P0030': ('HO2S Heater Control Circuit (Bank 1 Sensor 1)', DtcSeverity.warning, ['O2 sensor heater failure'], ['Replace upstream O2 sensor']),
      'P0100': ('Mass or Volume Air Flow Circuit Malfunction', DtcSeverity.warning, ['MAF sensor dirty/failed', 'Vacuum leak'], ['Clean/replace MAF', 'Check vacuum leaks']),
      'P0101': ('Mass or Volume Air Flow Circuit Range/Performance', DtcSeverity.warning, ['MAF out of range'], ['Clean/replace MAF sensor']),
      'P0102': ('Mass or Volume Air Flow Circuit Low Input', DtcSeverity.warning, ['MAF signal low'], ['Check MAF wiring']),
      'P0103': ('Mass or Volume Air Flow Circuit High Input', DtcSeverity.warning, ['MAF signal high'], ['Check MAF wiring']),
      'P0115': ('Engine Coolant Temperature Circuit Malfunction', DtcSeverity.warning, ['ECT sensor failed'], ['Replace coolant temp sensor']),
      'P0128': ('Coolant Thermostat Below Regulating Temperature', DtcSeverity.info, ['Thermostat stuck open'], ['Replace thermostat']),
      'P0130': ('O2 Sensor Circuit (Bank 1 Sensor 1)', DtcSeverity.warning, ['O2 sensor failed'], ['Replace O2 sensor']),
      'P0135': ('O2 Sensor Heater Circuit (Bank 1 Sensor 1)', DtcSeverity.warning, ['O2 heater failed'], ['Replace O2 sensor']),
      'P0171': ('System Too Lean (Bank 1)', DtcSeverity.warning, ['Vacuum leak', 'MAF fault'], ['Check vacuum lines', 'Test fuel pressure']),
      'P0172': ('System Too Rich (Bank 1)', DtcSeverity.warning, ['Leaking injector'], ['Check injectors']),
      'P0174': ('System Too Lean (Bank 2)', DtcSeverity.warning, ['Vacuum leak bank 2'], ['Inspect intake']),
      'P0175': ('System Too Rich (Bank 2)', DtcSeverity.warning, ['Rich condition bank 2'], ['Check injectors']),
      'P0201': ('Injector Circuit/Open - Cylinder 1', DtcSeverity.warning, ['Injector failed'], ['Test/replace injector']),
      'P0217': ('Engine Coolant Over Temperature Condition', DtcSeverity.critical, ['Cooling system failure'], ['Check coolant and fan']),
      'P0234': ('Engine Over Boost Condition', DtcSeverity.critical, ['Turbo overboost'], ['Inspect turbo/wastegate']),
      'P0300': ('Random/Multiple Cylinder Misfire Detected', DtcSeverity.critical, ['Spark plugs', 'Coils', 'Vacuum leak'], ['Replace spark plugs', 'Check coils']),
      'P0301': ('Cylinder 1 Misfire Detected', DtcSeverity.critical, ['Bad plug/coil cyl 1'], ['Replace plug/coil']),
      'P0302': ('Cylinder 2 Misfire Detected', DtcSeverity.critical, ['Bad plug/coil cyl 2'], ['Replace plug/coil']),
      'P0303': ('Cylinder 3 Misfire Detected', DtcSeverity.critical, ['Bad plug/coil cyl 3'], ['Replace plug/coil']),
      'P0304': ('Cylinder 4 Misfire Detected', DtcSeverity.critical, ['Bad plug/coil cyl 4'], ['Replace plug/coil']),
      'P0335': ('Crankshaft Position Sensor A Circuit Malfunction', DtcSeverity.critical, ['Crank sensor failed'], ['Replace crankshaft sensor']),
      'P0340': ('Camshaft Position Sensor Circuit Malfunction', DtcSeverity.warning, ['Cam sensor failed'], ['Replace camshaft sensor']),
      'P0400': ('Exhaust Gas Recirculation Flow Malfunction', DtcSeverity.warning, ['EGR valve stuck'], ['Clean/replace EGR']),
      'P0401': ('Exhaust Gas Recirculation Flow Insufficient', DtcSeverity.warning, ['EGR passage blocked'], ['Clean EGR passages']),
      'P0420': ('Catalyst System Efficiency Below Threshold (Bank 1)', DtcSeverity.warning, ['Failed catalytic converter'], ['Replace catalytic converter']),
      'P0430': ('Catalyst System Efficiency Below Threshold (Bank 2)', DtcSeverity.warning, ['Bank 2 cat failure'], ['Replace cat bank 2']),
      'P0440': ('Evaporative Emission Control System Malfunction', DtcSeverity.info, ['EVAP leak', 'Gas cap loose'], ['Check gas cap']),
      'P0442': ('EVAP System Leak Detected (Small)', DtcSeverity.info, ['Small EVAP leak'], ['Smoke test EVAP']),
      'P0455': ('EVAP System Leak Detected (Large)', DtcSeverity.warning, ['Large EVAP leak'], ['Inspect gas cap and hoses']),
      'P0456': ('EVAP System Leak Detected (Very Small)', DtcSeverity.info, ['Minor EVAP leak'], ['Check gas cap seal']),
      'P0500': ('Vehicle Speed Sensor Malfunction', DtcSeverity.warning, ['VSS failed'], ['Replace speed sensor']),
      'P0505': ('Idle Air Control System Malfunction', DtcSeverity.warning, ['IAC valve dirty'], ['Clean/replace IAC']),
      'P0562': ('System Voltage Low', DtcSeverity.warning, ['Weak battery/alternator'], ['Test charging system']),
      'P0700': ('Transmission Control System Malfunction', DtcSeverity.critical, ['Transmission fault'], ['Scan TCM for codes']),
      'P0715': ('Input/Turbine Speed Sensor Circuit Malfunction', DtcSeverity.warning, ['Input speed sensor'], ['Replace sensor']),
      'P0730': ('Incorrect Gear Ratio', DtcSeverity.critical, ['Transmission slipping'], ['Inspect transmission fluid']),
      'P1000': ('OBD Systems Not Ready - Drive Cycle Not Complete', DtcSeverity.info, ['Recent code clear'], ['Complete drive cycle']),
      'C0035': ('Left Front Wheel Speed Sensor Circuit', DtcSeverity.warning, ['ABS sensor fault'], ['Replace LF sensor']),
      'C0121': ('ABS Pump Motor Circuit Failure', DtcSeverity.critical, ['ABS pump failed'], ['Replace ABS module']),
      'B0001': ('Driver Frontal Airbag Deployment Control', DtcSeverity.critical, ['Airbag circuit fault'], ['Diagnose SRS']),
      'U0100': ('Lost Communication With ECM/PCM A', DtcSeverity.critical, ['CAN bus fault'], ['Check CAN wiring']),
      'U0101': ('Lost Communication With TCM', DtcSeverity.critical, ['TCM offline'], ['Check TCM connection']),
      'U0121': ('Lost Communication With ABS Module', DtcSeverity.critical, ['ABS module offline'], ['Check ABS power']),
    };

    for (final entry in explicit.entries) {
      final (desc, sev, causes, fixes) = entry.value;
      _put(entry.key, desc, severity: sev, causes: causes, fixes: fixes);
    }
  }

  static void _generateStandardCodes() {
    for (var i = 0; i < 1000; i++) {
      final code = 'P${i.toString().padLeft(4, '0')}';
      if (_codes.containsKey(code)) continue;
      _put(code, _p0Description(i), severity: DtcSeverity.info);
    }
    for (var i = 1000; i < 2000; i++) {
      final code = 'P${i.toString().padLeft(4, '0')}';
      _put(
        code,
        'Manufacturer-Specific Powertrain Code $code',
        severity: DtcSeverity.warning,
        causes: const ['Manufacturer-specific fault'],
        fixes: const ['Check manufacturer service information'],
      );
    }
    for (var i = 2000; i < 4000; i++) {
      final code = 'P${i.toString().padLeft(4, '0')}';
      _put(
        code,
        i < 3000 ? 'Generic Powertrain Code $code' : 'Manufacturer-Specific Powertrain Code $code',
        severity: DtcSeverity.info,
      );
    }
    for (var i = 0; i < 1000; i++) {
      final code = 'C${i.toString().padLeft(4, '0')}';
      if (_codes.containsKey(code)) continue;
      _put(code, 'Chassis / ABS / Steering / Suspension ($code)');
    }
    for (var i = 0; i < 1000; i++) {
      final code = 'B${i.toString().padLeft(4, '0')}';
      if (_codes.containsKey(code)) continue;
      _put(code, 'Body / Airbag / Climate / Lighting ($code)');
    }
    for (var i = 0; i < 1000; i++) {
      final code = 'U${i.toString().padLeft(4, '0')}';
      if (_codes.containsKey(code)) continue;
      _put(code, 'Network / CAN Communication ($code)');
    }
  }

  static String _p0Description(int num) {
    if (num <= 99) return 'Fuel and Air Metering / Auxiliary Emission ($num)';
    if (num <= 199) return 'Fuel and Air Metering ($num)';
    if (num <= 299) return 'Fuel and Air Metering - Injector Circuit ($num)';
    if (num <= 399) return 'Ignition System or Misfire ($num)';
    if (num <= 499) return 'Auxiliary Emission Controls ($num)';
    if (num <= 599) return 'Vehicle Speed Control and Idle Control ($num)';
    if (num <= 699) return 'Computer Output Circuit ($num)';
    if (num <= 899) return 'Transmission ($num)';
    return 'Fuel and Air Metering / Vehicle Speed ($num)';
  }
}
