import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/contacts/contact_sync_helper.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localizations/utils_regions/italy_phone_formatter.dart';
import '../../../../core/logging/app_logger.dart';
import '../providers/clients_providers.dart';

class OsmAddress {
  OsmAddress({
    required this.osmId,
    required this.lat,
    required this.lon,
    required this.road,
    required this.houseNumber,
    required this.city,
    required this.postcode,
    required this.fullDisplayName,
  });

  factory OsmAddress.fromJson(final Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};

    final cityVal =
        address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'] ??
        '';

    final roadVal =
        address['road'] ??
        address['pedestrian'] ??
        address['street'] ??
        address['square'] ??
        '';

    return OsmAddress(
      osmId: (json['osm_id'] as int?) ?? 0,
      lat: (json['lat'] as String?) ?? '',
      lon: (json['lon'] as String?) ?? '',
      fullDisplayName: (json['display_name'] as String?) ?? '',
      road: roadVal as String,
      houseNumber: (address['house_number'] as String?) ?? '',
      city: cityVal as String,
      postcode: (address['postcode'] as String?) ?? '',
    );
  }

  final int osmId;
  final String lat;
  final String lon;
  final String road;
  final String houseNumber;
  final String city;
  final String postcode;
  final String fullDisplayName;

  String get formattedAddress {
    final buffer = StringBuffer();

    if (road.isNotEmpty) {
      buffer.write(road);
    }

    if (houseNumber.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(houseNumber);
    }

    if (city.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(city);
    }

    if (postcode.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(' $postcode');
    }

    if (buffer.isEmpty) {
      return fullDisplayName;
    }

    return buffer.toString();
  }
}

class OsmService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'User-Agent': 'BeautyCenterApp/1.0'},
    ),
  );

  static CancelToken? _cancelToken;

  static Future<List<OsmAddress>> searchAddress(final String query) async {
    if (query.trim().length < 3) return [];

    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('New query started');
    }
    _cancelToken = CancelToken();

    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': 1,
          'limit': 10,
          'countrycodes': 'it,ch',
          'layer': 'address',
          'dedupe': 1,
        },
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data!
            .map((final e) {
              if (e is Map<String, dynamic>) {
                return OsmAddress.fromJson(e);
              }
              return null;
            })
            .whereType<OsmAddress>()
            .toList();

        final seenAddresses = <String>{};
        final uniqueResults = <OsmAddress>[];

        for (final item in results) {
          if (item.road.isEmpty && item.city.isEmpty) continue;

          final key = item.formattedAddress;
          if (!seenAddresses.contains(key)) {
            seenAddresses.add(key);
            uniqueResults.add(item);
          }
        }

        return uniqueResults.take(5).toList();
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return [];
      debugPrint('Error OSM: $e');
    }
    return [];
  }
}

enum Mode { add, edit }

class AddEditClientDialog extends ConsumerStatefulWidget {
  const AddEditClientDialog({this.client, this.mode = Mode.add, super.key});

  final Client? client;

  final Mode mode;

  @override
  ConsumerState<AddEditClientDialog> createState() =>
      _AddEditClientDialogState();
}

class _AddEditClientDialogState extends ConsumerState<AddEditClientDialog> {
  static final log = AppLogger.getLogger(name: 'AddEditClientDialog');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  DateTime? _birthDate;

  static const _emailDomains = <String>[
    'gmail.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'yahoo.com',
    'libero.it',
    'virgilio.it',
    'alice.it',
  ];

  var _isLoading = false;

  bool get _isEditMode => widget.client != null && widget.mode == Mode.edit;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.client?.firstName,
    );
    _lastNameController = TextEditingController(text: widget.client?.lastName);

    _birthDate = widget.client?.birthDate;

    _birthDateController = TextEditingController(
      text: _birthDate != null
          ? DateFormat('dd/MM/yyyy').format(_birthDate!)
          : '',
    );

    final original = widget.client?.phoneNumber.replaceAll(' ', '') ?? '';
    final formatted = original.startsWith('+39') && !original.startsWith('+39 ')
        ? '+39 ${original.substring(3)}'
        : original;
    _phoneController = TextEditingController(text: formatted);
    _emailController = TextEditingController(text: widget.client?.email);
    _addressController = TextEditingController(text: widget.client?.address);
    _notesController = TextEditingController(text: widget.client?.notes);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final initialDate =
        _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trimmedFirstName = _firstNameController.text.trim();
      final trimmedLastName = _lastNameController.text.trim();
      final normalizedPhone = _phoneController.text.trim().replaceAll(' ', '');
      final trimmedEmail = _emailController.text.trim();
      final trimmedAddress = _addressController.text.trim();
      final trimmedNotes = _notesController.text.trim();

      // Save to database
      if (_isEditMode) {
        await ref
            .read(clientsActionsProvider)
            .updateClient(
              id: widget.client!.id,
              firstName: trimmedFirstName,
              lastName: trimmedLastName,
              phoneNumber: normalizedPhone,
              email: trimmedEmail.isEmpty ? null : trimmedEmail,
              birthDate: _birthDate,
              address: trimmedAddress.isEmpty ? null : trimmedAddress,
              notes: trimmedNotes.isEmpty ? null : trimmedNotes,
            );
      } else {
        await ref
            .read(clientsActionsProvider)
            .createClient(
              firstName: trimmedFirstName,
              lastName: trimmedLastName,
              phoneNumber: normalizedPhone,
              email: trimmedEmail.isEmpty ? null : trimmedEmail,
              birthDate: _birthDate,
              address: trimmedAddress.isEmpty ? null : trimmedAddress,
              notes: trimmedNotes.isEmpty ? null : trimmedNotes,
            );
      }

      if (!mounted) return;

      // Sync to device contacts (non-blocking)
      if (!kIsWindows) {
        await ContactSyncHelper.syncPersonToContact(
          context: context,
          firstName: trimmedFirstName,
          lastName: trimmedLastName,
          phoneNumber: normalizedPhone,
          email: trimmedEmail.isEmpty ? null : trimmedEmail,
        ).catchError(
          (final Object e) =>
              log.warning('Contact sync failed but client saved', e),
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
      showCustomSnackBar(
        context: context,
        message: _isEditMode
            ? 'Cliente modificato con successo'
            : 'Cliente aggiunto con successo',
        okColor: AppTabs.clients.color,
      );
    } catch (e, stackTrace) {
      log.severe('Error saving client', e, stackTrace);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Errore durante il salvataggio',
          okColor: AppTabs.clients.color,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: kIsWindows ? 600 : double.infinity,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                        : Symbols.person_add_rounded,
                    size: kIsWindows ? 28 : 28.sp,
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'Modifica cliente' : 'Nuovo cliente',
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
                      // Personal data
                      Text(
                        'Dati anagrafici',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: kIsWindows ? 20 : 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: kIsWindows ? 12 : 12.h),

                      // First name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome *',
                          prefixIcon: Icon(Symbols.person_outline_rounded),
                        ),
                        maxLength: 100,
                        minLines: 1,
                        maxLines: null,
                        textCapitalization: TextCapitalization.words,
                        validator: (final value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il nome';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),

                      SizedBox(height: kIsWindows ? 16 : 16.h),

                      // Last name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Cognome *',
                          prefixIcon: Icon(Symbols.person_outline_rounded),
                        ),
                        maxLength: 100,
                        minLines: 1,
                        maxLines: null,
                        textCapitalization: TextCapitalization.words,
                        validator: (final value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il cognome';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),

                      SizedBox(height: kIsWindows ? 16 : 16.h),

                      // Birthday date
                      TextFormField(
                        controller: _birthDateController,
                        readOnly: true,
                        onTap: _isLoading ? null : _selectBirthDate,
                        decoration: const InputDecoration(
                          labelText: 'Data di nascita *',
                          prefixIcon: Icon(Symbols.cake_rounded),
                          suffixIcon: Icon(Symbols.calendar_month_rounded),
                          hintText: 'Seleziona data',
                        ),
                        minLines: 1,
                        maxLines: null,
                        validator: (final value) {
                          if (value == null || value.isEmpty) {
                            return 'Inserisci la data di nascita';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),

                      SizedBox(height: kIsWindows ? 24 : 24.h),

                      // Contacts
                      Text(
                        'Contatti',
                        style: TextStyle(
                          fontSize: kIsWindows ? 20 : 20.sp,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),

                      SizedBox(height: kIsWindows ? 12 : 12.h),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefono *',
                          prefixIcon: Icon(Symbols.phone_rounded),
                          hintText: '+39 3331234567',
                        ),
                        maxLength: 20,
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [ItalyPhoneFormatter()],
                        validator: (final value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il numero di telefono';
                          }

                          final regex = RegExp(r'^\+39 [0-9]{10}$');
                          if (!regex.hasMatch(value.trim())) {
                            return 'Formato non valido: usa +39 e 10 cifre';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),

                      SizedBox(height: kIsWindows ? 16 : 16.h),

                      // --- EMAIL AUTOCOMPLETE ---
                      TypeAheadField<String>(
                        controller: _emailController,
                        suggestionsCallback: (final pattern) {
                          if (pattern.isEmpty) return [];

                          var username = pattern;
                          var domainPart = '';

                          if (pattern.contains('@')) {
                            final split = pattern.split('@');
                            username = split[0];
                            if (split.length > 1) domainPart = split[1];
                          }

                          if (_emailDomains.contains(domainPart)) return [];

                          final matches = _emailDomains.where(
                            (final d) => d.startsWith(domainPart),
                          );

                          return matches
                              .map((final d) => '$username@$d')
                              .toList();
                        },
                        hideOnEmpty: true,
                        hideOnError: true,
                        animationDuration: kDefaultAppAnimationsDuration,
                        builder:
                            (
                              final context,
                              final controller,
                              final focusNode,
                            ) => TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Symbols.email_rounded),
                              ),
                              minLines: 1,
                              maxLength: 200,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isLoading,
                              validator: (final value) {
                                if (value != null && value.isNotEmpty) {
                                  final emailRegex = RegExp(
                                    r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  );
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Email non valida';
                                  }
                                }
                                return null;
                              },
                            ),
                        itemBuilder: (final context, final suggestion) =>
                            ListTile(
                              leading: Icon(
                                Symbols.alternate_email_rounded,
                                color: colorScheme.primary,
                                size: kIsWindows ? 20 : 20.sp,
                              ),
                              title: Text(suggestion),
                              dense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: kIsWindows ? 16 : 16.w,
                              ),
                            ),
                        onSelected: (final suggestion) {
                          _emailController.text = suggestion;
                        },
                        decorationBuilder: (final context, final child) =>
                            Material(
                              type: MaterialType.card,
                              elevation: 6,
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                kIsWindows ? 12 : 12.r,
                              ),
                              child: child,
                            ),
                        offset: const Offset(0, 4),
                      ),

                      SizedBox(height: kIsWindows ? 16 : 16.h),

                      // --- ADDRESS AUTOCOMPLETE (OPENSTREETMAP) ---
                      TypeAheadField<OsmAddress>(
                        controller: _addressController,
                        suggestionsCallback: OsmService.searchAddress,
                        debounceDuration: const Duration(milliseconds: 500),
                        hideOnEmpty: true,
                        hideOnError: true,
                        animationDuration: kDefaultAppAnimationsDuration,
                        builder:
                            (
                              final context,
                              final controller,
                              final focusNode,
                            ) => TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Indirizzo',
                                prefixIcon: Icon(Symbols.location_on_rounded),
                                suffixIcon: Icon(Symbols.expand_more_rounded),
                              ),
                              textCapitalization: TextCapitalization.words,
                              enabled: !_isLoading,
                              minLines: 1,
                              maxLines: null,
                            ),
                        itemBuilder: (final context, final address) => ListTile(
                          leading: Icon(
                            Symbols.map_rounded,
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            address.formattedAddress,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: kIsWindows ? 16 : 16.w,
                            vertical: kIsWindows ? 4 : 4.h,
                          ),
                          dense: false,
                        ),
                        onSelected: (final address) {
                          _addressController.text = address.formattedAddress;
                        },
                        decorationBuilder: (final context, final child) =>
                            Material(
                              type: MaterialType.card,
                              elevation: 6,
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                kIsWindows ? 12 : 12.r,
                              ),
                              child: child,
                            ),
                        offset: const Offset(0, 4),
                      ),

                      SizedBox(height: kIsWindows ? 24 : 24.h),

                      // Notes
                      Text(
                        'Note aggiuntive',
                        style: TextStyle(
                          fontSize: kIsWindows ? 20 : 20.sp,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),

                      SizedBox(height: kIsWindows ? 12 : 12.h),

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          prefixIcon: Icon(Symbols.note_rounded),
                          alignLabelWithHint: true,
                          hintText: 'Informazioni aggiuntive sul cliente...',
                        ),
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
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
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveClient,
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
