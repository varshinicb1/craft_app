import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UnitConverter extends StatefulWidget {
  const UnitConverter({super.key});
  @override
  State<UnitConverter> createState() => _UnitConverterState();
}

class _UnitConverterState extends State<UnitConverter> {
  String _category = 'Length';
  int _fromIndex = 0;
  int _toIndex = 1;
  final _inputCtrl = TextEditingController(text: '1');
  String _result = '';

  static const _categories = ['Length', 'Weight', 'Temperature', 'Data', 'Speed', 'Area', 'Volume', 'Time'];

  static const _units = {
    'Length': ['Meters', 'Kilometers', 'Miles', 'Feet', 'Inches', 'Centimeters', 'Millimeters', 'Yards'],
    'Weight': ['Kilograms', 'Grams', 'Pounds', 'Ounces', 'Tons', 'Milligrams'],
    'Temperature': ['Celsius', 'Fahrenheit', 'Kelvin'],
    'Data': ['Bytes', 'KB', 'MB', 'GB', 'TB', 'Bits', 'Kilobits'],
    'Speed': ['km/h', 'mph', 'm/s', 'knots'],
    'Area': ['sq meters', 'sq km', 'sq miles', 'sq feet', 'acres', 'hectares'],
    'Volume': ['Liters', 'Milliliters', 'Gallons', 'Quarts', 'Cubic meters', 'Cubic feet'],
    'Time': ['Seconds', 'Minutes', 'Hours', 'Days', 'Weeks', 'Months', 'Years'],
  };

  static const _conversionFactors = {
    'Length': [1.0, 1000.0, 1609.344, 0.3048, 0.0254, 0.01, 0.001, 0.9144],
    'Weight': [1.0, 0.001, 0.453592, 0.0283495, 1000.0, 0.000001],
    'Data': [1.0, 1024.0, 1048576.0, 1073741824.0, 1099511627776.0, 0.125, 128.0],
    'Speed': [1.0, 1.60934, 3.6, 1.852],
    'Area': [1.0, 1000000.0, 2589988.0, 0.092903, 4046.86, 10000.0],
    'Volume': [1.0, 0.001, 3.78541, 0.946353, 1000.0, 28.3168],
    'Time': [1.0, 60.0, 3600.0, 86400.0, 604800.0, 2629800.0, 31557600.0],
  };

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _convert() {
    final input = double.tryParse(_inputCtrl.text);
    if (input == null) {
      setState(() => _result = 'Invalid number');
      return;
    }

    if (_category == 'Temperature') {
      setState(() => _result = _convertTemp(input));
      return;
    }

    final factors = _conversionFactors[_category];
    if (factors == null) {
      setState(() => _result = '');
      return;
    }

    final baseValue = input * factors[_fromIndex];
    final converted = baseValue / factors[_toIndex];

    final toUnit = _units[_category]![_toIndex];

    String formatted;
    if (converted.abs() >= 1000000 || (converted.abs() > 0 && converted.abs() < 0.001)) {
      formatted = converted.toStringAsExponential(4);
    } else if (converted == converted.roundToDouble()) {
      formatted = converted.toStringAsFixed(0);
    } else {
      formatted = converted.toStringAsFixed(4);
    }

    setState(() => _result = '$formatted $toUnit');
  }

  String _convertTemp(double value) {
    double result;
    String fromUnit = _units['Temperature']![_fromIndex];
    String toUnit = _units['Temperature']![_toIndex];

    double toCelsius;
    if (fromUnit == 'Celsius') {
      toCelsius = value;
    } else if (fromUnit == 'Fahrenheit') {
      toCelsius = (value - 32) * 5 / 9;
    } else {
      toCelsius = value - 273.15;
    }

    if (toUnit == 'Celsius') {
      result = toCelsius;
    } else if (toUnit == 'Fahrenheit') {
      result = toCelsius * 9 / 5 + 32;
    } else {
      result = toCelsius + 273.15;
    }

    return '${result.toStringAsFixed(2)} °$toUnit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;
    final units = _units[_category]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Unit Converter')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, ac), const SizedBox(height: 24),
        _buildCategorySelector(theme, ac),
        const SizedBox(height: 20),
        _buildUnitPicker(theme, ac, units),
        const SizedBox(height: 20),
        _buildInputField(theme, ac),
        const SizedBox(height: 16),
        _buildConvertButton(theme, ac),
        if (_result.isNotEmpty) ...[const SizedBox(height: 20), _buildResult(theme, ac)],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.primary, ac.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF1A0A00), size: 28),
        ),
        const SizedBox(height: 16),
        Text('Unit Converter', style: theme.textTheme.headlineSmall?.copyWith(color: const Color(0xFF1A0A00), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Length, Weight, Temperature, Data, Speed & more', style: TextStyle(color: const Color(0xFF1A0A00).withAlpha(200))),
      ]),
    );
  }

  Widget _buildCategorySelector(ThemeData theme, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: ac.outline.withAlpha(60))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Category', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _categories.map((cat) {
          final isSelected = _category == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) => setState(() { _category = cat; _fromIndex = 0; _toIndex = 1; _result = ''; }),
            selectedColor: ac.primaryContainer,
            backgroundColor: ac.surfaceVariant,
            side: BorderSide(color: isSelected ? ac.primary.withAlpha(80) : ac.outline.withAlpha(60)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            labelStyle: TextStyle(color: isSelected ? ac.primary : ac.onSurfaceDim, fontSize: 13),
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildUnitPicker(ThemeData theme, AppColors ac, List<String> units) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: ac.outline.withAlpha(60))),
      child: Column(children: [
        Row(children: [
          Expanded(child: _buildDropdown(theme, ac, 'From', units, _fromIndex, (v) => setState(() { _fromIndex = v!; _result = ''; }))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: ac.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_rounded, color: ac.primary, size: 18),
            ),
          ),
          Expanded(child: _buildDropdown(theme, ac, 'To', units, _toIndex, (v) => setState(() { _toIndex = v!; _result = ''; }))),
        ]),
      ]),
    );
  }

  Widget _buildDropdown(ThemeData theme, AppColors ac, String label, List<String> items, int value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      dropdownColor: ac.cardElevated,
      style: TextStyle(color: ac.cream),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ac.onSurfaceDim),
      ),
      items: List.generate(items.length, (i) => DropdownMenuItem(
        value: i,
        child: Text(items[i], style: const TextStyle(fontSize: 13)),
      )),
      onChanged: onChanged,
    );
  }

  Widget _buildInputField(ThemeData theme, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: ac.outline.withAlpha(60))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Value', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _inputCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter value',
            suffixIcon: IconButton(
              icon: Icon(Icons.refresh_rounded, color: ac.onSurfaceDim),
              onPressed: () { _inputCtrl.text = '1'; _convert(); },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildConvertButton(ThemeData theme, AppColors ac) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: ac.primary.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: FilledButton.icon(
        onPressed: _convert,
        icon: const Icon(Icons.calculate_rounded),
        label: const Text('Convert'),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ac.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.primary.withAlpha(60)),
      ),
      child: Center(child: Column(children: [
        Text('${_inputCtrl.text} ${_units[_category]![_fromIndex]} =', style: TextStyle(color: ac.onSurfaceDim)),
        const SizedBox(height: 8),
        Text(_result, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: ac.primary)),
      ])),
    );
  }
}
