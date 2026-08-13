/// Safe enum parsing for persisted JSON — avoids crashes on schema drift.
T enumByName<T extends Enum>(
  List<T> values,
  String? raw,
  T fallback,
) {
  if (raw == null || raw.isEmpty) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
