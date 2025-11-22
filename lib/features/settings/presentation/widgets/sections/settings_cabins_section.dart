import 'package:beauty_center/core/database/extensions/db_models_extensions.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:beauty_center/core/providers/supabase_auth_provider.dart';
import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/connectivity/connectivity_provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/widgets/custom_snackbar.dart';
import '../../../../../core/widgets/section_card.dart';
import '../../providers/settings_provider.dart';

class SettingsCabinsSection extends ConsumerWidget {
  const SettingsCabinsSection({required this.cabins, super.key});

  final List<Cabin> cabins;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final isOffline = ref.watch(isConnectionUnusableProvider);
    final isDisconnectedSup = ref.watch(supabaseAuthProvider).isDisconnected;
    final actions = ref.read(settingsActionsProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.meeting_room,
                size: kIsWindows ? 28 : 28.sp,
                color: colorScheme.primary,
              ),
              SizedBox(width: kIsWindows ? 8 : 8.w),
              Text(
                context.l10n.cabins,
                style: TextStyle(
                  fontSize: kIsWindows ? 24 : 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 16 : 16.h),
          Row(
            children: [
              Text(
                context.l10n.number,
                style: TextStyle(fontSize: kIsWindows ? 18 : 18.sp),
              ),
              SizedBox(width: kIsWindows ? 12 : 12.w),
              Expanded(
                child: Slider(
                  min: kMinCabinsCount.toDouble(),
                  max: kMaxCabinsCount.toDouble(),
                  divisions: (kMaxCabinsCount - kMinCabinsCount)
                      .clamp(1, double.infinity)
                      .toInt(),
                  value: cabins.length.toDouble().clamp(
                    kMinCabinsCount.toDouble(),
                    kMaxCabinsCount.toDouble(),
                  ),
                  label:
                      '${cabins.length.clamp(kMinCabinsCount, kMaxCabinsCount)}',
                  onChanged: isOffline || isDisconnectedSup
                      ? null
                      : (final v) => actions.setCabinsCount(v.round()),
                ),
              ),
              SizedBox(
                width: kIsWindows ? 40 : 40.w,
                child: Center(
                  child: Text(
                    '${cabins.length}',
                    key: ValueKey<int>(cabins.length),
                    style: TextStyle(
                      fontSize: kIsWindows ? 18 : 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 16 : 16.h),
          ...cabins.asMap().entries.map(
            (final entry) => _CabinRow(
              index: entry.key,
              cabin: entry.value,
              isOffline: isOffline || isDisconnectedSup,
            ),
          ),
        ],
      ),
    );
  }
}

class _CabinRow extends ConsumerWidget {
  const _CabinRow({
    required this.index,
    required this.cabin,
    required this.isOffline,
  });

  final int index;
  final Cabin cabin;
  final bool isOffline;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = ThemeData.estimateBrightnessForColor(cabin.colorValue);
    final overColor = brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Padding(
      padding: EdgeInsets.only(bottom: kIsWindows ? 12 : 12.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: kIsWindows ? 22 : 22.r,
            backgroundColor: colorScheme.primary,
            child: Text(
              cabin.displayNumber,
              style: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          SizedBox(width: kIsWindows ? 12 : 12.w),
          Expanded(
            child: InkWell(
              onTap: () {
                if (isOffline) {
                  showCustomSnackBar(
                    context: context,
                    message: context.l10n.offlineNoChangeData,
                    okColor: AppTabs.settings.color,
                  );
                } else {
                  _showColorPicker(context, ref, cabin);
                }
              },
              borderRadius: BorderRadius.circular(kIsWindows ? 10 : 10.r),
              child: Container(
                height: kIsWindows ? 50 : 50.h,
                decoration: BoxDecoration(
                  color: cabin.colorValue,
                  borderRadius: BorderRadius.circular(kIsWindows ? 10 : 10.r),
                  border: Border.all(
                    color: Colors.black12,
                    width: kIsWindows ? 2 : 1.5.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cabin.colorValue.withValues(alpha: 0.3),
                      blurRadius: kIsWindows ? 8 : 8.r,
                      spreadRadius: kIsWindows ? 1 : 1.r,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    context.l10n.tapToChangeColor,
                    style: TextStyle(
                      color: isOffline ? Colors.grey : overColor,
                      fontSize: kIsWindows ? 14 : 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPicker(
    final BuildContext context,
    final WidgetRef ref,
    final Cabin cabin,
  ) async {
    var selectedColor = cabin.colorValue;

    await showDialog<void>(
      context: context,
      builder: (final ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
        ),
        contentPadding: EdgeInsets.all(kIsWindows ? 20 : 20.w),
        content: StatefulBuilder(
          builder: (final context, final setState) => SizedBox(
            width: 0.85.sw,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.cabinColor(cabin.id),
                  style: TextStyle(
                    fontSize: kIsWindows ? 18 : 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: kIsWindows ? 20 : 20.h),
                ColorPicker(
                  color: selectedColor,
                  onColorChanged: (final c) =>
                      setState(() => selectedColor = c),
                  width: kIsWindows ? 44 : 44.w,
                  height: kIsWindows ? 44 : 44.h,
                  borderRadius: kIsWindows ? 12 : 12.r,
                  spacing: 8,
                  runSpacing: 8,
                  pickersEnabled: const {
                    ColorPickerType.wheel: true,
                    ColorPickerType.primary: false,
                    ColorPickerType.accent: false,
                  },
                  wheelDiameter: kIsWindows ? 220 : 200.w,
                  wheelWidth: kIsWindows ? 18 : 18.w,
                  wheelHasBorder: true,
                  wheelSquarePadding: kIsWindows ? 4 : 4.w,
                  wheelSquareBorderRadius: kIsWindows ? 12 : 12.r,
                ),
                SizedBox(height: kIsWindows ? 20 : 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                    SizedBox(width: kIsWindows ? 12 : 12.w),
                    FilledButton(
                      onPressed: () {
                        ref
                            .read(settingsActionsProvider)
                            .updateCabinColor(
                              id: cabin.id,
                              color: selectedColor,
                            );
                        Navigator.pop(context);
                      },
                      child: Text(context.l10n.submit),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
