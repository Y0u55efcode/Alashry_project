import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/invoice.dart';

class PdfService {
  Future<void> generateInvoicePdf(Invoice invoice) async {
    try {
      final pdf = pw.Document();
      final arabicFont = await _loadArabicFont();
      final arabicFontBold = await _loadArabicFontBold();

      // تحميل الصورة بطريقة صحيحة
      Uint8List? logoBytes;
      try {
        logoBytes = await _loadLogo();
      } catch (e) {
        print('تعذر تحميل الشعار: $e');
        // سنستمر بدون الشعار
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicFontBold,
          ),
          margin: pw.EdgeInsets.all(20),
          header: (pw.Context context) {
            return _buildHeader(context, invoice, logoBytes);
          },
          footer: (pw.Context context) {
            return _buildFooter(context);
          },
          build: (pw.Context context) {
            return [
              _buildCustomerInfo(invoice),
              pw.SizedBox(height: 20),
              pw.Text(
                'تفاصيل الاصناف:',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildItemsTable(invoice, arabicFont),
              pw.SizedBox(height: 20),
              _buildTotalSection(invoice, arabicFont),
              pw.SizedBox(height: 30),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'شكراً لتعاملكم معنا',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'نتطلع لخدمتكم مرة أخرى',
                      style: pw.TextStyle(
                        fontSize: 14,
                        font: arabicFont,
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

      await _savePdf(pdf, invoice);
    } catch (e) {
      print('خطأ في إنشاء PDF: $e');
      throw Exception('فشل في إنشاء الفاتورة: $e');
    }
  }

  // تحميل الشعار بطريقة صحيحة
  Future<Uint8List> _loadLogo() async {
    try {
      // محاولة تحميل من assets
      final ByteData data = await rootBundle.load('assets/images/app_icon.png');
      return data.buffer.asUint8List();
    } catch (e) {
      // إذا فشل، إنشاء شعار بسيط
      return await _createSimpleLogo();
    }
  }

  // إنشاء شعار بسيط إذا لم تكن الصورة متوفرة
  Future<Uint8List> _createSimpleLogo() async {
    final recorder = pw.Document();
    recorder.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(60, 60),
        build: (context) => pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            color: PdfColors.blue,
            borderRadius: pw.BorderRadius.circular(30),
          ),
          child: pw.Center(
            child: pw.Text(
              'شعار',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
    return await recorder.save();
  }

  pw.Widget _buildHeader(pw.Context context, Invoice invoice, Uint8List? logoBytes) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // عرض الشعار إذا كان متوفراً
              if (logoBytes != null)
                pw.Container(
                  width: 60,
                  height: 60,
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.Container(
                  width: 60,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.circular(30),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'شعار',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              pw.SizedBox(height: 5),
              pw.Text(
                'الحج يوسف: 01225228202 / 01093491072',
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'خالد يوسف: 01212558797',
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'فاتورة مبيعات ',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'رقم الفاتورة: INV-${DateFormat('yyyyMMdd-HHmmss').format(invoice.date)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(thickness: 2, color: PdfColors.blue),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'تم الإنشاء في: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerInfo(Invoice invoice) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'بيانات العميل',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'الاسم: ${invoice.customerName}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'تاريخ الفاتورة',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  DateFormat('dd/MM/yyyy').format(invoice.date),
                  style: pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(Invoice invoice, pw.Font arabicFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            _buildTableCell('اسم الصنف ', arabicFont, isHeader: true),
            _buildTableCell('النوع', arabicFont, isHeader: true),
            _buildTableCell('الكمية', arabicFont, isHeader: true),
            _buildTableCell('سعر الوحدة', arabicFont, isHeader: true),
            _buildTableCell('الإجمالي', arabicFont, isHeader: true),
          ],
        ),
        ...invoice.items.asMap().entries.map((entry) {
          int index = entry.key;
          var item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              _buildTableCell(item.productName, arabicFont),
              _buildTableCell(item.productType, arabicFont),
              _buildTableCell(item.quantity.toString(), arabicFont),
              _buildTableCell('${item.price.toStringAsFixed(2)} ج.م', arabicFont),
              _buildTableCell('${item.total.toStringAsFixed(2)} ج.م', arabicFont),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 14 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: font,
          color: isHeader ? PdfColors.blue800 : PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTotalSection(Invoice invoice, pw.Font arabicFont) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200, width: 2),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'ملخص الفاتورة',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              font: arabicFont,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.blue200),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'عدد الأصناف: ${invoice.items.length}',
                style: pw.TextStyle(fontSize: 14, font: arabicFont),
              ),
              pw.Text(
                'إجمالي الكمية: ${invoice.items.fold(0, (sum, item) => sum + item.quantity)}',
                style: pw.TextStyle(fontSize: 14, font: arabicFont),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'الإجمالي الكلي: ',
                  style: pw.TextStyle(
                    fontSize: 18,
                    font: arabicFont,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '${invoice.totalAmount.toStringAsFixed(2)} جنيه ',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    font: arabicFont,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Font> _loadArabicFont() async {
    try {
      // محاولة تحميل خط Cairo من Google Fonts
      final fontData = await PdfGoogleFonts.cairoRegular();
      return fontData;
    } catch (e) {
      print('فشل في تحميل خط Cairo: $e');
      try {
        // محاولة تحميل من assets
        final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
        return pw.Font.ttf(fontData);
      } catch (e2) {
        print('فشل في تحميل خط من assets: $e2');
        // استخدام الخط الافتراضي
        return pw.Font.helvetica();
      }
    }
  }

  Future<pw.Font> _loadArabicFontBold() async {
    try {
      final fontData = await PdfGoogleFonts.cairoBold();
      return fontData;
    } catch (e) {
      print('فشل في تحميل خط Cairo Bold: $e');
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
        return pw.Font.ttf(fontData);
      } catch (e2) {
        print('فشل في تحميل خط Bold من assets: $e2');
        return pw.Font.helveticaBold();
      }
    }
  }

  Future<void> _savePdf(pw.Document pdf, Invoice invoice) async {
    try {
      // إنشاء bytes للـ PDF
      final Uint8List pdfBytes = await pdf.save();

      // حفظ الملف محلياً
      await _saveToFile(pdfBytes, invoice);

      // طباعة PDF
      await _printPdf(pdfBytes, invoice);

    } catch (e) {
      print('خطأ في حفظ/طباعة PDF: $e');
      throw Exception('فشل في حفظ أو طباعة الفاتورة: $e');
    }
  }

  Future<void> _saveToFile(Uint8List pdfBytes, Invoice invoice) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'فاتورة_${invoice.customerName.replaceAll(' ', '_')}_${DateFormat('dd-MM-yyyy_HH-mm').format(invoice.date)}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);
      print('تم حفظ PDF في: ${file.path}');
    } catch (e) {
      print('خطأ في حفظ الملف: $e');
    }
  }

  Future<void> _printPdf(Uint8List pdfBytes, Invoice invoice) async {
    try {
      final fileName = 'فاتورة_${invoice.customerName}_${DateFormat('dd-MM-yyyy').format(invoice.date)}';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
        format: PdfPageFormat.a4,
      );

      print('تم إرسال PDF للطباعة بنجاح');
    } catch (e) {
      print('خطأ في الطباعة: $e');

      // محاولة بديلة للطباعة
      try {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'فاتورة_${invoice.customerName}.pdf',
        );
        print('تم مشاركة PDF بنجاح');
      } catch (e2) {
        print('خطأ في مشاركة PDF: $e2');
        throw Exception('فشل في طباعة أو مشاركة الفاتورة');
      }
    }
  }
}
