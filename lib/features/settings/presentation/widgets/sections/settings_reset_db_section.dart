import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/widgets/section_card.dart';

class SettingsResetDbSection extends StatefulWidget {
  const SettingsResetDbSection({super.key});

  @override
  State<SettingsResetDbSection> createState() => _SettingsResetDbSectionState();
}

class _SettingsResetDbSectionState extends State<SettingsResetDbSection> {
  static final _log = AppLogger.getLogger(name: 'SettingsResetDbSection');

  Future<void> _handleDatabaseReset(BuildContext context) async {
    // 1. Prima Conferma
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          "Sei sicuro di voler resettare il database locale e chiudere l'app? "
          "L'app verrà chiusa e predisposta per una pulizia totale",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('PROCEDI'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // 2. Seconda Conferma (Stile di allerta)
    if (!context.mounted) return;
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            const Icon(Symbols.warning, color: Colors.red),
            SizedBox(width: kIsWindows ? 10 : 10.w),
            const Text(
              'ATTENZIONE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Questa operazione eliminerà tutti i dati salvati localmente e chiuderà l'app. "
          "Sei assolutamente certo di voler procedere con la formattazione locale e chiudere l'app?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'NO, ESCI',
              style: TextStyle(color: Colors.black),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SÌ, RESETTA TUTTO E CHIUDI L'APP"),
          ),
        ],
      ),
    );

    if (secondConfirm == true) {
      _log.severe('Reset database richiesto.');
      await AppDatabase.requestResetOnNextLaunch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          hoverColor: colorScheme.primary.withAlpha(20),
          splashColor: colorScheme.primary.withAlpha(30),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: kIsWindows ? 16 : 16.w,
            vertical: kIsWindows ? 4 : 4.w,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
          ),
          leading: Icon(
            Symbols.database,
            size: kIsWindows ? 28 : 28.sp,
            color: colorScheme.primary,
          ),
          title: Text(
            'Manutenzione Database',
            style: TextStyle(
              fontSize: kIsWindows ? 24 : 24.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          children: [
            Container(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.w),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(15),
                borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
                border: Border.all(color: Colors.red.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.error,
                        color: Colors.red,
                        size: kIsWindows ? 20 : 20.sp,
                      ),
                      SizedBox(width: kIsWindows ? 8 : 8.w),
                      Text(
                        'Zona Pericolosa',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: kIsWindows ? 16 : 16.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  Text(
                    'Usa questa funzione solo se il database locale presenta corruzioni o se è necessario pulire la cache dei dati.',
                    style: TextStyle(
                      fontSize: kIsWindows ? 14 : 14.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 16 : 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(
                          vertical: kIsWindows ? 12 : 12.h,
                        ),
                      ),
                      onPressed: () => _handleDatabaseReset(context),
                      icon: const Icon(Symbols.delete_forever),
                      label: const Text('ESEGUI RESET DB LOCALE'),
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
