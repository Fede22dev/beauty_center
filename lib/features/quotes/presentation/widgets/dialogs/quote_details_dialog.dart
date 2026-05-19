import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/tabs/app_tabs.dart';
import '../../../../../core/widgets/custom_snackbar.dart';
import '../../../../clients/providers/clients_providers.dart';
import '../../../providers/quotes_providers.dart';
import '../../../utils/pdf_generator.dart';

/// Dialog per visualizzare i dettagli di un preventivo
class QuoteDetailsDialog extends ConsumerWidget {
  const QuoteDetailsDialog({required this.quoteId, super.key});

  final String quoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(quoteStreamProvider(quoteId));
    final itemsAsync = ref.watch(quoteItemsStreamProvider(quoteId));
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context, colorScheme),
            // Content
            Flexible(
              child: quoteAsync.when(
                data: (quote) {
                  if (quote == null) {
                    return const Center(child: Text('Preventivo non trovato'));
                  }
                  return itemsAsync.when(
                    data: (items) =>
                        _buildContent(context, colorScheme, quote, items, ref),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Errore: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Errore: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Icon(Symbols.description_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            'Dettaglio Preventivo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
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

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    QuoteData quote,
    List<QuoteItemData> items,
    WidgetRef ref,
  ) {
    final canDelete =
        quote.status == 'draft' ||
        quote.status == 'sent' ||
        quote.status == 'rejected';
    final canGeneratePdf =
        quote.status != 'rejected'; // Non generare PDF per rifiutati

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info principali
          _buildInfoCard(context, colorScheme, quote),
          const SizedBox(height: 16),
          // Lista servizi
          _buildItemsCard(context, colorScheme, items),
          const SizedBox(height: 16),
          // Totale
          _buildTotalCard(context, colorScheme, quote),
          if (quote.notes != null && quote.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(context, colorScheme, quote.notes!),
          ],
          const SizedBox(height: 24),
          // Azioni
          Row(
            children: [
              if (canDelete)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showDeleteConfirmation(context, ref, quote),
                    icon: const Icon(Symbols.delete_rounded),
                    label: const Text('Elimina'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ),
              if (canDelete) const SizedBox(width: 12),
              if (canGeneratePdf)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _generatePdf(context, ref, quote, items),
                    icon: const Icon(Symbols.picture_as_pdf_rounded),
                    label: const Text('Genera PDF'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ColorScheme colorScheme,
    QuoteData quote,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quote.quoteNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(colorScheme, quote.status),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(
              Symbols.event_rounded,
              'Creato',
              DateFormat('dd/MM/yyyy', 'it').format(quote.createdAt),
            ),
            if (quote.validUntil != null)
              _buildInfoRow(
                Symbols.schedule_rounded,
                'Valido fino',
                DateFormat('dd/MM/yyyy', 'it').format(quote.validUntil!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ColorScheme colorScheme, String status) {
    final (color, label) = switch (status) {
      'draft' => (colorScheme.outline, 'Bozza'),
      'sent' => (colorScheme.primary, 'Inviato'),
      'accepted' => (Colors.green, 'Accettato'),
      'rejected' => (colorScheme.error, 'Rifiutato'),
      'expired' => (Colors.orange, 'Scaduto'),
      _ => (colorScheme.outline, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildItemsCard(
    BuildContext context,
    ColorScheme colorScheme,
    List<QuoteItemData> items,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.spa_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Servizi inclusi (${items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            ...items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(QuoteItemData item) {
    final hasDiscount = item.discountAmount > 0;
    final originalPrice = item.lockedUnitPrice * item.sessions;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.lockedServiceName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '€${item.lockedUnitPrice.toStringAsFixed(2)} × ${item.sessions} sedut${item.sessions > 1 ? 'e' : 'a'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (hasDiscount) ...[
                  const SizedBox(height: 4),
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
              if (hasDiscount) ...[
                Text(
                  '€${originalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey.shade500,
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
    BuildContext context,
    ColorScheme colorScheme,
    QuoteData quote,
  ) {
    final finalTotal = quote.totalPrice - quote.discountAmount;

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Totale servizi:'),
                Text('€${quote.totalPrice.toStringAsFixed(2)}'),
              ],
            ),
            if (quote.discountAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sconto applicato:'),
                  Text(
                    '-€${quote.discountAmount.toStringAsFixed(2)}',
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
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  '€${finalTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(
    BuildContext context,
    ColorScheme colorScheme,
    String notes,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.note_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Note',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Text(notes),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    QuoteData quote,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina preventivo'),
        content: Text(
          'Sei sicuro di voler eliminare il preventivo "${quote.quoteNumber}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(quotesActionsProvider).deleteQuote(quote.id);
      if (context.mounted) {
        Navigator.pop(context); // Chiudi dialog dettagli
        showCustomSnackBar(
          context: context,
          message: 'Preventivo eliminato',
          okColor: AppTabs.clients.color,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore eliminazione: $e')));
      }
    }
  }

  Future<void> _generatePdf(
    BuildContext context,
    WidgetRef ref,
    QuoteData quote,
    List<QuoteItemData> items,
  ) async {
    try {
      // Genera il PDF elegante
      final bytes = await _createElegantPdf(ref, quote, items);

      if (!context.mounted) return;

      // Salva temporaneamente per la condivisione
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'Preventivo_${quote.quoteNumber.replaceAll('/', '_')}.pdf';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      if (!context.mounted) return;

      // Mostra dialog opzioni
      final action = await showDialog<_PdfAction>(
        context: context,
        builder: (context) => _buildShareOptionsDialog(context, quote),
      );

      if (action == null) return; // Utente ha annullato

      switch (action) {
        case _PdfAction.saveAndOpen:
          // Salva con dialog e apri
          final saveLocation = await getSaveLocation(suggestedName: fileName);
          if (saveLocation == null) return;

          await File(saveLocation.path).writeAsBytes(bytes);

          if (context.mounted) {
            showCustomSnackBar(
              context: context,
              message: 'PDF salvato: $fileName',
            );
            // Apri il file
            await OpenFilex.open(saveLocation.path);
          }

        case _PdfAction.shareWhatsApp:
          final clientId = quote.clientId;
          String? phone;
          if (clientId != null) {
            final client = await ref
                .read(clientsRepositoryProvider)
                .getClientById(clientId);
            phone = client?.phoneNumber;
          }

          // Su Android: usa share_plus (funziona con WhatsApp app)
          // Su Windows: salva in Downloads e apre WhatsApp Web
          if (Platform.isAndroid || Platform.isIOS) {
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(tempFile.path)],
                text:
                    'Ciao! Ti invio il preventivo ${quote.quoteNumber}. '
                    'Per qualsiasi informazione non esitare a contattarmi. '
                    'A presto! 💆‍♀️✨',
              ),
            );
          } else {
            // Desktop (Windows/Linux/Mac): salva e apre WhatsApp Web
            final downloadsDir = await getDownloadsDirectory();
            if (downloadsDir != null) {
              final downloadFile = File('${downloadsDir.path}/$fileName');
              await downloadFile.writeAsBytes(bytes);
            }

            final whatsappText = Uri.encodeComponent(
              'Ciao! Ti invio il preventivo ${quote.quoteNumber}. '
              'Per qualsiasi informazione non esitare a contattarmi. '
              'A presto! 💆‍♀️✨',
            );

            if (phone != null && phone.isNotEmpty) {
              final cleanPhone = phone.replaceAll(
                RegExp(r'[\s\-\+\.\(\)]'),
                '',
              );
              final whatsappUrl = Uri.parse(
                'https://wa.me/$cleanPhone?text=$whatsappText',
              );
              // Prova ad aprire senza canLaunchUrl (spesso fallisce su Windows)
              try {
                await launchUrl(
                  whatsappUrl,
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                debugPrint('Errore apertura WhatsApp: $e');
              }
            }

            if (context.mounted) {
              showCustomSnackBar(
                context: context,
                message:
                    'Il PDF è stato salvato in Download. WhatsApp Web dovrebbe essere aperto. Trascina il file nella chat per inviarlo.',
              );
            }
          }

        case _PdfAction.shareEmail:
          final clientId = quote.clientId;
          String? email;
          if (clientId != null) {
            final client = await ref
                .read(clientsRepositoryProvider)
                .getClientById(clientId);
            email = client?.email;
          }

          // Su Android: usa share_plus (funziona con app email)
          if (Platform.isAndroid || Platform.isIOS) {
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(tempFile.path)],
                subject: 'Preventivo ${quote.quoteNumber} - Beauty Center',
                text:
                    'Gentile Cliente,\n\n'
                    'in allegato trova il preventivo ${quote.quoteNumber}.\n\n'
                    'Restiamo a disposizione per qualsiasi chiarimento.\n\n'
                    'Cordiali saluti,\n'
                    'Beauty Center Team 💆‍♀️',
              ),
            );
          } else {
            // Desktop: salva in Downloads e apri client email o Gmail
            final downloadsDir = await getDownloadsDirectory();
            if (downloadsDir != null) {
              final downloadFile = File('${downloadsDir.path}/$fileName');
              await downloadFile.writeAsBytes(bytes);
            }

            final subject = Uri.encodeComponent(
              'Preventivo ${quote.quoteNumber} - Beauty Center',
            );
            final body = Uri.encodeComponent(
              'Gentile Cliente,\n\n'
              'in allegato trova il preventivo ${quote.quoteNumber}.\n\n'
              'Restiamo a disposizione per qualsiasi chiarimento.\n\n'
              'Cordiali saluti,\n'
              'Beauty Center Team 💆‍♀️',
            );

            // Prova mailto: senza canLaunchUrl (spesso fallisce su Windows)
            final mailtoUrl = Uri.parse(
              'mailto:$email?subject=$subject&body=$body',
            );
            var opened = false;
            try {
              opened = await launchUrl(mailtoUrl);
            } catch (e) {
              debugPrint('Errore mailto: $e');
            }

            // Se mailto fallisce, prova Gmail web
            if (!opened) {
              final gmailUrl = Uri.parse(
                'https://mail.google.com/mail/?view=cm&fs=1&to=$email&su=$subject&body=$body',
              );
              try {
                await launchUrl(gmailUrl, mode: LaunchMode.externalApplication);
                opened = true;
              } catch (e) {
                debugPrint('Errore Gmail: $e');
              }
            }

            if (context.mounted) {
              showCustomSnackBar(
                context: context,
                message:
                    'Il PDF è stato salvato in Download. L\'applicazione email dovrebbe essere aperta. Ricorda di allegare il file manualmente.',
              );
            }
          }
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Errore generazione PDF: $e',
        );
      }
      debugPrint('PDF Generation Error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Crea un PDF elegante stile Beauty Center
  /// Utilizza compute() per eseguire la generazione in un isolate e non bloccare l'UI
  Future<List<int>> _createElegantPdf(
    WidgetRef ref,
    QuoteData quote,
    List<QuoteItemData> items,
  ) async {
    // Recupera dati cliente se presente
    PdfClientInfo? clientInfo;
    if (quote.clientId != null && quote.clientId!.isNotEmpty) {
      final client = await ref
          .read(clientsRepositoryProvider)
          .getClientById(quote.clientId!);
      if (client != null) {
        clientInfo = PdfClientInfo(
          firstName: client.firstName,
          lastName: client.lastName,
          phoneNumber: client.phoneNumber,
          email: client.email,
          address: client.address,
        );
      }
    }

    // Dati del centro estetico (per ora hardcoded, potrebbero venire da settings in futuro)
    final centerInfo = PdfCenterInfo(
      name: 'Beauty Center',
      address: 'Via Roma 123, 00100 Roma (RM)',
      phone: '+39 06 1234567',
      email: 'info@beautycenter.it',
      vatNumber: '12345678901',
    );

    // Esegui la generazione PDF in un isolate per non bloccare il main thread
    return await compute(
      generateQuotePdf,
      PdfGenerationParams(
        quote,
        items,
        clientInfo: clientInfo,
        centerInfo: centerInfo,
      ),
    );
  }

  /// Dialog opzioni condivisione
  Widget _buildShareOptionsDialog(BuildContext context, QuoteData quote) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.picture_as_pdf_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Preventivo Pronto!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cosa vuoi fare con il PDF?',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Salva e Apri
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _PdfAction.saveAndOpen),
              icon: const Icon(Symbols.save_rounded),
              label: const Text('Salva e Apri'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 12),

            // Condividi WhatsApp
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _PdfAction.shareWhatsApp),
              icon: Icon(
                Symbols.chat_rounded,
                color: const Color(0xFF25D366), // Verde WhatsApp
              ),
              label: const Text('Condividi su WhatsApp'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: const Color(0xFF25D366)),
              ),
            ),
            const SizedBox(height: 12),

            // Condividi Email
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _PdfAction.shareEmail),
              icon: Icon(Symbols.mail_rounded, color: colorScheme.primary),
              label: const Text('Invia via Email'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),

            // Annulla
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PdfAction { saveAndOpen, shareWhatsApp, shareEmail }
