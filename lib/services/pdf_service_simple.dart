import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';

class PdfService {
  Future<void> generateInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    // Load Arabic font from Google Fonts
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Text(
                'فاتورة',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 30),

            // Customer and Date Info
            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'اسم العميل: ${invoice.customerName}',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'التاريخ: ${DateFormat('dd/MM/yyyy').format(invoice.date)}',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'رقم الفاتورة: INV-${DateFormat('yyyyMMdd-HHmmss').format(invoice.date)}',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // Items Table
            pw.Text(
              'تفاصيل البضائع:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('اسم البضاعة', isHeader: true),
                    _buildTableCell('النوع', isHeader: true),
                    _buildTableCell('الكمية', isHeader: true),
                    _buildTableCell('سعر الوحدة', isHeader: true),
                    _buildTableCell('الإجمالي', isHeader: true),
                  ],
                ),
                // Data Rows
                ...invoice.items.map((item) => pw.TableRow(
                  children: [
                    _buildTableCell(item.productName),
                    _buildTableCell(item.productType),
                    _buildTableCell(item.quantity.toString()),
                    _buildTableCell('${item.price.toStringAsFixed(2)} ج.م'),
                    _buildTableCell('${item.total.toStringAsFixed(2)} ج.م'),
                  ],
                )),
              ],
            ),

            pw.SizedBox(height: 25),

            // Total Section
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'الإجمالي الكلي',
                    style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '${invoice.totalAmount.toStringAsFixed(2)} جنيه مصري',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'شكراً لتعاملكم معنا',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'نتطلع لخدمتكم مرة أخرى',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Save and print PDF
    await _savePdf(pdf, invoice);
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 14 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  Future<void> _savePdf(pw.Document pdf, Invoice invoice) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'فاتورة_${invoice.customerName.replaceAll(' ', '_')}_${DateFormat('dd-MM-yyyy').format(invoice.date)}.pdf';
      final file = File('${directory.path}/$fileName');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      // Print PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );

      print('PDF saved to: ${file.path}');
    } catch (e) {
      print('Error saving/printing PDF: $e');
      throw Exception('فشل في حفظ أو طباعة الفاتورة');
    }
  }
}
