import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int cabinsCount = 3;
  int operatorsCount = 2;

  List<Color> cabinColors = [];
  List<String> operatorNames = [];

  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    cabinColors = List<Color>.generate(cabinsCount, _defaultColor);
    operatorNames = List<String>.generate(
      operatorsCount,
      (final i) => 'Operatore ${i + 1}',
    );
  }

  Color _defaultColor(final int i) {
    const palette = [
      Color(0xFFEF9A9A),
      Color(0xFFF48FB1),
      Color(0xFFCE93D8),
      Color(0xFF9FA8DA),
      Color(0xFF81D4FA),
      Color(0xFFA5D6A7),
      Color(0xFFFFF59D),
      Color(0xFFFFCC80),
      Color(0xFFBCAAA4),
      Color(0xFF90A4AE),
    ];

    return palette[i % palette.length];
  }

  void _setCabinsCount(final int n) {
    setState(() {
      cabinsCount = n;
      if (cabinColors.length < n) {
        cabinColors.addAll(
          List.generate(
            n - cabinColors.length,
            (final i) => _defaultColor(cabinColors.length + i),
          ),
        );
      } else if (cabinColors.length > n) {
        cabinColors = cabinColors.take(n).toList();
      }
    });
  }

  void _setOperatorsCount(final int n) {
    setState(() {
      operatorsCount = n;
      if (operatorNames.length < n) {
        operatorNames.addAll(
          List.generate(
            n - operatorNames.length,
            (final i) => 'Operatore ${operatorNames.length + i + 1}',
          ),
        );
      } else if (operatorNames.length > n) {
        operatorNames = operatorNames.take(n).toList();
      }
    });
  }

  Future<void> _pickColor(final int index) async {
    final initial = cabinColors[index];
    var color = initial;

    await showDialog<void>(
      context: context,
      builder: (final context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        contentPadding: EdgeInsets.all(16.w),
        content: StatefulBuilder(
          builder: (final context, final setState) => SizedBox(
            width: 0.25.sw,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Seleziona colore cabina',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12.h),
                ColorPicker(
                  color: color,
                  onColorChanged: (final c) => setState(() => color = c),
                  width: kIsDesktop ? 45 : 30,
                  height: kIsDesktop ? 40 : 30,
                  heading: Text(
                    'Palette',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subheading: Text(
                    'Seleziona una tonalità',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  showColorName: true,
                  pickersEnabled: const <ColorPickerType, bool>{
                    ColorPickerType.primary: false,
                    ColorPickerType.accent: false,
                    ColorPickerType.custom: true,
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // update outer scope after pop
                        });
                        color = color;
                        Navigator.of(context).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // finally set the value
    setState(() {
      cabinColors[index] = color;
    });
  }

  Future<void> _pickTime({required final bool isStart}) async {
    final initial = isStart ? startTime : endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (final context, final child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      // validate ranges
      if (isStart) {
        if (picked.hour < 6 || picked.hour > 12) {
          _showSnack('Orario di inizio deve essere tra 06:00 e 12:00');
          return;
        }
        setState(() => startTime = picked);
      } else {
        if (picked.hour < 14 || picked.hour > 22) {
          _showSnack('Orario di fine deve essere tra 14:00 e 22:00');
          return;
        }
        setState(() => endTime = picked);
      }
    }
  }

  void _showSnack(final String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Widget _buildSectionCard({required final Widget child}) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 2,
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );

  Widget _cabinsSection(final Color cardColor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Cabine', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Numero cabine:'),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider.adaptive(
                min: 1,
                max: 12,
                divisions: 11,
                value: cabinsCount.toDouble(),
                label: '$cabinsCount',
                onChanged: (final v) => _setCabinsCount(v.round()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 48, child: Center(child: Text('$cabinsCount'))),
        ],
      ),
      const SizedBox(height: 12),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(children: List.generate(cabinsCount, _cabinRow)),
      ),
    ],
  );

  Widget _cabinRow(final int index) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cabinColors[index],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Cabina ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        // Color preview / picker trigger
        GestureDetector(
          onTap: () async => _pickColor(index),
          child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: cabinColors[index],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: cabinColors[index].withValues(alpha: 0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _operatorsSection(final Color cardColor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Operatori', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Numero operatori:'),
          const SizedBox(width: 12),
          Expanded(
            child: Slider.adaptive(
              min: 1,
              max: 8,
              divisions: 7,
              value: operatorsCount.toDouble(),
              label: '$operatorsCount',
              onChanged: (final v) => _setOperatorsCount(v.round()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 36, child: Center(child: Text('$operatorsCount'))),
        ],
      ),
      const SizedBox(height: 12),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: Column(children: List.generate(operatorsCount, _operatorRow)),
      ),
    ],
  );

  Widget _operatorRow(final int index) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        CircleAvatar(radius: 18, child: Text('${index + 1}')),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            initialValue: operatorNames[index],
            decoration: InputDecoration(
              labelText: 'Nome operatore',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (final v) => operatorNames[index] = v,
          ),
        ),
      ],
    ),
  );

  Widget _workHoursSection(final Color cardColor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Orari di lavoro', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              tileColor: cardColor,
              title: const Text('Inizio (min 06:00 - max 12:00)'),
              subtitle: Text(startTime.format(context)),
              onTap: () => _pickTime(isStart: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              tileColor: cardColor,
              title: const Text('Fine (min 14:00 - max 22:00)'),
              subtitle: Text(endTime.format(context)),
              onTap: () => _pickTime(isStart: false),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(final BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    print('settings page');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionCard(child: _cabinsSection(cardColor)),
          const SizedBox(height: 12),
          _buildSectionCard(child: _operatorsSection(cardColor)),
          const SizedBox(height: 12),
          _buildSectionCard(child: _workHoursSection(cardColor)),
          const SizedBox(height: 20),
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: save locally / push to DB
                    _showSnack('Impostazioni salvate (demo)');
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Salva impostazioni',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
