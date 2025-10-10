import 'package:beauty_center/core/database/extensions/db_models_extensions.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/widgets/section_card.dart';
import '../../providers/settings_provider.dart';

class OperatorsSection extends ConsumerWidget {
  const OperatorsSection({required this.operators, super.key});

  final List<Operator> operators;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.read(settingsActionsProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  min: kMinOperatorsCount.toDouble(),
                  max: kMaxOperatorsCount.toDouble(),
                  divisions: kMaxOperatorsCount - kMinOperatorsCount,
                  value: operators.length.toDouble().clamp(1.0, 5.0),
                  label: '${operators.length}',
                  onChanged: (final v) => actions.setOperatorsCount(v.round()),
                ),
              ),
              SizedBox(
                width: kIsWindows ? 40 : 40.w,
                child: Center(
                  child: Text(
                    '${operators.length}',
                    key: ValueKey<int>(operators.length),
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
          ...operators.asMap().entries.map(
            (final entry) =>
                _OperatorRow(index: entry.key, operator: entry.value),
          ),
        ],
      ),
    );
  }
}

class _OperatorRow extends ConsumerStatefulWidget {
  const _OperatorRow({required this.index, required this.operator});

  final int index;
  final Operator operator;

  @override
  ConsumerState<_OperatorRow> createState() => _OperatorRowState();
}

class _OperatorRowState extends ConsumerState<_OperatorRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.operator.name);
    _focusNode = FocusNode();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave() {
    final newName = _controller.text.trim();
    if (newName != widget.operator.name) {
      ref
          .read(settingsActionsProvider)
          .updateOperatorName(id: widget.operator.id, name: newName);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: kIsWindows ? 5 : 5.h),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: kIsWindows ? 20 : 20.h),
            child: CircleAvatar(
              radius: kIsWindows ? 22 : 22.r,
              backgroundColor: colorScheme.primary,
              child: Text(
                widget.operator.displayNumber,
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
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, _, _) => TextField(
                controller: _controller,
                focusNode: _focusNode,
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
                  counterText:
                      '${_controller.text.length}/$kMaxOperatorsNameLength',
                ),
                onSubmitted: (_) => _onSave(),
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
        ],
      ),
    );
  }
}
