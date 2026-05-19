import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/offline_status_provider.dart';
import '../../providers/products_providers.dart';

enum ProductDialogMode { add, edit }

class AddEditProductDialog extends ConsumerStatefulWidget {
  const AddEditProductDialog({
    this.product,
    this.mode = ProductDialogMode.add,
    super.key,
  });

  final ProductData? product;
  final ProductDialogMode mode;

  @override
  ConsumerState<AddEditProductDialog> createState() =>
      _AddEditProductDialogState();
}

class _AddEditProductDialogState extends ConsumerState<AddEditProductDialog> {
  static final _log = AppLogger.getLogger(name: 'AddEditProductDialog');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;

  var _isLoading = false;

  bool get _isEditMode =>
      widget.product != null && widget.mode == ProductDialogMode.edit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name);
    _priceController = TextEditingController(
      text: widget.product != null
          ? widget.product!.price.toStringAsFixed(2)
          : '',
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trimmedName = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final trimmedDescription = _descriptionController.text.trim();

      if (_isEditMode) {
        await ref.read(productsActionsProvider).updateProduct(
              id: widget.product!.id,
              name: trimmedName,
              price: price,
              description:
                  trimmedDescription.isEmpty ? null : trimmedDescription,
            );
      } else {
        await ref.read(productsActionsProvider).createProduct(
              name: trimmedName,
              price: price,
              description:
                  trimmedDescription.isEmpty ? null : trimmedDescription,
            );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
      showCustomSnackBar(
        context: context,
        message: _isEditMode
            ? 'Prodotto modificato con successo'
            : 'Prodotto aggiunto con successo',
        okColor: AppTabs.products.color,
      );
    } catch (e, stackTrace) {
      _log.severe('Error saving product', e, stackTrace);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Errore durante il salvataggio',
          okColor: AppTabs.products.color,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final offlineReadOnly = ref.watch(isOfflineReadOnlyProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: kIsWindows ? 500 : double.infinity,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(kIsWindows ? 20 : 20.sp),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(kIsWindows ? 28 : 28.r),
                  topRight: Radius.circular(kIsWindows ? 28 : 28.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditMode
                        ? Symbols.edit_rounded
                        : Symbols.experiment_rounded,
                    size: kIsWindows ? 28 : 28.sp,
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      _isEditMode
                          ? 'Modifica prodotto'
                          : 'Nuovo prodotto',
                      style: TextStyle(
                        fontSize: kIsWindows ? 20 : 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(kIsWindows ? 20 : 20.sp),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome *',
                          prefixIcon: Icon(Symbols.experiment_rounded),
                          helperText:
                              'Minimo $kMinProductNameLength, massimo $kMaxProductNameLength caratteri',
                        ),
                        maxLength: kMaxProductNameLength,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textCapitalization: TextCapitalization.words,
                        validator: (final value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Il nome è obbligatorio';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),

                      SizedBox(height: kIsWindows ? 16 : 16.h),

                      // Price
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Prezzo (€) *',
                          prefixIcon: Icon(Symbols.euro_rounded),
                          hintText: '0.00',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*[\.,]?\d{0,2}'),
                          ),
                        ],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (final value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Il prezzo è obbligatorio';
                          }
                          final parsed =
                              double.tryParse(trimmed.replaceAll(',', '.'));
                          if (parsed == null || parsed < 0) {
                            return 'Inserisci un prezzo valido';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),

                      SizedBox(height: kIsWindows ? 16 : 16.h),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                          prefixIcon: Icon(Symbols.note_rounded),
                          helperText:
                              'Massimo $kMaxProductDescriptionLength caratteri',
                        ),
                        maxLength: kMaxProductDescriptionLength,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(kIsWindows ? 20 : 20.sp),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(kIsWindows ? 28 : 28.r),
                  bottomRight: Radius.circular(kIsWindows ? 28 : 28.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  if (offlineReadOnly)
                    Container(
                      margin: EdgeInsets.only(right: kIsWindows ? 12 : 12.w),
                      padding: EdgeInsets.symmetric(horizontal: kIsWindows ? 8 : 8.w, vertical: kIsWindows ? 4 : 4.sp),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Symbols.wifi_off_rounded, size: kIsWindows ? 14 : 14.sp, color: colorScheme.onErrorContainer),
                          SizedBox(width: kIsWindows ? 4 : 4.w),
                          Text('Offline', style: TextStyle(fontSize: kIsWindows ? 12 : 12.sp, color: colorScheme.onErrorContainer)),
                        ],
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: (_isLoading || offlineReadOnly) ? null : _saveProduct,
                    icon: _isLoading
                        ? SizedBox(
                            width: kIsWindows ? 20 : 20.sp,
                            height: kIsWindows ? 20 : 20.sp,
                            child: CircularProgressIndicator(
                              strokeWidth: kIsWindows ? 2 : 2.w,
                            ),
                          )
                        : Icon(
                            _isEditMode
                                ? Symbols.save_rounded
                                : Symbols.add_rounded,
                          ),
                    label: Text(_isEditMode ? 'Salva' : 'Aggiungi'),
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
