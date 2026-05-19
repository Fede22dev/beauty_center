import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/connectivity/connectivity_providers.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/providers/supabase_auth_provider.dart';
import '../../../../../core/widgets/app_error_view.dart';
import '../../../../../core/widgets/custom_snackbar.dart';
import '../../../../../core/widgets/section_card.dart';
import '../../../providers/settings_providers.dart';

class SettingsOperatorsSection extends ConsumerWidget {
  const SettingsOperatorsSection({required this.operators, super.key});

  final List<Operator> operators;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final isOffline = ref.watch(isConnectionUnusableProvider);
    final isDisconnectedSup = ref.watch(supabaseAuthProvider).isDisconnected;
    final actions = ref.read(settingsActionsProvider);

    final maxOperatorsAsync = ref.watch(maxOperatorsStreamProvider);

    // Error handling
    if (maxOperatorsAsync.hasError) {
      return AppErrorView(
        error: maxOperatorsAsync.error.toString(),
        onRetry: () {
          // Invalidate streams to retry
          ref.invalidate(maxOperatorsStreamProvider);
        },
      );
    }

    // Loading state
    if (!maxOperatorsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    // Extract data
    final maxOperatorsCount = maxOperatorsAsync.value!;

    final canAddMore = operators.length < maxOperatorsCount;
    final isSystemOffline = isOffline || isDisconnectedSup;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Symbols.people,
                    size: kIsWindows ? 28 : 28.sp,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: kIsWindows ? 8 : 8.w),
                  Text(
                    context.l10n.operators,
                    style: TextStyle(
                      fontSize: kIsWindows ? 24 : 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // BOTTONE AGGIUNGI AL POSTO DELLO SLIDER
              IconButton.filledTonal(
                onPressed: (isSystemOffline || !canAddMore)
                    ? null
                    : actions.addOperator,
                icon: const Icon(Symbols.person_add),
                tooltip: 'Aggiungi Operatore',
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 16 : 16.h),

          // LISTA DEGLI OPERATORI
          ...operators.map(
            (final operator) => _OperatorRow(
              key: ValueKey(operator.id),
              operator: operator,
              isOffline: isSystemOffline,
              canDelete:
                  operators.length >
                  kMinOperatorsCount, // Evita di cancellarli tutti
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// OperatorRow
// =======================================================

class _OperatorRow extends ConsumerStatefulWidget {
  const _OperatorRow({
    required this.operator,
    required this.isOffline,
    required this.canDelete,
    super.key,
  });

  final Operator operator;
  final bool isOffline;
  final bool canDelete;

  @override
  ConsumerState<_OperatorRow> createState() => _OperatorRowState();
}

class _OperatorRowState extends ConsumerState<_OperatorRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  void _onTextChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.operator.name);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  // Se l'operatore viene aggiornato dall'esterno (es. sync Supabase)
  @override
  void didUpdateWidget(covariant _OperatorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operator.name != widget.operator.name &&
        _controller.text != widget.operator.name) {
      _controller.text = widget.operator.name;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave() {
    final newName = _controller.text.trim();
    if (newName != widget.operator.name && newName.isNotEmpty) {
      ref
          .read(settingsActionsProvider)
          .updateOperatorName(id: widget.operator.id, name: newName);
    } else if (newName.isEmpty) {
      _controller.text = widget.operator.name; // Ripristina se vuoto
    }
  }

  void _onDelete() {
    // Mostra conferma prima di cancellare
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vuoi eliminare ${widget.operator.name}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(settingsActionsProvider)
                  .deleteOperator(id: widget.operator.id);
            },
            child: Text(
              'Elimina',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: kIsWindows ? 8 : 8.h),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: kIsWindows ? 20 : 20.h),
            child: CircleAvatar(
              radius: kIsWindows ? 22 : 22.r,
              backgroundColor: colorScheme.primary,
              child: Text(
                widget.operator.id.toString(),
                style: TextStyle(
                  fontSize: kIsWindows ? 16 : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: kIsWindows ? 16 : 16.w),
          Expanded(
            child: Opacity(
              opacity: widget.isOffline ? 0.6 : 1.0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                readOnly: widget.isOffline,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZÀ-ÿ\s]')),
                  LengthLimitingTextInputFormatter(kMaxOperatorsNameLength),
                ],
                decoration: InputDecoration(
                  labelText: context.l10n.name,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: kIsWindows ? 16 : 16.w,
                    vertical: kIsWindows ? 14 : 14.h,
                  ),
                ),
                onTap: () {
                  if (widget.isOffline && context.mounted) {
                    _focusNode.unfocus();
                    showCustomSnackBar(
                      context: context,
                      message: context.l10n.offlineNoChangeData,
                      okColor: AppTabs.settings.color,
                    );
                  }
                },
                onSubmitted: (_) => _onSave,
                onEditingComplete: () {
                  _focusNode.unfocus();
                  _onSave();
                },
                onTapOutside: (_) {
                  _focusNode.unfocus();
                  _onSave();
                },
              ),
            ),
          ),
          SizedBox(width: kIsWindows ? 8 : 8.w),
          // BOTTONE ELIMINA SPECIFICO PER QUESTA RIGA
          IconButton(
            onPressed: (widget.isOffline || !widget.canDelete)
                ? null
                : _onDelete,
            icon: const Icon(Symbols.delete),
            color: colorScheme.error,
            tooltip: 'Elimina operatore',
          ),
        ],
      ),
    );
  }
}
