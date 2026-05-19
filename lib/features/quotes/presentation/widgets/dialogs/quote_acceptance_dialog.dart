import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/providers/offline_status_provider.dart';
import '../../../../fidelity/providers/fidelity_providers.dart';
import '../../../../packages/providers/packages_providers.dart';
import '../../../../payments/providers/payments_providers.dart';
import '../../../../quotes/providers/quotes_providers.dart';

class QuoteAcceptanceDialog extends ConsumerStatefulWidget {
  const QuoteAcceptanceDialog({required this.quoteId, super.key});

  final String quoteId;

  @override
  ConsumerState<QuoteAcceptanceDialog> createState() =>
      _QuoteAcceptanceDialogState();
}

class _QuoteAcceptanceDialogState extends ConsumerState<QuoteAcceptanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _packageNameController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  DateTime? _expiresAt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Imposta metodo di pagamento di default
    _paymentMethodController.text = PaymentMethod.cash.name;
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    _paidAmountController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final offlineReadOnly = ref.watch(isOfflineReadOnlyProvider);
    final quoteAsync = ref.watch<AsyncValue<QuoteData?>>(
      quoteStreamProvider(widget.quoteId),
    );

    return quoteAsync.when(
      data: (QuoteData? quote) {
        if (quote == null) {
          return const Center(child: Text('Preventivo non trovato'));
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: kIsWindows ? 80 : 16,
            vertical: 24,
          ),
          child: Container(
            width: kIsWindows ? 600 : double.infinity,
            constraints: const BoxConstraints(maxHeight: 700),
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
                _buildHeader(cs, quote),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuoteSummary(cs, quote),
                          const SizedBox(height: 24),
                          _buildSectionTitle(cs, 'DETTAGLI PACCHETTO'),
                          _buildPackageNameInput(),
                          const SizedBox(height: 16),
                          _buildExpiryDate(cs),
                          const SizedBox(height: 24),
                          _buildSectionTitle(cs, 'PAGAMENTO'),
                          _buildPaidAmountInput(),
                          const SizedBox(height: 16),
                          _buildPaymentMethodInput(),
                          const SizedBox(height: 24),
                          _buildPaymentSummary(cs, quote),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(cs, offlineReadOnly),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, _) => Center(child: Text('Errore: $error')),
    );
  }

  Widget _buildHeader(ColorScheme cs, QuoteData quote) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.check_circle_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accetta Preventivo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  quote.quoteNumber,
                  style: TextStyle(fontSize: 14, color: cs.outline),
                ),
              ],
            ),
          ),
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

  Widget _buildQuoteSummary(ColorScheme cs, QuoteData quote) {
    final quoteItemsAsync = ref.watch(quoteItemsStreamProvider(widget.quoteId));

    return quoteItemsAsync.when(
      data: (List<QuoteItemData> items) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Servizi inclusi:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.lockedServiceName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${item.sessions} sedut${item.sessions > 1 ? 'e' : 'a'}',
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                            if (item.discountAmount > 0) ...[
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Sconto: -€${item.discountAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.discountAmount > 0) ...[
                            Text(
                              '€${(item.lockedUnitPrice * item.sessions).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: cs.outline,
                              ),
                            ),
                            Text(
                              '€${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ] else
                            Text(
                              '€${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Totale:'),
                  Text(
                    '€${quote.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (quote.discountAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sconto:', style: TextStyle(color: cs.error)),
                    Text(
                      '-€${quote.discountAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: cs.error),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Errore caricamento servizi'),
    );
  }

  Widget _buildPackageNameInput() {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _packageNameController,
      decoration: InputDecoration(
        labelText: 'Nome pacchetto',
        prefixIcon: const Icon(Symbols.inventory_2_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
    );
  }

  Widget _buildExpiryDate(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate:
                  _expiresAt ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (date != null) {
              setState(() => _expiresAt = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Symbols.event_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _expiresAt == null
                        ? 'Nessuna scadenza (pacchetto senza data)'
                        : 'Scadenza: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                    style: TextStyle(
                      color: _expiresAt == null ? cs.outline : cs.onSurface,
                    ),
                  ),
                ),
                if (_expiresAt != null)
                  IconButton(
                    icon: const Icon(Symbols.clear_rounded, size: 18),
                    onPressed: () => setState(() => _expiresAt = null),
                    tooltip: 'Rimuovi scadenza',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tocca per ${_expiresAt == null ? 'impostare' : 'modificare'} la data, '
          'usa ✕ per rimuoverla',
          style: TextStyle(fontSize: 12, color: cs.outline),
        ),
      ],
    );
  }

  Widget _buildPaidAmountInput() {
    final cs = Theme.of(context).colorScheme;
    final quoteAsync = ref.watch<AsyncValue<QuoteData?>>(quoteStreamProvider(widget.quoteId));
    
    return quoteAsync.when(
      data: (quote) {
        if (quote == null) return const SizedBox.shrink();
        
        return TextFormField(
          controller: _paidAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Importo pagato (€)',
            prefixIcon: const Icon(Symbols.euro_rounded),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Campo obbligatorio';
            final amount = double.tryParse(v);
            if (amount == null || amount < 0) return 'Importo non valido';
            
            // Validate that payment doesn't exceed total after discount
            final finalPrice = quote.totalPrice - quote.discountAmount;
            if (amount > finalPrice) {
              return 'Importo non può superare il totale di €${finalPrice.toStringAsFixed(2)}';
            }
            return null;
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPaymentMethodInput() {
    final cs = Theme.of(context).colorScheme;

    // Ottieni il valore corrente dall'enum
    PaymentMethod currentMethod;
    try {
      currentMethod = PaymentMethod.fromString(_paymentMethodController.text);
    } catch (_) {
      currentMethod = PaymentMethod.cash;
    }

    return DropdownButtonFormField<PaymentMethod>(
      value: currentMethod,
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
          _paymentMethodController.text = value.name;
        }
      },
      validator: (v) => v == null ? 'Seleziona un metodo' : null,
    );
  }

  Widget _buildPaymentSummary(ColorScheme cs, QuoteData quote) {
    final paid = double.tryParse(_paidAmountController.text) ?? 0;
    final remaining = quote.totalPrice - quote.discountAmount - paid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Totale preventivo:'),
              Text('€${quote.totalPrice.toStringAsFixed(2)}'),
            ],
          ),
          if (quote.discountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sconto:', style: TextStyle(color: cs.error)),
                Text(
                  '-€${quote.discountAmount.toStringAsFixed(2)}',
                  style: TextStyle(color: cs.error),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pagato:'),
              Text('€${paid.toStringAsFixed(2)}'),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rimanente:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: remaining > 0 ? cs.error : cs.primary,
                ),
              ),
              Text(
                '€${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: remaining > 0 ? cs.error : cs.primary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs, bool offlineReadOnly) {
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
              onPressed: (_isLoading || offlineReadOnly) ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crea Pacchetto'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final quote = await ref
          .read(quotesActionsProvider)
          .getQuoteById(widget.quoteId);
      if (quote == null) {
        _showError('Preventivo non trovato');
        return;
      }

      if (quote.clientId == null || quote.clientId!.isEmpty) {
        _showError('Il preventivo non è associato a nessun cliente');
        return;
      }

      final quoteItems = await ref
          .read(quotesActionsProvider)
          .getQuoteItemsByQuoteId(widget.quoteId);
      final packageItems = quoteItems.map((QuoteItemData item) {
        return PackageItemData(
          id: '',
          // Will be generated by repository
          packageId: '',
          // Will be set by repository
          serviceId: item.serviceId,
          lockedServiceName: item.lockedServiceName,
          lockedUnitPrice: item.lockedUnitPrice,
          totalSessions: item.sessions,
          // Use sessions from quote item
          usedSessions: 0,
        );
      }).toList();

      final paid = double.tryParse(_paidAmountController.text) ?? 0;

      // Create package with DISCOUNTED price (fix bug: use final price after discount)
      final finalPrice = quote.totalPrice - quote.discountAmount;
      final packageId = await ref
          .read(packagesActionsProvider)
          .createPackage(
            clientId: quote.clientId!,
            name: _packageNameController.text.trim(),
            totalPrice: finalPrice,
            quoteId: widget.quoteId,
            expiresAt: _expiresAt,
            notes: null,
            items: packageItems,
          );

      // Update quote status
      await ref
          .read(quotesActionsProvider)
          .updateQuoteStatus(id: widget.quoteId, status: 'accepted');

      // Create payment if amount > 0
      if (paid > 0) {
        final paymentMethod = _paymentMethodController.text.trim();

        // Gestione pagamento fidelity
        if (paymentMethod == PaymentMethod.fidelity.name) {
          // Recupera carte fidelity attive del cliente
          final fidelityCards = await ref
              .read(fidelityActionsProvider)
              .getActiveFidelityCardsByClientId(quote.clientId!);

          if (fidelityCards.isEmpty) {
            _showError(
              'Nessuna carta fidelity attiva trovata per questo cliente',
            );
            setState(() => _isLoading = false);
            return;
          }

          // Trova una carta con saldo sufficiente
          final cardWithBalance = fidelityCards.firstWhere(
            (card) => card.balance >= paid,
            orElse: () => fidelityCards.first,
          );

          if (cardWithBalance.balance < paid) {
            _showError(
              'Credito insufficiente. Saldo disponibile: €${cardWithBalance.balance.toStringAsFixed(2)}. '
              'Importo richiesto: €${paid.toStringAsFixed(2)}',
            );
            setState(() => _isLoading = false);
            return;
          }

          // Scala il credito dalla carta
          await ref
              .read(fidelityActionsProvider)
              .addUsage(
                cardId: cardWithBalance.id,
                amount: paid,
                description:
                    'Pagamento pacchetto: ${_packageNameController.text.trim()}',
              );
        }

        await ref
            .read(paymentsActionsProvider)
            .createPayment(
              clientId: quote.clientId!,
              amount: paid,
              paymentMethod: paymentMethod.isEmpty ? 'Contanti' : paymentMethod,
              packageId: packageId,
            );

        // Update package paid amount
        if (packageId != null) {
          await ref
              .read(packagesActionsProvider)
              .updatePackagePaidAmount(id: packageId, paidAmount: paid);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pacchetto creato con successo')),
        );
      }
    } catch (e) {
      _showError('Errore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cs.error));
  }
}
