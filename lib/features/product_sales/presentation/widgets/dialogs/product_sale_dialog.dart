import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/database/providers/app_database_provider.dart';
import '../../../../../core/providers/offline_status_provider.dart';
import '../../../../../core/services/financial_service.dart';
import '../../../../fidelity/providers/fidelity_providers.dart';
import '../../../../products/providers/products_providers.dart';

/// Item nel carrello con prodotto e quantità
class _CartItem {
  _CartItem({required this.product, required this.quantity});

  final ProductData product;
  int quantity;

  double get lineTotal => product.price * quantity;
}

class ProductSaleDialog extends ConsumerStatefulWidget {
  const ProductSaleDialog({required this.clientId, super.key});

  final String clientId;

  @override
  ConsumerState<ProductSaleDialog> createState() => _ProductSaleDialogState();
}

class _ProductSaleDialogState extends ConsumerState<ProductSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _discountController = TextEditingController();
  final List<_CartItem> _cart = [];
  bool _isLoading = false;
  DiscountType _discountType = DiscountType.fixed;
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  /// Prodotti filtrati dalla ricerca
  List<ProductData> _getFilteredProducts(List<ProductData> allProducts) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return allProducts;
    return allProducts
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  /// Prodotti già nel carrello (per mostrarli prima)
  List<ProductData> _getOrderedProducts(List<ProductData> allProducts) {
    final filtered = _getFilteredProducts(allProducts);
    final cartIds = _cart.map((i) => i.product.id).toSet();

    final inCart = filtered.where((p) => cartIds.contains(p.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final notInCart = filtered.where((p) => !cartIds.contains(p.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return [...inCart, ...notInCart];
  }

  void _addToCart(ProductData product) {
    setState(() {
      final existing = _cart.firstWhereOrNull(
        (i) => i.product.id == product.id,
      );
      if (existing != null) {
        existing.quantity++;
      } else {
        _cart.add(_CartItem(product: product, quantity: 1));
      }
    });
  }

  void _updateQuantity(String productId, int delta) {
    setState(() {
      final index = _cart.indexWhere((i) => i.product.id == productId);
      if (index >= 0) {
        final newQty = _cart[index].quantity + delta;
        if (newQty <= 0) {
          _cart.removeAt(index);
        } else {
          _cart[index].quantity = newQty;
        }
      }
    });
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get _discountAmount {
    final discountValue = double.tryParse(_discountController.text) ?? 0;
    if (discountValue <= 0) return 0;

    if (_discountType == DiscountType.percentage) {
      final percentage = discountValue > kMaxDiscountPercentage
          ? kMaxDiscountPercentage
          : discountValue;
      return _subtotal * (percentage / 100);
    } else {
      return discountValue > _subtotal ? _subtotal : discountValue;
    }
  }

  double get _finalTotal => _subtotal - _discountAmount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final products = ref.watch(productsStreamProvider).value ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      _buildSectionTitle(cs, 'CARRELLO'),
                      _buildCartSection(cs),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildSectionTitle(cs, 'AGGIUNGI PRODOTTI'),
                      _buildSearchField(cs),
                      const SizedBox(height: 12),
                      _buildProductList(_getOrderedProducts(products), cs),
                      const SizedBox(height: 24),
                      _buildSectionTitle(cs, 'SCONTO'),
                      _buildDiscountInput(cs),
                      const SizedBox(height: 24),
                      _buildSectionTitle(cs, 'PAGAMENTO'),
                      _buildPaymentMethodInput(cs),
                      const SizedBox(height: 24),
                      _buildTotalSummary(cs),
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
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.shopping_cart_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            'Vendita Prodotti',
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: cs.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCartSection(ColorScheme cs) {
    if (_cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Symbols.shopping_cart_rounded, size: 48, color: cs.outline),
              const SizedBox(height: 8),
              Text('Carrello vuoto', style: TextStyle(color: cs.outline)),
              const SizedBox(height: 4),
              Text(
                'Cerca e aggiungi prodotti qui sotto',
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _cart
          .map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: Icon(Symbols.shopping_bag_rounded, color: cs.primary),
                title: Text(item.product.name),
                subtitle: Text(
                  '€${item.product.price.toStringAsFixed(2)} × ${item.quantity} = '
                  '€${item.lineTotal.toStringAsFixed(2)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.remove_rounded, size: 18),
                      onPressed: () => _updateQuantity(item.product.id, -1),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.add_rounded, size: 18),
                      onPressed: () => _updateQuantity(item.product.id, 1),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSearchField(ColorScheme cs) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Cerca prodotti...',
        prefixIcon: const Icon(Symbols.search_rounded),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Symbols.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProductList(List<ProductData> products, ColorScheme cs) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _searchController.text.isEmpty
                ? 'Nessun prodotto disponibile'
                : 'Nessun prodotto trovato',
            style: TextStyle(color: cs.outline),
          ),
        ),
      );
    }

    // Separa selezionati e non
    final cartIds = _cart.map((i) => i.product.id).toSet();
    final selectedProducts = products
        .where((p) => cartIds.contains(p.id))
        .toList();
    final unselectedProducts = products
        .where((p) => !cartIds.contains(p.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedProducts.isNotEmpty) ...[
          ...selectedProducts.map(
            (p) => _buildProductTile(p, cs, isSelected: true),
          ),
          if (unselectedProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ],
        ...unselectedProducts.map(
          (p) => _buildProductTile(p, cs, isSelected: false),
        ),
      ],
    );
  }

  Widget _buildProductTile(
    ProductData product,
    ColorScheme cs, {
    required bool isSelected,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? cs.primaryContainer.withValues(alpha: 0.2) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: isSelected
            ? Icon(Icons.check_circle, color: cs.primary)
            : Icon(Symbols.shopping_bag_rounded, color: cs.outline),
        title: Text(product.name),
        subtitle: Text('€${product.price.toStringAsFixed(2)}'),
        trailing: isSelected
            ? const Icon(Icons.check, color: Colors.green)
            : IconButton(
                icon: const Icon(Symbols.add_rounded),
                onPressed: () => _addToCart(product),
                style: IconButton.styleFrom(
                  backgroundColor: cs.primaryContainer,
                ),
              ),
        onTap: () => _addToCart(product),
      ),
    );
  }

  Widget _buildDiscountInput(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<DiscountType>(
          segments: [
            ButtonSegment(
              value: DiscountType.fixed,
              label: const Text('€ Fisso'),
              icon: const Icon(Symbols.euro_rounded),
            ),
            ButtonSegment(
              value: DiscountType.percentage,
              label: const Text('% Percentuale'),
              icon: const Icon(Symbols.percent_rounded),
            ),
          ],
          selected: {_discountType},
          onSelectionChanged: (set) {
            setState(() {
              _discountType = set.first;
              _discountController.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _discountController,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _discountType == DiscountType.fixed
                ? 'Sconto in euro'
                : 'Sconto in percentuale',
            hintText: _discountType == DiscountType.fixed
                ? 'Es: 10.50'
                : 'Es: 15',
            prefixIcon: const Icon(Symbols.local_offer_rounded),
            suffixText: _discountType == DiscountType.fixed ? '€' : '%',
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodInput(ColorScheme cs) {
    return DropdownButtonFormField<PaymentMethod>(
      value: _paymentMethod,
      decoration: InputDecoration(
        labelText: 'Metodo di pagamento',
        prefixIcon: const Icon(Symbols.credit_card_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: PaymentMethod.values.map((method) {
        IconData icon;
        switch (method) {
          case PaymentMethod.cash:
            icon = Symbols.payments_rounded;
          case PaymentMethod.card:
            icon = Symbols.credit_card_rounded;
          case PaymentMethod.transfer:
            icon = Symbols.account_balance_rounded;
          case PaymentMethod.fidelity:
            icon = Symbols.style_rounded;
        }
        return DropdownMenuItem(
          value: method,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(method.displayName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _paymentMethod = value);
        }
      },
    );
  }

  Widget _buildTotalSummary(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Totale (${_cart.length} prodotti):'),
              Text('€${_subtotal.toStringAsFixed(2)}'),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _discountType == DiscountType.percentage
                      ? 'Sconto (${_discountController.text}%):'
                      : 'Sconto:',
                ),
                Text(
                  '-€${_discountAmount.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTALE FINALE:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              Text(
                '€${_finalTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    final offlineReadOnly = ref.watch(isOfflineReadOnlyProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
          ),
          const SizedBox(width: 12),
          if (offlineReadOnly)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.wifi_off_rounded, size: 16, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Text('Solo visualizzazione', style: TextStyle(fontSize: 14, color: cs.onErrorContainer)),
                ],
              ),
            ),
          Expanded(
            child: FilledButton(
              onPressed: _cart.isEmpty || _isLoading || offlineReadOnly ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Registra Vendita'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final totalAmount = _finalTotal;

      // CREA FINANCIAL SERVICE
      final financialService = FinancialService(
        db: ref.read(appDatabaseProvider),
        isOnline: !ref.read(isOfflineReadOnlyProvider),
      );

      // Gestione pagamento fidelity - verifica saldo PRIMA di qualsiasi operazione
      String? fidelityCardId;
      if (_paymentMethod == PaymentMethod.fidelity) {
        final fidelityCards = await ref.read(fidelityActionsProvider)
            .getActiveFidelityCardsByClientId(widget.clientId);

        if (fidelityCards.isEmpty) {
          _showError('Nessuna carta fidelity attiva trovata per questo cliente');
          setState(() => _isLoading = false);
          return;
        }

        final cardWithBalance = fidelityCards.firstWhere(
          (card) => card.balance >= totalAmount,
          orElse: () => fidelityCards.first,
        );

        if (cardWithBalance.balance < totalAmount) {
          _showError(
            'Credito insufficiente. Saldo disponibile: €${cardWithBalance.balance.toStringAsFixed(2)}. '
            'Importo richiesto: €${totalAmount.toStringAsFixed(2)}',
          );
          setState(() => _isLoading = false);
          return;
        }
        fidelityCardId = cardWithBalance.id;
      }

      // Calculate discount per unit
      final discountPerUnit = _cart.isEmpty ? 0.0 : _discountAmount / _cart.fold(0.0, (sum, item) => sum + item.quantity);
      
      // Per ogni prodotto nel carrello, usa FinancialService per operazione ATOMICA
      for (final item in _cart) {
        // Calculate the discounted unit price for this item
        final originalUnitPrice = item.product.price;
        final discountedUnitPrice = originalUnitPrice - discountPerUnit;
        
        // Ensure we don't go below zero
        final finalUnitPrice = discountedUnitPrice > 0 ? discountedUnitPrice : 0.0;
        
        // Per pagamenti fidelity, creiamo vendita con pagamento 'fidelity' 
        // che verrà stornato/scalato dal saldo fidelity dopo
        final result = await financialService.createProductSaleWithPayment(
          clientId: widget.clientId,
          productId: item.product.id,
          lockedProductName: item.product.name,
          lockedPrice: originalUnitPrice, // Keep original price for reference
          quantity: item.quantity,
          paymentMethod: _paymentMethod == PaymentMethod.fidelity 
            ? 'fidelity' 
            : _paymentMethod.name,
          notes: 'Acquisto prodotto: ${item.product.name} (x${item.quantity})',
          discountedPrice: finalUnitPrice, // Pass the discounted price
        );

        if (!result.success) {
          throw Exception('Errore creazione vendita: ${result.error?.message}');
        }
      }

      // Se pagamento fidelity, scala il saldo in modo atomico
      if (_paymentMethod == PaymentMethod.fidelity && fidelityCardId != null) {
        final fidelityResult = await financialService.useFidelityBalance(
          cardId: fidelityCardId,
          amount: totalAmount,
          description: 'Acquisto prodotti (${_cart.length} articoli)',
        );

        if (!fidelityResult.success) {
          throw Exception('Errore scalatura fidelity: ${fidelityResult.error?.message}');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vendita di ${_cart.length} prodotti registrata con successo',
            ),
          ),
        );
      }
    } on FinancialException catch (e) {
      _showError('Errore finanziario: ${e.message}');
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cs.error,
      ),
    );
  }
}
