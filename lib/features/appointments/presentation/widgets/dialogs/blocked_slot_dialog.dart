import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/providers/offline_status_provider.dart';
import '../../../../settings/providers/settings_providers.dart';
import '../../../models/blocked_slot_recurrence.dart';
import '../../../providers/operator_blocked_slots_providers.dart';
import '../common/appointments_date_picker_dialog.dart';

class BlockedSlotDialog extends ConsumerStatefulWidget {
  const BlockedSlotDialog({
    super.key,
    this.existingSlot,
    this.initialDate,
    this.initialOperatorId,
  });

  final OperatorBlockedSlot? existingSlot;
  final DateTime? initialDate;
  final int? initialOperatorId;

  @override
  ConsumerState<BlockedSlotDialog> createState() => _BlockedSlotDialogState();
}

class _BlockedSlotDialogState extends ConsumerState<BlockedSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _reasonCtrl;
  late int _operatorId;
  late DateTime _startTime;
  late DateTime _endTime;
  BlockedSlotRecurrence _recurrence = BlockedSlotRecurrence.none;
  DateTime? _until;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSlot;
    final now = DateTime.now();
    final baseDate = s?.startDateTime ?? widget.initialDate ?? now;

    _operatorId = s?.operatorId ?? widget.initialOperatorId ?? 1;
    _startTime =
        s?.startDateTime ??
        DateTime(baseDate.year, baseDate.month, baseDate.day, now.hour, 0);
    _endTime = s?.endDateTime ?? _startTime.add(const Duration(hours: 1));
    _reasonCtrl = TextEditingController(text: s?.reason ?? '');
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recurrence != BlockedSlotRecurrence.none && _until == null) {
      _showError('Seleziona la data di fine ricorrenza');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final actions = ref.read(blockedSlotActionsProvider);
      final reason = _reasonCtrl.text.trim().isEmpty
          ? null
          : _reasonCtrl.text.trim();

      if (widget.existingSlot != null) {
        // Se fa parte di una serie, chiedi se modificare solo questo o tutta la serie
        if (widget.existingSlot!.seriesId != null) {
          final mode = await _showSeriesEditDialog();
          if (mode == null) {
            setState(() => _isLoading = false);
            return;
          }
          if (mode == 'series') {
            await actions.updateRecurrenceBlockedSlots(
              seriesId: widget.existingSlot!.seriesId!,
              operatorId: _operatorId,
              startDateTime: _startTime,
              endDateTime: _endTime,
              reason: reason,
            );
          } else {
            await actions.updateBlockedSlot(
              id: widget.existingSlot!.id,
              operatorId: _operatorId,
              startDateTime: _startTime,
              endDateTime: _endTime,
              reason: reason,
            );
          }
        } else {
          await actions.updateBlockedSlot(
            id: widget.existingSlot!.id,
            operatorId: _operatorId,
            startDateTime: _startTime,
            endDateTime: _endTime,
            reason: reason,
          );
        }
      } else if (_recurrence == BlockedSlotRecurrence.none) {
        await actions.createBlockedSlot(
          operatorId: _operatorId,
          startDateTime: _startTime,
          endDateTime: _endTime,
          reason: reason,
        );
      } else {
        await actions.createRecurrenceBlockedSlots(
          operatorId: _operatorId,
          startDateTime: _startTime,
          endDateTime: _endTime,
          reason: reason,
          recurrence: _recurrence,
          until: _until!,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Errore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showSeriesEditDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica blocco ricorrente'),
        content: const Text(
          'Questo blocco fa parte di una serie. Vuoi modificare solo questo blocco o tutta la serie?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'single'),
            child: const Text('SOLO QUESTO'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'series'),
            child: const Text('TUTTA LA SERIE'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final operators = ref.watch(operatorsStreamProvider).value ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: kIsWindows ? 460 : double.infinity,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(cs),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(cs, 'OPERATORE'),
                      _buildOperatorSelector(operators),
                      const SizedBox(height: 24),

                      _buildSectionTitle(cs, 'PERIODO'),
                      _buildDateTimeSelectors(cs),
                      const SizedBox(height: 24),

                      _buildSectionTitle(cs, 'MOTIVAZIONE'),
                      _buildReasonInput(),

                      if (widget.existingSlot == null) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(cs, 'RICORRENZA'),
                        _buildRecurrenceSection(cs),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Icon(Symbols.block_rounded, color: cs.error),
          const SizedBox(width: 12),
          Text(
            widget.existingSlot != null ? 'Modifica Blocco' : 'Nuovo Blocco',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Symbols.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: cs.error,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildOperatorSelector(List<Operator> operators) {
    return DropdownButtonFormField<int>(
      value: _operatorId,
      decoration: InputDecoration(
        prefixIcon: const Icon(Symbols.person_rounded),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: operators
          .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
          .toList(),
      onChanged: (v) => setState(() => _operatorId = v!),
    );
  }

  Widget _buildDateTimeSelectors(ColorScheme cs) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final picked = await showAppointmentsDatePickerDialog(
              context: context,
              selectedDay: _startTime,
            );
            if (picked != null) {
              setState(() {
                _startTime = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  _startTime.hour,
                  _startTime.minute,
                );
                _endTime = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  _endTime.hour,
                  _endTime.minute,
                );
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Symbols.calendar_today_rounded, size: 20, color: cs.error),
                const SizedBox(width: 12),
                Text(
                  '${_startTime.day}/${_startTime.month}/${_startTime.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Symbols.edit_rounded, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: 'Dalle',
                time: TimeOfDay.fromDateTime(_startTime),
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeBox(
                label: 'Alle',
                time: TimeOfDay.fromDateTime(_endTime),
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final base = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final updated = DateTime(
          base.year,
          base.month,
          base.day,
          picked.hour,
          picked.minute,
        );
        if (isStart) {
          _startTime = updated;
          if (_endTime.isBefore(_startTime))
            _endTime = _startTime.add(const Duration(hours: 1));
        } else {
          _endTime = updated;
        }
      });
    }
  }

  Widget _buildReasonInput() {
    return TextFormField(
      controller: _reasonCtrl,
      decoration: InputDecoration(
        hintText: 'Esempio: Pausa pranzo, Ferie, Formazione...',
        prefixIcon: const Icon(Symbols.notes_rounded),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection(ColorScheme cs) {
    return Column(
      children: [
        DropdownButtonFormField<BlockedSlotRecurrence>(
          value: _recurrence,
          decoration: InputDecoration(
            prefixIcon: const Icon(Symbols.repeat_rounded),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          items: BlockedSlotRecurrence.values
              .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
              .toList(),
          onChanged: (v) => setState(() => _recurrence = v!),
        ),
        if (_recurrence != BlockedSlotRecurrence.none) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _until ?? _startTime.add(const Duration(days: 7)),
                firstDate: _startTime,
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _until = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.event_repeat_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _until == null
                        ? 'Ripeti fino al...'
                        : 'Fino al ${_until!.day}/${_until!.month}/${_until!.year}',
                  ),
                  const Spacer(),
                  const Icon(Symbols.calendar_month_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    final offlineReadOnly = ref.watch(isOfflineReadOnlyProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.existingSlot != null)
            IconButton(
              icon: Icon(
                Symbols.delete_rounded,
                color: offlineReadOnly ? cs.outline : cs.error,
              ),
              onPressed: offlineReadOnly
                  ? null
                  : () async {
                      final deleteMode = await _showDeleteConfirm();
                      if (deleteMode == null) return;

                      try {
                        if (deleteMode == 'series') {
                          await ref
                              .read(blockedSlotActionsProvider)
                              .deleteRecurrenceBlockedSlots(widget.existingSlot!.seriesId!);
                        } else {
                          await ref
                              .read(blockedSlotActionsProvider)
                              .deleteBlockedSlot(widget.existingSlot!.id);
                        }
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _showError('Errore: $e');
                      }
                    },
              tooltip: offlineReadOnly ? 'Eliminazione disabilitata in modalità offline' : null,
            ),
          if (offlineReadOnly)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.wifi_off_rounded, size: 14, color: cs.onErrorContainer),
                  const SizedBox(width: 4),
                  Text(
                    'Solo visualizzazione',
                    style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                  ),
                ],
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: (_isLoading || offlineReadOnly) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SALVA BLOCCO'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDeleteConfirm() async {
    // Se fa parte di una serie, chiedi se eliminare solo questo o tutta la serie
    if (widget.existingSlot?.seriesId != null) {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Elimina blocco ricorrente'),
          content: const Text(
            'Questo blocco fa parte di una serie. Vuoi eliminare solo questo blocco o tutta la serie?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('ANNULLA'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'single'),
              child: const Text('SOLO QUESTO'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 'series'),
              child: const Text('TUTTA LA SERIE'),
            ),
          ],
        ),
      );
    }

    // Blocco singolo
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina blocco'),
        content: const Text(
          'Sei sicuro di voler eliminare questo blocco operatore?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ELIMINA',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return confirmed == true ? 'single' : null;
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
