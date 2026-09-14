import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/person_model.dart';

class PdfGenerator {
  static Future<void> generateAndPrintStatement({
    required PersonModel person,
    required List<Map<String, dynamic>> events,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final lastBalance = events.isNotEmpty 
        ? (events.last['balance'] as num?)?.toDouble() ?? 0.0 
        : 0.0;
        
    final currentDateStr = DateTime.now().toString().substring(0, 16);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                width: double.infinity,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                child: pw.Text(
                  'حسابات علاء أبو شادي ', // مسافة أمان لمنع قص حرف الياء
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  pw.Text(
                    'كشف حساب: ${person.name} ',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'صفحة ${context.pageNumber}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'تاريخ الطباعة: $currentDateStr',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E3A5F),
            ),
            headerHeight: 24,
            cellHeight: 20,
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            headers: <String>[
              'التاريخ',
              'النوع',
              'البيان',
              'السيارة',
              'السائق',
              'طن',
              'سعر الطن',
              'مدين',
              'دائن',
              'الرصيد',
            ],
            data: events.map((ev) {
              final double debit = (ev['debit'] as num?)?.toDouble() ?? 0.0;
              final double credit = (ev['credit'] as num?)?.toDouble() ?? 0.0;
              final double balance = (ev['balance'] as num?)?.toDouble() ?? 0.0;

              // قراءة الأوزان والأسعار بمختلف التسميات المحتملة
              final double weight = (ev['weight'] ?? ev['qty'] ?? ev['ton'] as num?)?.toDouble() ?? 0.0;
              final double price = (ev['price'] ?? ev['unit_price'] as num?)?.toDouble() ?? 0.0;
              
              final String vehicle = (ev['vehicle'] ?? ev['car'] ?? ev['vehicle_no'] ?? '').toString();
              final String driver = (ev['driver'] ?? ev['driver_name'] ?? '').toString();
              final String itemOrDesc = (ev['desc'] ?? ev['item'] ?? ev['description'] ?? '').toString();

              return [
                ev['date']?.toString() ?? '',
                ev['type']?.toString() ?? '',
                itemOrDesc,
                vehicle,
                driver,
                weight > 0 ? weight.toStringAsFixed(2) : '',
                price > 0 ? price.toStringAsFixed(2) : '',
                debit > 0 ? debit.toStringAsFixed(2) : '0.00',
                credit > 0 ? credit.toStringAsFixed(2) : '0.00',
                balance.toStringAsFixed(2),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              pw.Text(
                'الرصيد النهائي: ${lastBalance.toStringAsFixed(2)}',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          pw.Center(
            child: pw.Text(
              'تم تصميم البرنامج بواسطة علي خلف',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${person.name}',
      format: PdfPageFormat.a4.landscape,
    );
  }
}
