import 'package:flutter/material.dart';
import '../models/vehicle.dart';

/// Small offline catalogue. Custom text remains valid for unlisted vehicles.
abstract final class VehicleCatalogue {
  static const _extra = {
    'Honda': ['Brio', 'Activa', 'Dio', 'Shine', 'Unicorn', 'CB350'],
    'Hero': ['Splendor', 'Passion', 'Xtreme', 'Xpulse'],
    'Bajaj': ['Pulsar', 'Dominar', 'Platina', 'Avenger'],
    'TVS': ['Apache', 'Jupiter', 'Ntorq', 'Raider'],
    'Royal Enfield': ['Classic 350', 'Bullet 350', 'Himalayan', 'Meteor 350'],
    'Yamaha': ['FZ', 'R15', 'MT-15', 'Aerox'],
    'Kawasaki': ['Ninja', 'Versys', 'Z650'],
    'KTM': ['Duke', 'RC', 'Adventure'],
    'Holden': ['Commodore', 'Colorado', 'Astra'],
    'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X'],
  };
  static String _key(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]'), '')
      .replaceAll('š', 's')
      .replaceAll('ë', 'e');
  static List<String> _matches(Iterable<String> values, String query) {
    final key = _key(query.trim());
    if (key.isEmpty) return [];
    final result = values.toSet().where((v) => _key(v).contains(key)).toList();
    result.sort((a, b) {
      final ap = _key(a).startsWith(key), bp = _key(b).startsWith(key);
      if (ap != bp) return ap ? -1 : 1;
      return a.compareTo(b);
    });
    return result.take(4).toList();
  }

  static List<String> makes(String query) =>
      _matches([...VehicleData.makes, ..._extra.keys], query);
  static List<String> models(String make, String query) {
    final brands = {...VehicleData.makes, ..._extra.keys};
    final matched = brands.where((v) => _key(v) == _key(make)).firstOrNull;
    if (matched == null) return [];
    return _matches(
        [...VehicleData.modelsFor(matched), ...?_extra[matched]], query);
  }
}

class VehicleAutocomplete extends StatefulWidget {
  const VehicleAutocomplete(
      {super.key,
      required this.label,
      required this.controller,
      required this.options});
  final String label;
  final TextEditingController controller;
  final Iterable<String> Function(String) options;
  @override
  State<VehicleAutocomplete> createState() => _VehicleAutocompleteState();
}

class _VehicleAutocompleteState extends State<VehicleAutocomplete> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: LayoutBuilder(
            builder: (context, constraints) => RawAutocomplete<String>(
                  textEditingController: widget.controller,
                  focusNode: _focus,
                  optionsBuilder: (value) => widget.options(value.text),
                  fieldViewBuilder: (context, controller, focus, submit) =>
                      TextFormField(
                          controller: controller,
                          focusNode: focus,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                              labelText: widget.label,
                              helperText:
                                  'Offline suggestions · custom entries welcome')),
                  optionsViewBuilder: (context, select, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                              width: constraints.maxWidth,
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 220),
                                  child: ListView(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      children: options
                                          .map((option) => ListTile(
                                              dense: true,
                                              title: Text(option),
                                              onTap: () => select(option)))
                                          .toList()))))),
                )),
      );
}
