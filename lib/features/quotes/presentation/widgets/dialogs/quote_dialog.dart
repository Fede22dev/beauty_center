import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/providers/offline_status_provider.dart';
import '../../../../quotes/providers/quotes_providers.dart';
import '../../../../treatments/providers/treatments_providers.dart';

class QuoteDialog extends ConsumerStatefulWidget {
  const QuoteDialog({required this.clientId, super.key});

  final String clientId;

  @override
  ConsumerState<QuoteDialog> createState() => _QuoteDialogState();
}

/// Rappresenta un servizio selezionato con la sua quantità e sconto
class _SelectedService {
  final String serviceId;
  int quantity;
  DiscountType discountType;
  double discountAmount;

  _SelectedService({
    required this.serviceId,
    this.quantity = 1,
  })  : discountType = DiscountType.fixed,
        discountAmount = 0;

  /// Calcola il prezzo unitario scontato
  double getDiscountedUnitPrice(double originalPrice) {
    if (discountAmount <= 0) return originalPrice;

    if (discountType == DiscountType.percentage) {
      final percentage = discountAmount > 100 ? 100 : discountAmount;
      return originalPrice * (1 - percentage / 100);
    } else {
      // Sconto fisso, non può essere maggiore del prezzo
      final maxDiscount = originalPrice;
      final actualDiscount = discountAmount > maxDiscount ? maxDiscount : discountAmount;
      return originalPrice - actualDiscount;
    }
  }
}

class _QuoteDialogState extends ConsumerState<QuoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime? _validUntil;
  bool _isLoading = false;
  DiscountType _discountType = DiscountType.fixed;

  // Servizi selezionati con quantità
  final List<_SelectedService> _selectedServices = [];

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Restituisce i servizi filtrati per la ricerca
  List<ServiceData> _getFilteredServices(List<ServiceData> allServices) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return allServices;
    return allServices
        .where((s) => s.name.toLowerCase().contains(query))
        .toList();
  }

  /// Restituisce i servizi selezionati per primi, poi gli altri
  List<ServiceData> _getOrderedServices(List<ServiceData> allServices) {
    final filtered = _getFilteredServices(allServices);
    final selectedIds = _selectedServices.map((s) => s.serviceId).toSet();

    final selected = filtered.where((s) => selectedIds.contains(s.id)).toList();
    final unselected = filtered
        .where((s) => !selectedIds.contains(s.id))
        .toList();

    // Ordina i selezionati per nome
    selected.sort((a, b) => a.name.compareTo(b.name));
    unselected.sort((a, b) => a.name.compareTo(b.name));

    return [...selected, ...unselected];
  }

  /// Trova la quantità selezionata per un servizio
  int _getQuantity(String serviceId) {
    final selected = _selectedServices.firstWhere(
      (s) => s.serviceId == serviceId,
      orElse: () => _SelectedService(serviceId: '', quantity: 0),
    );
    return selected.serviceId.isEmpty ? 0 : selected.quantity;
  }

  /// Aggiunge o rimuove un servizio dalla selezione
  void _toggleService(String serviceId) {
    setState(() {
      final index = _selectedServices.indexWhere(
        (s) => s.serviceId == serviceId,
      );
      if (index >= 0) {
        _selectedServices.removeAt(index);
      } else {
        _selectedServices.add(
          _SelectedService(serviceId: serviceId, quantity: 1),
        );
      }
    });
  }

  /// Modifica la quantità di un servizio selezionato
  void _updateQuantity(String serviceId, int delta) {
    setState(() {
      final index = _selectedServices.indexWhere(
        (s) => s.serviceId == serviceId,
      );
      if (index >= 0) {
        final newQty = _selectedServices[index].quantity + delta;
        if (newQty <= 0) {
          _selectedServices.removeAt(index);
        } else {
          _selectedServices[index].quantity = newQty;
        }
      }
    });
  }

  /// Modifica lo sconto di un servizio selezionato
  void _updateServiceDiscount(
    String serviceId,
    DiscountType type,
    double amount,
  ) {
    setState(() {
      final index = _selectedServices.indexWhere(
        (s) => s.serviceId == serviceId,
      );
      if (index >= 0) {
        _selectedServices[index].discountType = type;
        _selectedServices[index].discountAmount = amount;
      }
    });
  }

  /// Calcola il totale dei servizi con sconti per riga
  double _calculateSubtotal(List<ServiceData> services) {
    var total = 0.0;
    for (final selected in _selectedServices) {
      final service = services.firstWhereOrNull(
        (s) => s.id == selected.serviceId,
      );
      if (service != null) {
        final discountedPrice = selected.getDiscountedUnitPrice(service.price);
        total += discountedPrice * selected.quantity;
      }
    }
    return total;
  }

  /// Calcola l'importo dello sconto
  double _calculateDiscountAmount(double subtotal) {
    final discountValue = double.tryParse(_discountController.text) ?? 0;
    if (discountValue <= 0) return 0;

    if (_discountType == DiscountType.percentage) {
      // Limita al 100%
      final percentage = discountValue > kMaxDiscountPercentage
          ? kMaxDiscountPercentage
          : discountValue;
      return subtotal * (percentage / 100);
    } else {
      // Fisso, limita al totale
      return discountValue > subtotal ? subtotal : discountValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final services = ref.watch(servicesStreamProvider).value ?? [];

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
            _buildHeader(cs),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(cs, 'SERVIZI'),
                      _buildServiceSearch(cs),
                      const SizedBox(height: 12),
                      _buildServiceSelection(services),
                      const SizedBox(height: 24),
                      _buildSectionTitle(cs, 'SCONTO'),
                      _buildDiscountInput(),
                      const SizedBox(height: 16),
                      _buildSectionTitle(cs, 'VALIDITÀ'),
                      _buildValidityDate(cs),
                      const SizedBox(height: 16),
                      _buildSectionTitle(cs, 'NOTE'),
                      _buildNotesInput(),
                      const SizedBox(height: 24),
                      _buildTotalSummary(cs, services),
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
          const Icon(Symbols.description_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Text(
            'Nuovo Preventivo',
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

  Widget _buildServiceSearch(ColorScheme cs) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Cerca servizi...',
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

  Widget _buildServiceSelection(List<ServiceData> services) {
    final cs = Theme.of(context).colorScheme;
    final orderedServices = _getOrderedServices(services);
    final selectedIds = _selectedServices.map((s) => s.serviceId).toSet();

    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Nessun servizio disponibile',
          style: TextStyle(color: cs.outline),
        ),
      );
    }

    if (orderedServices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Nessun servizio trovato',
          style: TextStyle(color: cs.outline),
        ),
      );
    }

    // Separa selezionati e non selezionati per mostrare un divider
    final selectedServices = orderedServices
        .where((s) => selectedIds.contains(s.id))
        .toList();
    final unselectedServices = orderedServices
        .where((s) => !selectedIds.contains(s.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sezione selezionati (in evidenza)
        if (selectedServices.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SELEZIONATI (${selectedServices.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...selectedServices.map(
            (service) => _buildServiceTile(
              service,
              isSelected: true,
              quantity: _getQuantity(service.id),
            ),
          ),
          if (unselectedServices.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ],
        // Sezione non selezionati
        if (unselectedServices.isNotEmpty) ...[
          if (selectedServices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'DISPONIBILI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.outline,
                ),
              ),
            ),
          ...unselectedServices.map(
            (service) =>
                _buildServiceTile(service, isSelected: false, quantity: 0),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceTile(
    ServiceData service, {
    required bool isSelected,
    required int quantity,
  }) {
    final cs = Theme.of(context).colorScheme;

    // Ottieni info sconto se il servizio è selezionato
    final selectedService = _selectedServices.firstWhere(
      (s) => s.serviceId == service.id,
      orElse: () => _SelectedService(serviceId: ''),
    );
    final hasDiscount = isSelected && selectedService.discountAmount > 0;
    final discountedPrice = isSelected
        ? selectedService.getDiscountedUnitPrice(service.price)
        : service.price;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? cs.primaryContainer.withValues(alpha: 0.2) : null,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleService(service.id),
            ),
            title: Text(
              service.name,
              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDiscount) ...[
                  Text(
                    '€${service.price.toStringAsFixed(2)} → €${discountedPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: cs.outline,
                    ),
                  ),
                  Text(
                    'Sconto: ${selectedService.discountType == DiscountType.percentage ? '${selectedService.discountAmount.toStringAsFixed(0)}%' : '€${selectedService.discountAmount.toStringAsFixed(2)}'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else
                  Text(
                    '€${service.price.toStringAsFixed(2)} • ${service.durationMinutes} min',
                  ),
              ],
            ),
            trailing: isSelected
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Symbols.local_offer_rounded),
                        onPressed: () => _showServiceDiscountDialog(service, selectedService),
                        style: IconButton.styleFrom(
                          backgroundColor: hasDiscount
                              ? Colors.green.withValues(alpha: 0.2)
                              : cs.surfaceContainerHighest,
                          foregroundColor: hasDiscount ? Colors.green.shade700 : null,
                        ),
                        tooltip: 'Sconto',
                      ),
                      IconButton(
                        icon: const Icon(Symbols.remove_rounded),
                        onPressed: quantity > 1
                            ? () => _updateQuantity(service.id, -1)
                            : () => _toggleService(service.id),
                        style: IconButton.styleFrom(
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.add_rounded),
                        onPressed: () => _updateQuantity(service.id, 1),
                        style: IconButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                        ),
                      ),
                    ],
                  )
                : null,
            onTap: () => _toggleService(service.id),
          ),
        ],
      ),
    );
  }

  void _showServiceDiscountDialog(ServiceData service, _SelectedService selected) {
    final cs = Theme.of(context).colorScheme;
    final discountController = TextEditingController(
      text: selected.discountAmount > 0 ? selected.discountAmount.toString() : '',
    );
    DiscountType tempType = selected.discountType;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Sconto per ${service.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Prezzo base: €${service.price.toStringAsFixed(2)}',
                style: TextStyle(color: cs.outline),
              ),
              const SizedBox(height: 16),
              SegmentedButton<DiscountType>(
                segments: [
                  ButtonSegment(
                    value: DiscountType.fixed,
                    label: const Text('€ Fisso'),
                    icon: const Icon(Symbols.euro_rounded),
                  ),
                  ButtonSegment(
                    value: DiscountType.percentage,
                    label: const Text('% Perc.'),
                    icon: const Icon(Symbols.percent_rounded),
                  ),
                ],
                selected: {tempType},
                onSelectionChanged: (set) {
                  setDialogState(() => tempType = set.first);
                  discountController.clear();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tempType == DiscountType.fixed
                      ? 'Sconto in euro'
                      : 'Sconto in %',
                  suffixText: tempType == DiscountType.fixed ? '€' : '%',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              if (discountController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final amount = double.tryParse(discountController.text) ?? 0;
                  final discounted = tempType == DiscountType.percentage
                      ? service.price * (1 - (amount > 100 ? 100 : amount) / 100)
                      : service.price - (amount > service.price ? service.price : amount);
                  return Text(
                    'Prezzo finale: €${discounted.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                _updateServiceDiscount(service.id, DiscountType.fixed, 0);
                Navigator.pop(context);
              },
              child: Text(
                'Rimuovi',
                style: TextStyle(color: cs.error),
              ),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(discountController.text) ?? 0;
                if (amount >= 0) {
                  _updateServiceDiscount(service.id, tempType, amount);
                }
                Navigator.pop(context);
              },
              child: const Text('Applica'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountInput() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle tipo sconto
        Row(
          children: [
            Expanded(
              child: SegmentedButton<DiscountType>(
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
                    // Resetta il valore quando cambia tipo
                    _discountController.clear();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Input sconto
        TextFormField(
          controller: _discountController,
          onChanged: (_) => setState(() {}),
          // Aggiorna totale in tempo reale
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
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final discount = double.tryParse(v);
            if (discount == null || discount < 0) {
              return 'Sconto non valido';
            }
            if (_discountType == DiscountType.percentage &&
                discount > kMaxDiscountPercentage) {
              return 'Max 100%';
            }
            return null;
          },
        ),
        // Anteprima sconto calcolato
        if (_discountController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _buildDiscountPreview(),
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _buildDiscountPreview() {
    final services = ref.read(servicesStreamProvider).value ?? [];
    final subtotal = _calculateSubtotal(services);
    final discountAmount = _calculateDiscountAmount(subtotal);

    if (discountAmount <= 0) return '';

    if (_discountType == DiscountType.percentage) {
      return 'Sconto applicato: -€${discountAmount.toStringAsFixed(2)}';
    }
    return '';
  }

  Widget _buildValidityDate(ColorScheme cs) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              _validUntil ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() => _validUntil = date);
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
            Text(
              _validUntil == null
                  ? 'Seleziona data di validità'
                  : 'Valido fino al: ${_validUntil!.day}/${_validUntil!.month}/${_validUntil!.year}',
              style: TextStyle(
                color: _validUntil == null ? cs.outline : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesInput() {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Note (opzionale)',
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

  Widget _buildTotalSummary(ColorScheme cs, List<ServiceData> services) {
    final subtotal = _calculateSubtotal(services);
    final discountAmount = _calculateDiscountAmount(subtotal);
    final finalTotal = subtotal - discountAmount;

    // Calcola numero totale servizi
    final totalQuantity = _selectedServices.fold(
      0,
      (sum, s) => sum + s.quantity,
    );

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
              Text('Totale servizi ($totalQuantity articoli):'),
              Text('€${subtotal.toStringAsFixed(2)}'),
            ],
          ),
          if (discountAmount > 0) ...[
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
                  '-€${discountAmount.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Totale finale:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              Text(
                '€${finalTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                  fontSize: 18,
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
              onPressed: (_isLoading || offlineReadOnly) ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crea Preventivo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedServices.isEmpty) {
      _showError('Seleziona almeno un servizio');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final services = ref.read(servicesStreamProvider).value ?? [];

      // Crea i quote items con le quantità selezionate e sconti per riga
      final quoteItems = _selectedServices.map((selected) {
        final service = services.firstWhere((s) => s.id == selected.serviceId);
        final unitPrice = service.price;
        final sessions = selected.quantity;
        final discountedUnitPrice = selected.getDiscountedUnitPrice(unitPrice);
        return QuoteItemData(
          id: '',
          // Will be generated by repository
          quoteId: '',
          // Will be set by repository
          serviceId: service.id,
          lockedServiceName: service.name,
          lockedUnitPrice: unitPrice,
          sessions: sessions,
          discountType: selected.discountType.name,
          discountAmount: selected.discountAmount,
          discountedUnitPrice: discountedUnitPrice,
          lineTotal: discountedUnitPrice * sessions,
        );
      }).toList();

      // Calcola il totale
      final subtotal = quoteItems.fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      );

      // Calcola lo sconto
      final discountAmount = _calculateDiscountAmount(subtotal);

      final now = DateTime.now();
      // Genera numero preventivo human readable: PREV-XXX-YYYY (progressivo-anno)
      final year = now.year;
      final randomSequential = (now.millisecondsSinceEpoch % 900) + 100; // 100-999
      await ref
          .read(quotesActionsProvider)
          .createQuote(
            clientId: widget.clientId,
            quoteNumber:
                'PREV-${randomSequential.toString().padLeft(3, '0')}-$year',
            totalPrice: subtotal,
            discountAmount: discountAmount,
            validUntil: _validUntil,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: quoteItems,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preventivo creato con successo')),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cs.error));
  }
}
