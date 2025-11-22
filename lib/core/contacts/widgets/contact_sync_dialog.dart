import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/contact_change_model.dart';
import '../services/contact_service.dart';

/// Dialog showing a list of batch changes
class BatchSyncDialog extends StatefulWidget {
  const BatchSyncDialog({required this.changes, super.key});

  final List<PendingContactChange> changes;

  @override
  State<BatchSyncDialog> createState() => _BatchSyncDialogState();
}

class _BatchSyncDialogState extends State<BatchSyncDialog> {
  var _allSelected = true;

  late List<PendingContactChange> _creates;
  late List<PendingContactChange> _updates;

  @override
  void initState() {
    super.initState();
    _refreshLists();
  }

  void _refreshLists() {
    _creates = widget.changes
        .where((final c) => c.type == ContactChangeType.create)
        .toList();
    _updates = widget.changes
        .where((final c) => c.type == ContactChangeType.update)
        .toList();
  }

  void _toggleAll(final bool val) {
    setState(() {
      _allSelected = val;
      for (final c in widget.changes) {
        c.isSelected = val;
      }
    });
  }

  void _onItemChanged(final PendingContactChange change, final bool? val) {
    setState(() {
      change.isSelected = val ?? false;
      _allSelected = val! && widget.changes.every((final c) => c.isSelected);
    });
  }

  @override
  Widget build(final BuildContext context) {
    final count = widget.changes.where((final c) => c.isSelected).length;
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      contentPadding: EdgeInsets.zero,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Sync Contatti', style: theme.textTheme.titleLarge),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tutti', style: theme.textTheme.labelMedium),
              SizedBox(width: 8.w),
              Switch.adaptive(value: _allSelected, onChanged: _toggleAll),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 0.6.sh,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          shrinkWrap: true,
          children: [
            if (_creates.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Nuovi Contatti',
                color: Colors.green,
              ),
              ..._creates.map(
                (final c) => _ContactTile(
                  change: c,
                  color: Colors.green,
                  icon: Icons.person_add_rounded,
                  onChanged: (final v) => _onItemChanged(c, v),
                ),
              ),
            ],
            if (_updates.isNotEmpty) ...[
              if (_creates.isNotEmpty) Divider(height: 32.h),
              const _SectionHeader(
                title: 'Aggiornamenti',
                color: Colors.orange,
              ),
              ..._updates.map(
                (final c) => _ContactTile(
                  change: c,
                  color: Colors.orange,
                  icon: Icons.sync_rounded,
                  onChanged: (final v) => _onItemChanged(c, v),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: count > 0
              ? () => Navigator.pop(
                  context,
                  widget.changes.where((final c) => c.isSelected).toList(),
                )
              : null,
          child: Text('Sincronizza ($count)'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(final BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 16.h, bottom: 8.h),
    child: Row(
      children: [
        Container(width: 4.w, height: 16.h, color: color),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      ],
    ),
  );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.change,
    required this.color,
    required this.icon,
    required this.onChanged,
  });

  final PendingContactChange change;
  final Color color;
  final IconData icon;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(final BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    margin: EdgeInsets.only(bottom: 8.h),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.r),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
      ),
    ),
    child: CheckboxListTile(
      value: change.isSelected,
      activeColor: color,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      onChanged: onChanged,
      title: Text(
        '${change.firstName} ${change.lastName}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 4.h),
        child:
            change.type == ContactChangeType.update &&
                change.existingContact != null
            ? _DiffSummary(change: change)
            : Text(change.phone, style: TextStyle(fontSize: 12.sp)),
      ),
      secondary: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        radius: 16.r,
        child: Icon(icon, color: color, size: 18.sp),
      ),
    ),
  );
}

class _DiffSummary extends StatelessWidget {
  const _DiffSummary({required this.change});

  final PendingContactChange change;

  @override
  Widget build(final BuildContext context) {
    final diffs = DiffUtils.calculateDiffs(
      existing: change.existingContact!,
      newFirst: change.firstName,
      newLast: change.lastName,
      newPhone: change.phone,
      newEmail: change.email,
    );

    if (diffs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: diffs.map((final diff) => _DiffRowCompact(diff: diff)).toList(),
    );
  }
}

/// Single Sync Dialog
class SingleUpdateDialog extends StatelessWidget {
  const SingleUpdateDialog({
    required this.existing,
    required this.newFirstName,
    required this.newLastName,
    required this.newPhone,
    super.key,
    this.newEmail,
  });

  final Contact existing;
  final String newFirstName;
  final String newLastName;
  final String newPhone;
  final String? newEmail;

  @override
  Widget build(final BuildContext context) {
    final diffs = DiffUtils.calculateDiffs(
      existing: existing,
      newFirst: newFirstName,
      newLast: newLastName,
      newPhone: newPhone,
      newEmail: newEmail,
    );

    return AlertDialog(
      title: const Text('Aggiorna Contatto'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Verranno applicate le seguenti modifiche:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16.h),
            if (diffs.isEmpty)
              const Text(
                'Nessuna modifica rilevata.',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              ...diffs.map((final d) => _DiffRowDetailed(diff: d)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Sovrascrivi'),
        ),
      ],
    );
  }
}

class FieldDiff {
  const FieldDiff({
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  final String label;
  final String oldValue;
  final String newValue;
}

class DiffUtils {
  static List<FieldDiff> calculateDiffs({
    required final Contact existing,
    required final String newFirst,
    required final String newLast,
    required final String newPhone,
    required final String? newEmail,
  }) {
    final diffs = <FieldDiff>[];

    // Name Check
    final oldName = '${existing.name.first} ${existing.name.last}'.trim();
    final newName = '$newFirst $newLast'.trim();
    if (oldName != newName) {
      diffs.add(FieldDiff(label: 'Nome', oldValue: oldName, newValue: newName));
    }

    // Phone Check
    final normPhone = ContactService.normalizePhone(newPhone);
    final phoneChanged = !existing.phones.any(
      (final p) =>
          ContactService.normalizePhone(p.normalizedNumber) == normPhone,
    );

    if (phoneChanged) {
      diffs.add(
        FieldDiff(
          label: 'Telefono',
          oldValue: existing.phones.isNotEmpty
              ? existing.phones.first.number
              : 'Vuoto',
          newValue: newPhone,
        ),
      );
    }

    // Email Check
    final hasNewEmail = newEmail != null && newEmail.isNotEmpty;
    final emailChanged =
        hasNewEmail && !existing.emails.any((final e) => e.address == newEmail);

    if (emailChanged) {
      diffs.add(
        FieldDiff(
          label: 'Email',
          oldValue: existing.emails.isNotEmpty
              ? existing.emails.first.address
              : 'Vuoto',
          newValue: newEmail,
        ),
      );
    }

    return diffs;
  }
}

class _DiffRowCompact extends StatelessWidget {
  const _DiffRowCompact({required this.diff});

  final FieldDiff diff;

  @override
  Widget build(final BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 2.h),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 11.sp,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          TextSpan(
            text: '${diff.label}: ',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          TextSpan(
            text: diff.oldValue,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const TextSpan(
            text: '  ➜  ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          TextSpan(
            text: diff.newValue,
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _DiffRowDetailed extends StatelessWidget {
  const _DiffRowDetailed({required this.diff});

  final FieldDiff diff;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diff.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.outline,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.outlineVariant, width: 2),
              ),
            ),
            padding: EdgeInsets.only(left: 8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vecchio Valore
                if (diff.oldValue != 'Vuoto')
                  Text(
                    diff.oldValue,
                    style: TextStyle(
                      color: colorScheme.error,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: colorScheme.error,
                      fontSize: 13.sp,
                    ),
                  ),
                // Nuovo Valore
                Row(
                  children: [
                    if (diff.oldValue != 'Vuoto')
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 12.sp,
                        color: Colors.green,
                      ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        diff.newValue,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
