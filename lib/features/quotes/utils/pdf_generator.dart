import 'dart:developer';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/database/app_database.dart';

/// Client info for PDF generation
class PdfClientInfo {
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? email;
  final String? address;

  PdfClientInfo({
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.email,
    this.address,
  });

  String get fullName => '$firstName $lastName';
}

/// Beauty center details for PDF footer
class PdfCenterInfo {
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? vatNumber;
  final String? website;

  PdfCenterInfo({
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.vatNumber,
    this.website,
  });
}

/// Parameters for PDF generation in isolate
class PdfGenerationParams {
  final QuoteData quote;
  final List<QuoteItemData> items;
  final PdfClientInfo? clientInfo;
  final PdfCenterInfo? centerInfo;

  PdfGenerationParams(this.quote, this.items, {this.clientInfo, this.centerInfo});
}

/// Generate PDF for a quote - designed to run in an isolate
/// This function must be top-level or static to work with compute()
List<int> generateQuotePdf(PdfGenerationParams params) {
  try {
    final quote = params.quote;
    final items = params.items;
    final clientInfo = params.clientInfo;
    final centerInfo = params.centerInfo;

    final document = PdfDocument();
    document.pageSettings.orientation = PdfPageOrientation.portrait;
    document.pageSettings.margins.left = 50;
    document.pageSettings.margins.right = 50;
    document.pageSettings.margins.top = 40;
    document.pageSettings.margins.bottom = 60; // Increased for footer

    final page = document.pages.add();
    final graphics = page.graphics;
    final bounds = page.getClientSize();

    // COLORI ELEGANTI (palette luxury beauty)
    final goldColor = PdfColor(212, 175, 55); // Oro
    final roseGoldColor = PdfColor(183, 110, 121); // Oro rosa
    final charcoalColor = PdfColor(45, 45, 48); // Grigio antracite
    final softGreyColor = PdfColor(245, 245, 245); // Grigio chiaro
    final accentColor = PdfColor(139, 90, 43); // Marrone caldo
    final textDark = PdfColor(51, 51, 51);
    final textLight = PdfColor(120, 120, 120);
    final white = PdfColor(255, 255, 255);

    var currentY = 0.0;

    // ============ HEADER PROFESSIONALE ============
    // Sfondo header bianco con bordo oro superiore
    graphics.drawLine(
      PdfPen(goldColor, width: 4),
      Offset(0, 0),
      Offset(bounds.width, 0),
    );

    final centerName = centerInfo?.name ?? 'Beauty Center';
    final titleFont = PdfStandardFont(PdfFontFamily.timesRoman, 26, style: PdfFontStyle.bold);
    final subtitleFont = PdfStandardFont(PdfFontFamily.timesRoman, 12);

    graphics.drawString(
      centerName,
      titleFont,
      brush: PdfSolidBrush(charcoalColor),
      bounds: Rect.fromLTWH(0, 15, bounds.width, 30),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    graphics.drawString(
      'Eleganza e Benessere per te',
      subtitleFont,
      brush: PdfSolidBrush(textLight),
      bounds: Rect.fromLTWH(0, 50, bounds.width, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Bordo inferiore oro
    graphics.drawLine(
      PdfPen(goldColor, width: 2),
      Offset(0, 75),
      Offset(bounds.width, 75),
    );

    currentY = 95;

    // ============ INFO PREVENTIVO (2 colonne) ============
    final leftColWidth = bounds.width * 0.5;
    final rightColWidth = bounds.width * 0.5;

    // Colonna sinistra: Info Preventivo
    graphics.drawRectangle(
      brush: PdfSolidBrush(softGreyColor),
      bounds: Rect.fromLTWH(0, currentY, leftColWidth - 10, 80),
    );
    graphics.drawLine(
      PdfPen(goldColor, width: 3),
      Offset(0, currentY),
      Offset(0, currentY + 80),
    );

    final quoteLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final quoteNumFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final dateFont = PdfStandardFont(PdfFontFamily.helvetica, 10);

    graphics.drawString(
      'PREVENTIVO',
      quoteLabelFont,
      brush: PdfSolidBrush(accentColor),
      bounds: Rect.fromLTWH(15, currentY + 10, leftColWidth - 25, 12),
    );

    graphics.drawString(
      'N. ${quote.quoteNumber}',
      quoteNumFont,
      brush: PdfSolidBrush(charcoalColor),
      bounds: Rect.fromLTWH(15, currentY + 28, leftColWidth - 25, 20),
    );

    final formattedDate = _formatDate(quote.createdAt);
    graphics.drawString(
      'Data emissione: $formattedDate',
      dateFont,
      brush: PdfSolidBrush(textLight),
      bounds: Rect.fromLTWH(15, currentY + 52, leftColWidth - 25, 12),
    );

    // Colonna destra: Validità
    if (quote.validUntil != null) {
      final validDate = _formatDate(quote.validUntil!);
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 248, 240)),
        pen: PdfPen(goldColor, width: 1),
        bounds: Rect.fromLTWH(leftColWidth + 10, currentY, rightColWidth - 10, 80),
      );

      graphics.drawString(
        'VALIDITÀ',
        quoteLabelFont,
        brush: PdfSolidBrush(accentColor),
        bounds: Rect.fromLTWH(leftColWidth + 25, currentY + 15, rightColWidth - 35, 12),
      );

      final validFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
      graphics.drawString(
        'Valido fino al: $validDate',
        validFont,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(leftColWidth + 25, currentY + 35, rightColWidth - 35, 14),
      );

      graphics.drawString(
        '30 giorni dalla data di emissione',
        PdfStandardFont(PdfFontFamily.helvetica, 9),
        brush: PdfSolidBrush(textLight),
        bounds: Rect.fromLTWH(leftColWidth + 25, currentY + 55, rightColWidth - 35, 10),
      );
    }

    currentY += 100;

    // ============ SEZIONE CLIENTE ============
    final sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);

    graphics.drawString(
      'DESTINATARIO',
      sectionFont,
      brush: PdfSolidBrush(accentColor),
      bounds: Rect.fromLTWH(0, currentY, bounds.width, 14),
    );
    currentY += 20;

    // Box cliente con dettagli completi
    final hasClient = clientInfo != null;
    final clientBoxHeight = hasClient ? 70.0 : 35.0;

    graphics.drawRectangle(
      brush: PdfSolidBrush(white),
      pen: PdfPen(PdfColor(220, 220, 220), width: 1),
      bounds: Rect.fromLTWH(0, currentY, bounds.width, clientBoxHeight),
    );
    graphics.drawLine(
      PdfPen(accentColor, width: 3),
      Offset(0, currentY),
      Offset(0, currentY + clientBoxHeight),
    );

    if (hasClient) {
      final nameFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
      final detailFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      graphics.drawString(
        clientInfo.fullName,
        nameFont,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(15, currentY + 10, bounds.width - 30, 18),
      );

      // Riga con telefono e email
      var detailText = '';
      if (clientInfo.phoneNumber != null && clientInfo.phoneNumber!.isNotEmpty) {
        detailText += 'Tel: ${clientInfo.phoneNumber}';
      }
      if (clientInfo.email != null && clientInfo.email!.isNotEmpty) {
        detailText += detailText.isNotEmpty ? '  |  Email: ${clientInfo.email}' : 'Email: ${clientInfo.email}';
      }
      if (clientInfo.address != null && clientInfo.address!.isNotEmpty) {
        detailText += detailText.isNotEmpty ? '  |  Indirizzo: ${clientInfo.address}' : 'Indirizzo: ${clientInfo.address}';
      }

      if (detailText.isNotEmpty) {
        graphics.drawString(
          detailText,
          detailFont,
          brush: PdfSolidBrush(textLight),
          bounds: Rect.fromLTWH(15, currentY + 35, bounds.width - 30, 20),
        );
      }
    } else {
      graphics.drawString(
        'Cliente non specificato',
        PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(textLight),
        bounds: Rect.fromLTWH(15, currentY + 10, bounds.width - 30, 15),
      );
    }

    currentY += clientBoxHeight + 25;

    // ============ TABELLA SERVIZI/PRODOTTI MIGLIORATA ============
    graphics.drawString(
      'DETTAGLIO SERVIZI E PRODOTTI',
      sectionFont,
      brush: PdfSolidBrush(accentColor),
      bounds: Rect.fromLTWH(0, currentY, bounds.width, 14),
    );
    currentY += 20;

    // Header tabella migliorato
    final tableHeaderHeight = 28.0;
    graphics.drawRectangle(
      brush: PdfSolidBrush(charcoalColor),
      bounds: Rect.fromLTWH(0, currentY, bounds.width, tableHeaderHeight),
    );

    // Colonne: Descrizione | Qtà | Prezzo Unit. | Sconto | Totale
    final colWidths = [
      bounds.width * 0.38, // Descrizione
      bounds.width * 0.12, // Qtà
      bounds.width * 0.18, // Prezzo Unit.
      bounds.width * 0.14, // Sconto
      bounds.width * 0.18, // Totale
    ];
    final headerTextFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    var colX = 0.0;

    final headers = ['Descrizione', 'Qtà', 'Prezzo Unit.', 'Sconto', 'Totale'];
    final alignments = [
      PdfTextAlignment.left,
      PdfTextAlignment.center,
      PdfTextAlignment.right,
      PdfTextAlignment.right,
      PdfTextAlignment.right,
    ];

    for (var i = 0; i < headers.length; i++) {
      graphics.drawString(
        headers[i],
        headerTextFont,
        brush: PdfSolidBrush(white),
        bounds: Rect.fromLTWH(colX + 8, currentY + 7, colWidths[i] - 16, 14),
        format: PdfStringFormat(alignment: alignments[i]),
      );
      colX += colWidths[i];
    }

    currentY += tableHeaderHeight;

    // Righe tabella migliorate
    final rowFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final hasDiscount = item.discountAmount > 0;
      final originalTotal = item.lockedUnitPrice * item.sessions;
      final discountedTotal = item.discountedUnitPrice * item.sessions;

      // Calcola altezza riga dinamica
      var rowHeight = hasDiscount ? 38.0 : 26.0;

      final bgColor = i.isEven ? PdfColor(250, 250, 250) : PdfColor(255, 255, 255);
      graphics.drawRectangle(
        brush: PdfSolidBrush(bgColor),
        bounds: Rect.fromLTWH(0, currentY, bounds.width, rowHeight),
      );

      // Bordo sottile tra righe
      graphics.drawLine(
        PdfPen(PdfColor(230, 230, 230), width: 0.5),
        Offset(0, currentY + rowHeight),
        Offset(bounds.width, currentY + rowHeight),
      );

      colX = 0.0;

      // 1. Descrizione
      graphics.drawString(
        item.lockedServiceName,
        rowFont,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(colX + 8, currentY + 6, colWidths[0] - 12, hasDiscount ? 14 : 14),
      );

      // 2. Quantità
      graphics.drawString(
        '${item.sessions}',
        rowFont,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(colX + colWidths[0], currentY + 6, colWidths[1] - 8, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // 3. Prezzo Unitario
      if (hasDiscount) {
        // Prezzo originale barrato
        graphics.drawString(
          '€${item.lockedUnitPrice.toStringAsFixed(2)}',
          smallFont,
          brush: PdfSolidBrush(textLight),
          bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1], currentY + 4, colWidths[2] - 8, 10),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        // Prezzo scontato
        graphics.drawString(
          '€${item.discountedUnitPrice.toStringAsFixed(2)}',
          PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(accentColor),
          bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1], currentY + 15, colWidths[2] - 8, 12),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      } else {
        graphics.drawString(
          '€${item.lockedUnitPrice.toStringAsFixed(2)}',
          rowFont,
          brush: PdfSolidBrush(textDark),
          bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1], currentY + 6, colWidths[2] - 8, 14),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      }

      // 4. Sconto
      if (hasDiscount) {
        final discountLabel = item.discountType == 'percentage'
            ? '-${item.discountAmount.toStringAsFixed(0)}%'
            : '-€${item.discountAmount.toStringAsFixed(2)}';
        graphics.drawString(
          discountLabel,
          smallFont,
          brush: PdfSolidBrush(roseGoldColor),
          bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1] + colWidths[2], currentY + 6, colWidths[3] - 8, 14),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        // Totale risparmio
        final savings = originalTotal - discountedTotal;
        graphics.drawString(
          'Risparmio: €${savings.toStringAsFixed(2)}',
          PdfStandardFont(PdfFontFamily.helvetica, 7),
          brush: PdfSolidBrush(roseGoldColor),
          bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1] + colWidths[2], currentY + 20, colWidths[3] - 8, 10),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      } else {
        graphics.drawString(
          '-',
          rowFont,
          brush: PdfSolidBrush(textLight),
          bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1] + colWidths[2], currentY + 6, colWidths[3] - 8, 14),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      }

      // 5. Totale riga
      final totalRow = hasDiscount ? discountedTotal : originalTotal;
      graphics.drawString(
        '€${totalRow.toStringAsFixed(2)}',
        PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(hasDiscount ? accentColor : textDark),
        bounds: Rect.fromLTWH(colX + colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3], currentY + 6, colWidths[4] - 12, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      currentY += rowHeight;
    }

    // Bordo inferiore tabella
    graphics.drawLine(
      PdfPen(charcoalColor, width: 2),
      Offset(0, currentY),
      Offset(bounds.width, currentY),
    );

    currentY += 25;

    // ============ TOTALI MIGLIORATI ============
    // Calcola totali dettagliati
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.lockedUnitPrice * item.sessions),
    );
    final itemsDiscount = items.fold<double>(
      0,
      (sum, item) => sum + ((item.lockedUnitPrice - item.discountedUnitPrice) * item.sessions),
    );
    final quoteDiscount = quote.discountAmount;
    final total = quote.totalPrice;

    // Box totali con sfondo
    final totalsBoxWidth = 240.0;
    final totalsX = bounds.width - totalsBoxWidth;

    graphics.drawRectangle(
      brush: PdfSolidBrush(softGreyColor),
      bounds: Rect.fromLTWH(totalsX - 10, currentY, totalsBoxWidth + 10, 110),
    );
    graphics.drawLine(
      PdfPen(goldColor, width: 2),
      Offset(totalsX - 10, currentY),
      Offset(totalsX - 10, currentY + 110),
    );

    var totalY = currentY + 12;

    // Subtotale (somma prezzi originali)
    _drawTotalRow(
      graphics,
      totalsX,
      totalY,
      totalsBoxWidth,
      'Subtotale servizi:',
      subtotal,
      textDark,
      false,
    );
    totalY += 18;

    // Sconti su singoli items
    if (itemsDiscount > 0) {
      _drawTotalRow(
        graphics,
        totalsX,
        totalY,
        totalsBoxWidth,
        'Sconti su servizi:',
        itemsDiscount,
        roseGoldColor,
        false,
      );
      totalY += 18;
    }

    // Sconto globale sul preventivo
    if (quoteDiscount > 0) {
      _drawTotalRow(
        graphics,
        totalsX,
        totalY,
        totalsBoxWidth,
        'Sconto aggiuntivo:',
        quoteDiscount,
        roseGoldColor,
        false,
      );
      totalY += 18;
    }

    // Linea separazione
    graphics.drawLine(
      PdfPen(goldColor, width: 1),
      Offset(totalsX, totalY + 2),
      Offset(bounds.width, totalY + 2),
    );
    totalY += 10;

    // Totale finale evidenziato
    _drawTotalRow(
      graphics,
      totalsX,
      totalY,
      totalsBoxWidth,
      'TOTALE:',
      total,
      accentColor,
      true,
    );

    currentY += 130;

    // ============ NOTE PREVENTIVO ============
    if (quote.notes != null && quote.notes!.isNotEmpty) {
      if (currentY + 60 < bounds.height - 100) {
        graphics.drawString(
          'NOTE',
          sectionFont,
          brush: PdfSolidBrush(accentColor),
          bounds: Rect.fromLTWH(0, currentY, bounds.width, 14),
        );
        currentY += 18;

        graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(255, 250, 245)),
          pen: PdfPen(PdfColor(230, 220, 210), width: 1),
          bounds: Rect.fromLTWH(0, currentY, bounds.width, 50),
        );

        final notesFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
        graphics.drawString(
          quote.notes!,
          notesFont,
          brush: PdfSolidBrush(textDark),
          bounds: Rect.fromLTWH(10, currentY + 8, bounds.width - 20, 34),
        );
        currentY += 65;
      }
    }

    // ============ FOOTER CON DETTAGLI CENTRO ============
    final footerY = bounds.height - 55;

    // Linea decorativa footer
    graphics.drawLine(
      PdfPen(goldColor, width: 1.5),
      Offset(0, footerY),
      Offset(bounds.width, footerY),
    );

    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    // Nome centro in grassetto
    final footerCenterName = centerInfo?.name ?? 'Beauty Center';
    graphics.drawString(
      footerCenterName,
      PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(charcoalColor),
      bounds: Rect.fromLTWH(0, footerY + 8, bounds.width, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Dettagli centro (indirizzo, telefono, email, P.IVA)
    var centerDetails = '';
    if (centerInfo?.address != null && centerInfo!.address!.isNotEmpty) {
      centerDetails += centerInfo.address!;
    }
    if (centerInfo?.phone != null && centerInfo!.phone!.isNotEmpty) {
      centerDetails += centerDetails.isNotEmpty ? '  |  Tel: ${centerInfo.phone}' : 'Tel: ${centerInfo.phone}';
    }
    if (centerInfo?.email != null && centerInfo!.email!.isNotEmpty) {
      centerDetails += centerDetails.isNotEmpty ? '  |  Email: ${centerInfo.email}' : 'Email: ${centerInfo.email}';
    }
    if (centerInfo?.vatNumber != null && centerInfo!.vatNumber!.isNotEmpty) {
      centerDetails += centerDetails.isNotEmpty ? '  |  P.IVA: ${centerInfo.vatNumber}' : 'P.IVA: ${centerInfo.vatNumber}';
    }

    if (centerDetails.isNotEmpty) {
      graphics.drawString(
        centerDetails,
        footerFont,
        brush: PdfSolidBrush(textLight),
        bounds: Rect.fromLTWH(0, footerY + 22, bounds.width, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    // Validità preventivo
    graphics.drawString(
      'Preventivo valido per 30 giorni dalla data di emissione. Per confermare, contattaci telefonicamente o via email.',
      PdfStandardFont(PdfFontFamily.helvetica, 7),
      brush: PdfSolidBrush(textLight),
      bounds: Rect.fromLTWH(0, footerY + 38, bounds.width, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Salva e restituisci bytes
    final bytes = document.saveSync();
    document.dispose();

    return bytes;
  } catch (e, stackTrace) {
    log('PDF Generation Error in isolate: $e');
    log(stackTrace.toString());
    rethrow;
  }
}

/// Helper to draw total row
void _drawTotalRow(
  PdfGraphics graphics,
  double x,
  double y,
  double width,
  String label,
  double amount,
  PdfColor color,
  bool isBold,
) {
  final labelFont = PdfStandardFont(
    PdfFontFamily.helvetica,
    isBold ? 12 : 10,
    style: isBold ? PdfFontStyle.bold : PdfFontStyle.regular,
  );
  final valueFont = PdfStandardFont(
    PdfFontFamily.helvetica,
    isBold ? 13 : 10,
    style: isBold ? PdfFontStyle.bold : PdfFontStyle.regular,
  );

  graphics.drawString(
    label,
    labelFont,
    brush: PdfSolidBrush(color),
    bounds: Rect.fromLTWH(x, y, width * 0.5, 16),
    format: PdfStringFormat(alignment: PdfTextAlignment.right),
  );

  graphics.drawString(
    '€${amount.toStringAsFixed(2)}',
    valueFont,
    brush: PdfSolidBrush(color),
    bounds: Rect.fromLTWH(x + width * 0.55, y, width * 0.45, 16),
    format: PdfStringFormat(alignment: PdfTextAlignment.right),
  );
}

/// Format date helper
String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
