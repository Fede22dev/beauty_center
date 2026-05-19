import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/providers/offline_status_provider.dart';
import '../../../../fidelity/providers/fidelity_providers.dart';

class FidelityTopupDialog extends ConsumerStatefulWidget {
  const FidelityTopupDialog({
    required this.clientId,
    super.key,
  });

  final String clientId;

  @override
  ConsumerState<FidelityTopupDialog> createState() => _FidelityTopupDialogState();
}

class _FidelityTopupDialogState extends ConsumerState<FidelityTopupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cardNumberController = TextEditingController();
  bool _isLoading = false;
  bool _isGift = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final offlineReadOnly = ref.watch(isOfflineReadOnlyProvider);
    final existingCardsAsync = ref.watch(activeFidelityCardsByClientStreamProvider(widget.clientId));
    final existingCards = existingCardsAsync.value ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 80 : 16,
        vertical: 24,
      ),
      child: Container(
        width: kIsWindows ? 500 : double.infinity,
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
                      _buildSectionTitle(cs, 'CARTE ESISTENTI'),
                      _buildExistingCards(existingCards),
                      const SizedBox(height: 24),
                      _buildSectionTitle(cs, 'NUOVA RICARICA/REGALO'),
                      _buildGiftToggle(cs),
                      const SizedBox(height: 16),
                      if (_isGift) _buildCardNumberInput(),
                      if (_isGift) const SizedBox(height: 16),
                      _buildAmountInput(),
                      const SizedBox(height: 16),
                      _buildDescriptionInput(),
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
          const Icon(Symbols.style_rounded, color: Colors.purple),
          const SizedBox(width: 12),
          Text(
            'Ricarica Fidelity',
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

  Widget _buildExistingCards(List<FidelityCardData> existingCards) {
    final cs = Theme.of(context).colorScheme;
    if (existingCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Nessuna carta fidelity attiva per questo cliente',
          style: TextStyle(color: cs.outline),
        ),
      );
    }

    return Column(
      children: existingCards.map<Widget>((card) {
        return ListTile(
          leading: const Icon(Symbols.style_rounded),
          title: Text('Carta #${card.cardNumber}'),
          subtitle: Text('Saldo: €${card.balance.toStringAsFixed(2)}'),
          trailing: TextButton(
            onPressed: () => _topupExistingCard(card.id),
            child: const Text('Ricarica'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGiftToggle(ColorScheme cs) {
    return SwitchListTile(
      title: const Text('Crea come regalo'),
      subtitle: const Text('Genera una nuova carta fidelity'),
      value: _isGift,
      onChanged: (value) => setState(() => _isGift = value),
    );
  }

  Widget _buildCardNumberInput() {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _cardNumberController,
      decoration: InputDecoration(
        labelText: 'Numero carta (opzionale)',
        hintText: 'Lascia vuoto per generazione automatica',
        prefixIcon: const Icon(Symbols.tag_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Importo (€)',
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
        if (amount == null || amount <= 0) return 'Importo non valido';
        return null;
      },
    );
  }

  Widget _buildDescriptionInput() {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Descrizione (opzionale)',
        prefixIcon: const Icon(Symbols.note_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
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
                  : const Text('Conferma'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _topupExistingCard(String cardId) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Inserisci un importo valido');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(fidelityActionsProvider).addTopup(
            cardId: cardId,
            amount: amount,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ricarica effettuata con successo')),
        );
      }
    } catch (e) {
      _showError('Errore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    try {
      if (_isGift) {
        // Auto-generate card number if not provided
        var cardNumber = _cardNumberController.text.trim();
        if (cardNumber.isEmpty) {
          final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          cardNumber = 'GIFT-$timestamp';
        }

        await ref.read(fidelityActionsProvider).createFidelityCard(
              clientId: widget.clientId,
              cardNumber: cardNumber,
              initialBalance: amount,
              isGift: true,
              giftNote: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
            );
      } else {
        final existingCards = ref.read(activeFidelityCardsByClientStreamProvider(widget.clientId)).value ?? [];
        if (existingCards.isEmpty) {
          _showError('Nessuna carta fidelity attiva per questo cliente');
          return;
        }
        await ref.read(fidelityActionsProvider).addTopup(
              cardId: existingCards.first.id,
              amount: amount,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
            );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operazione completata con successo')),
        );
      }
    } catch (e) {
      _showError('Errore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cs.error,
      ),
    );
  }
}
