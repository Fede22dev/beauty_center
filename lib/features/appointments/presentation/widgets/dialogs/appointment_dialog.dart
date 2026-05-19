import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/providers/offline_status_provider.dart';
import '../../../../clients/providers/clients_providers.dart';
import '../../../../fidelity/providers/fidelity_providers.dart';
import '../../../../packages/providers/packages_providers.dart';
import '../../../../payments/providers/payments_providers.dart';
import '../../../../settings/providers/settings_providers.dart';
import '../../../../treatments/providers/treatments_providers.dart';
import '../../../providers/appointments_providers.dart';
import '../common/appointments_date_picker_dialog.dart';

class AppointmentDialog extends ConsumerStatefulWidget {
  const AppointmentDialog({
    required this.initialOperatorId,
    required this.initialStartTime,
    required this.initialEndTime,
    super.key,
    this.appointment,
  });

  final int initialOperatorId;
  final DateTime initialStartTime;
  final DateTime initialEndTime;
  final AppointmentData? appointment;

  @override
  ConsumerState<AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends ConsumerState<AppointmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _notesCtrl;
  late int _operatorId;
  int? _cabinId;
  Client? _selectedClient;
  late DateTime _startTime;
  late DateTime _endTime;
  bool _isLoading = false;

  // Multi-service selection with payment source (key = serviceId for uniqueness)
  // NOTE: Duplicate services in same appointment use the same serviceId key
  // and share payment source. To allow different payment per duplicate,
  // the model would need per-instance IDs. Current UI supports one entry per service.
  final Map<String, _ServicePaymentInfo> _selectedServices = {};

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _operatorId = a?.operatorId ?? widget.initialOperatorId;
    _cabinId = a?.cabinId;
    _startTime = a?.startDateTime ?? widget.initialStartTime;
    _endTime = a?.endDateTime ?? _startTime.add(const Duration(minutes: 60));
    _notesCtrl = TextEditingController(text: a?.notes ?? '');

    // Load existing appointment services when editing
    if (a != null) {
      _loadExistingServices();
    }
  }

  Future<void> _loadExistingServices() async {
    final services = await ref.read(appointmentActionsProvider)
        .getAppointmentServicesByAppointmentId(widget.appointment!.id);
    if (!mounted) return;
    for (final service in services) {
      _selectedServices[service.serviceId] = _ServicePaymentInfo(
        serviceId: service.serviceId,
        paymentSource: service.paymentSource,
        packageItemId: service.packageItemId,
        fidelityCardId: service.fidelityCardId,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _selectedClient == null ||
        _cabinId == null ||
        _selectedServices.isEmpty) {
      _showError('Per favore, compila tutti i campi obbligatori');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final actions = ref.read(appointmentActionsProvider);
      final services = ref.read(servicesStreamProvider).value ?? [];

      if (widget.appointment != null) {
        // Transactional update: replaces all services atomically
        final serviceInputs = _selectedServices.entries.map((entry) {
          final service = services.firstWhereOrNull((s) => s.id == entry.key);
          if (service == null) return null;
          return (
            serviceId: entry.key,
            lockedPrice: service.price,
            lockedDuration: service.durationMinutes,
            paymentSource: entry.value.paymentSource,
            packageItemId: entry.value.packageItemId,
            fidelityCardId: entry.value.fidelityCardId,
          );
        }).whereType<({String serviceId, double lockedPrice, int lockedDuration, String paymentSource, String? packageItemId, String? fidelityCardId})>().toList();

        final success = await actions.updateAppointmentWithServices(
          id: widget.appointment!.id,
          operatorId: _operatorId,
          clientId: _selectedClient!.id,
          cabinId: _cabinId!,
          startDateTime: _startTime,
          endDateTime: _endTime,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          services: serviceInputs,
        );

        if (!success) {
          throw StateError('Cannot update appointment: offline mode (read-only)');
        }
      } else {
        // Create appointment
        final appointmentId = await actions.createAppointment(
          operatorId: _operatorId,
          clientId: _selectedClient!.id,
          cabinId: _cabinId!,
          service: _selectedServices.keys.first, // Placeholder for backward compatibility
          startDateTime: _startTime,
          endDateTime: _endTime,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

        if (appointmentId == null) {
          throw StateError('Cannot create appointment: offline mode (read-only)');
        }

        // Create appointment services for each selected service
        for (final entry in _selectedServices.entries) {
          final service = services.firstWhereOrNull((s) => s.id == entry.key);
          if (service == null) continue;
          await actions.createAppointmentService(
            appointmentId: appointmentId,
            serviceId: entry.key,
            lockedPrice: service.price,
            lockedDuration: service.durationMinutes,
            packageItemId: entry.value.packageItemId,
            fidelityCardId: entry.value.fidelityCardId,
            paymentSource: entry.value.paymentSource,
          );

          // Handle payment based on source
          if (entry.value.paymentSource == 'package' && entry.value.packageItemId != null) {
            // Consume package session
            final packagesActions = ref.read(packagesActionsProvider);
            await packagesActions.incrementUsedSessions(entry.value.packageItemId!);
          } else if (entry.value.paymentSource == 'fidelity' && entry.value.fidelityCardId != null) {
            // Consume fidelity balance
            final fidelityActions = ref.read(fidelityActionsProvider);
            await fidelityActions.addUsage(
              cardId: entry.value.fidelityCardId!,
              amount: service.price,
              appointmentId: appointmentId,
              description: 'Utilizzo per servizio: ${service.name}',
            );
          } else if (entry.value.paymentSource == 'direct') {
            // CRITICAL: Create payment record for direct payments (cash/card)
            // This was missing and caused financial tracking holes!
            final paymentsActions = ref.read(paymentsActionsProvider);
            await paymentsActions.createPayment(
              clientId: _selectedClient!.id,
              amount: service.price,
              paymentMethod: 'cash', // Default to cash for direct payments
              appointmentId: appointmentId,
              notes: 'Pagamento per servizio: ${service.name}',
            );
          }
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Errore durante il salvataggio: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final cabins = ref.watch(activeCabinsStreamProvider).value ?? [];
    final clients = ref.watch(clientsStreamProvider).value ?? [];

    if (widget.appointment != null && _selectedClient == null) {
      _selectedClient = clients
          .where((c) => c.id == widget.appointment!.clientId)
          .firstOrNull;
    }

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
            // Header
            _buildHeader(cs),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(cs, 'CLIENTE'),
                      _buildClientSearch(clients),
                      const SizedBox(height: 24),

                      _buildSectionTitle(cs, 'DETTAGLI SERVIZIO'),
                      _buildServiceInput(),
                      const SizedBox(height: 16),
                      _buildOperatorAndCabinRow(operators, cabins),
                      const SizedBox(height: 24),

                      _buildSectionTitle(cs, 'DATA E ORARIO'),
                      _buildDateTimeSelectors(cs),
                      const SizedBox(height: 24),

                      _buildSectionTitle(cs, 'STATO APPUNTAMENTO'),
                      const SizedBox(height: 24),

                      _buildSectionTitle(cs, 'NOTE'),
                      _buildNotesInput(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
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
          Icon(
            widget.appointment != null
                ? Symbols.edit_rounded
                : Symbols.add_task_rounded,
            color: cs.primary,
          ),
          const SizedBox(width: 12),
          Text(
            widget.appointment != null
                ? 'Modifica Appuntamento'
                : 'Nuovo Appuntamento',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          if (widget.appointment != null)
            IconButton(
              tooltip: 'Copia',
              icon: const Icon(Symbols.content_copy_rounded),
              onPressed: () {
                ref
                    .read(appointmentActionsProvider)
                    .copyToClipboard(widget.appointment!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiato negli appunti')),
                );
                Navigator.pop(context);
              },
            ),
          if (widget.appointment != null)
            IconButton(
              tooltip: 'Taglia',
              icon: const Icon(Symbols.content_cut_rounded),
              onPressed: () {
                ref
                    .read(appointmentActionsProvider)
                    .cutToClipboard(widget.appointment!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tagliato negli appunti')),
                );
                Navigator.pop(context);
              },
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

  Widget _buildClientSearch(List<Client> clients) {
    return Autocomplete<Client>(
      initialValue: TextEditingValue(
        text: _selectedClient != null
            ? '${_selectedClient!.firstName} ${_selectedClient!.lastName}'
            : '',
      ),
      optionsBuilder: (text) => clients.where(
        (c) =>
            '${c.firstName} ${c.lastName}'.toLowerCase().contains(
              text.text.toLowerCase(),
            ) ||
            c.phoneNumber.contains(text.text),
      ),
      displayStringForOption: (c) => '${c.firstName} ${c.lastName}',
      onSelected: (c) => setState(() => _selectedClient = c),
      fieldViewBuilder: (context, controller, focus, onFieldSubmitted) =>
          TextFormField(
            controller: controller,
            focusNode: focus,
            decoration: InputDecoration(
              hintText: 'Cerca cliente per nome o telefono...',
              prefixIcon: const Icon(Symbols.search_rounded),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) =>
                _selectedClient == null ? 'Selezione obbligatoria' : null,
          ),
    );
  }

  Widget _buildServiceInput() {
    final cs = Theme.of(context).colorScheme;
    final services = ref.watch(servicesStreamProvider).value ?? [];
    final packagesAsync = _selectedClient != null
        ? ref.watch(activePackagesByClientStreamProvider(_selectedClient!.id))
        : null;
    final packages = packagesAsync?.value ?? [];
    final fidelityCardsAsync = _selectedClient != null
        ? ref.watch(activeFidelityCardsByClientStreamProvider(_selectedClient!.id))
        : null;
    final fidelityCards = fidelityCardsAsync?.value ?? [];

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

    return Column(
      children: services.map((service) {
        final isSelected = _selectedServices.containsKey(service.id);
        final paymentInfo = _selectedServices[service.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedServices[service.id] = _ServicePaymentInfo(
                        serviceId: service.id,
                        paymentSource: 'direct',
                      );
                    } else {
                      _selectedServices.remove(service.id);
                    }
                  });
                },
                title: Text(service.name),
                subtitle: Text('€${service.price.toStringAsFixed(2)} - ${service.durationMinutes} min'),
              ),
              if (isSelected) _buildPaymentSourceSelector(cs, service.id, paymentInfo!, packages, fidelityCards),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentSourceSelector(
    ColorScheme cs,
    String serviceId,
    _ServicePaymentInfo paymentInfo,
    List<PackageData> packages,
    List<FidelityCardData> fidelityCards,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metodo di pagamento:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'direct',
                label: Text('Diretto'),
                icon: Icon(Symbols.payments_rounded, size: 18),
              ),
              ButtonSegment(
                value: 'package',
                label: Text('Pacchetto'),
                icon: Icon(Symbols.inventory_2_rounded, size: 18),
              ),
              ButtonSegment(
                value: 'fidelity',
                label: Text('Fidelity'),
                icon: Icon(Symbols.style_rounded, size: 18),
              ),
            ],
            selected: {paymentInfo.paymentSource},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _selectedServices[serviceId] = _ServicePaymentInfo(
                  serviceId: serviceId,
                  paymentSource: selection.first,
                  packageItemId: null,
                  fidelityCardId: null,
                );
              });
            },
          ),
          const SizedBox(height: 8),
          if (paymentInfo.paymentSource == 'package') _buildPackageSelector(cs, serviceId, packages),
          if (paymentInfo.paymentSource == 'fidelity') _buildFidelitySelector(cs, serviceId, fidelityCards),
        ],
      ),
    );
  }

  Widget _buildPackageSelector(ColorScheme cs, String serviceId, List<PackageData> packages) {
    if (packages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Nessun pacchetto attivo disponibile',
          style: TextStyle(color: cs.onErrorContainer),
        ),
      );
    }

    return FutureBuilder<List<PackageItemData>>(
      future: _loadPackageItems(packages),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final packageItems = snapshot.data ?? [];

        return DropdownButtonFormField<String>(
          value: _selectedServices[serviceId]?.packageItemId,
          decoration: InputDecoration(
            labelText: 'Seleziona pacchetto',
            prefixIcon: const Icon(Symbols.inventory_2_rounded),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: packages.expand<DropdownMenuItem<String>>((pkg) {
            final items = packageItems.where((item) => item.packageId == pkg.id);
            return items.map<DropdownMenuItem<String>>((item) {
              return DropdownMenuItem<String>(
                value: item.id,
                child: Text('${pkg.name} - ${item.lockedServiceName} (${item.usedSessions}/${item.totalSessions})'),
              );
            });
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedServices[serviceId] = _ServicePaymentInfo(
                serviceId: serviceId,
                paymentSource: 'package',
                packageItemId: value,
              );
            });
          },
        );
      },
    );
  }

  Future<List<PackageItemData>> _loadPackageItems(List<PackageData> packages) async {
    final actions = ref.read(packagesActionsProvider);
    final allItems = <PackageItemData>[];
    for (final pkg in packages) {
      final items = await actions.getPackageItemsByPackageId(pkg.id);
      allItems.addAll(items);
    }
    return allItems;
  }

  Widget _buildFidelitySelector(ColorScheme cs, String serviceId, List<FidelityCardData> fidelityCards) {
    if (fidelityCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Nessuna carta fidelity attiva disponibile',
          style: TextStyle(color: cs.onErrorContainer),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedServices[serviceId]?.fidelityCardId,
      decoration: InputDecoration(
        labelText: 'Seleziona carta fidelity',
        prefixIcon: const Icon(Symbols.style_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: fidelityCards.map<DropdownMenuItem<String>>((card) {
        return DropdownMenuItem<String>(
          value: card.id,
          child: Text('Carta #${card.cardNumber} - Saldo: €${card.balance.toStringAsFixed(2)}'),
        );
      }).toList(),
      onChanged: (String? value) {
        setState(() {
          _selectedServices[serviceId] = _ServicePaymentInfo(
            serviceId: serviceId,
            paymentSource: 'fidelity',
            fidelityCardId: value,
          );
        });
      },
    );
  }

  Widget _buildOperatorAndCabinRow(
    List<Operator> operators,
    List<Cabin> cabins,
  ) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _operatorId,
            decoration: InputDecoration(
              labelText: 'Operatore',
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
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _cabinId,
            decoration: InputDecoration(
              labelText: 'Cabina',
              prefixIcon: const Icon(Symbols.door_front_rounded),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: cabins
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(c.color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Cabina ${c.id}'),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _cabinId = v),
            validator: (v) => v == null ? 'Obbligatorio' : null,
          ),
        ),
      ],
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
              color: cs.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.calendar_today_rounded,
                  size: 20,
                  color: cs.primary,
                ),
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
              child: _TimeButton(
                label: 'Inizio',
                time: TimeOfDay.fromDateTime(_startTime),
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeButton(
                label: 'Fine',
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
        var newTime = DateTime(
          base.year,
          base.month,
          base.day,
          picked.hour,
          picked.minute,
        );

        final workHours = ref.read(workHoursStreamProvider).value;
        if (workHours != null) {
          if (newTime.hour < workHours.startHr) {
            newTime = DateTime(
              newTime.year,
              newTime.month,
              newTime.day,
              workHours.startHr,
              0,
            );
          }
          if (newTime.hour > workHours.endHr ||
              (newTime.hour == workHours.endHr && newTime.minute > 0)) {
            newTime = DateTime(
              newTime.year,
              newTime.month,
              newTime.day,
              workHours.endHr,
              0,
            );
          }
        }

        if (isStart) {
          _startTime = newTime;
          if (_endTime.isBefore(_startTime))
            _endTime = _startTime.add(const Duration(minutes: 60));
        } else {
          if (newTime.isBefore(_startTime)) {
            _showError('Fine prima dell\'inizio');
            return;
          }
          _endTime = newTime;
        }
      });
    }
  }

  Widget _buildNotesInput() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: 'Note o richieste particolari...',
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

  Widget _buildFooter(ColorScheme cs) {
    final offlineReadOnly = ref.watch(isOfflineReadOnlyProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.appointment != null)
            IconButton(
              icon: Icon(
                Symbols.delete_rounded,
                color: offlineReadOnly ? cs.outline : cs.error,
              ),
              onPressed: offlineReadOnly
                  ? null
                  : () async {
                      final confirmed = await _showDeleteConfirm();
                      if (confirmed) {
                        await ref
                            .read(appointmentActionsProvider)
                            .deleteAppointment(widget.appointment!.id);
                        if (mounted) Navigator.pop(context);
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                : Text(widget.appointment != null ? 'SALVA' : 'CREA'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Conferma eliminazione'),
            content: const Text(
              'Sei sicuro di voler eliminare questo appuntamento?',
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
        ) ??
        false;
  }
}

class _ServicePaymentInfo {
  _ServicePaymentInfo({
    required this.serviceId,
    required this.paymentSource,
    this.packageItemId,
    this.fidelityCardId,
  });

  final String serviceId;
  final String paymentSource; // 'direct', 'package', 'fidelity'
  final String? packageItemId;
  final String? fidelityCardId;
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
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
