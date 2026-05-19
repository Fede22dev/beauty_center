import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../providers/products_providers.dart';
import '../widgets/add_edit_product_dialog.dart';
import '../widgets/sections/list/products_list_section.dart';
import '../widgets/sections/products_search_add_bar_section.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final _log = AppLogger.getLogger(name: 'ProductsPage');

  late final ScrollController _scrollController;
  late final double _scrollbarThickness;
  var _isScrollbarNeeded = false;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollbarThickness = kIsWindows ? 8.0 : 0.0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(final String query) {
    setState(() => _searchQuery = query);
    _log.finest('Products search query: $query');
  }

  Future<void> _onAddProduct() async {
    _log.finest('Add product button pressed');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddEditProductDialog(),
    );

    if (result == true) {
      _log.finest(
        'Product was added, list should refresh automatically via stream',
      );
    }
  }

  void _onProductTap(final String productId) {
    _log.finest('Product tapped: $productId');
    _onProductEdit(productId);
  }

  Future<void> _onProductEdit(final String productId) async {
    final product = await ref
        .read(productsActionsProvider)
        .getProductById(productId);
    if (product == null || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddEditProductDialog(
        product: product,
        mode: ProductDialogMode.edit,
      ),
    );

    if (result == true) {
      _log.finest('Product was edited');
    }
  }

  Future<void> _onProductDelete(final String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (final ctx) => AlertDialog(
        icon: Icon(
          Symbols.warning_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: kIsWindows ? 32 : 32.sp,
        ),
        title: const Text('Elimina prodotto'),
        content: const Text(
          'Sei sicuro di voler eliminare questo prodotto? L\'azione è irreversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(productsActionsProvider).deleteProduct(productId);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Prodotto eliminato con successo',
          okColor: AppTabs.products.color,
        );
      }
    } catch (e, stackTrace) {
      _log.severe('Error deleting product', e, stackTrace);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Errore durante l\'eliminazione',
          okColor: AppTabs.products.color,
        );
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    super.build(context);

    if (_scrollbarThickness > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isNeeded =
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0;
        if (isNeeded != _isScrollbarNeeded) {
          setState(() => _isScrollbarNeeded = isNeeded);
        }
      });
    }

    _log.finest('build');

    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            kIsWindows ? 16 : 8.w,
            kIsWindows ? 12 : 8.h,
            kIsWindows ? 16 : 8.w,
            kIsWindows ? 12 : 8.h,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SectionProductsSearchAddBar(
            onSearchChanged: _onSearchChanged,
            onAddProduct: _onAddProduct,
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thickness: _scrollbarThickness,
            thumbVisibility: kIsWindows,
            interactive: kIsWindows,
            child: SectionProductList(
              searchQuery: _searchQuery,
              onProductTap: _onProductTap,
              onProductEdit: _onProductEdit,
              onProductDelete: _onProductDelete,
              scrollController: _scrollController,
            ),
          ),
        ),
        const SafeArea(top: false, child: SizedBox.shrink()),
      ],
    );
  }
}
