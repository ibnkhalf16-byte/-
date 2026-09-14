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

    // تحميل وتثبيت خط Cairo العربي الصريح
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBoldFont = await PdfGoogleFonts.cairoBold();

    final lastBalance = events.isNotEmpty ? (events.last['balance'] as double) : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBoldFont,
        ),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12.0),
            padding: const pw.EdgeInsets.all(8.0),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.blueGrey800)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('كشف حساب مالي', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('الطرف: ${person.name}', style: const pw.TextStyle(fontSize: 13)),
                    if (person.phone.isNotEmpty)
                      pw.Text('الهاتف: ${person.phone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('تجارة علاء أبو شادي', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('التاريخ: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 15.0),
            padding: const pw.EdgeInsets.only(top: 8.0),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.8, color: PdfColors.grey400)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'تم برمجة التطبيق بواسطة علي خلف',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            headers: <String>['التاريخ', 'الحركة', 'البيان', 'مدين (+)', 'دائن (-)', 'الرصيد'],
            data: events.map((ev) {
              return [
                ev['date'].toString(),
                ev['type'].toString(),
                ev['desc'].toString(),
                (ev['debit'] as double) > 0 ? (ev['debit'] as double).toStringAsFixed(2) : '-',
                (ev['credit'] as double) > 0 ? (ev['credit'] as double).toStringAsFixed(2) : '-',
                (ev['balance'] as double).toStringAsFixed(2),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('الرصيد النهائي المستحق:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${lastBalance.toStringAsFixed(2)} ج.م (${lastBalance >= 0 ? "رصيد لك" : "رصيد عليك"})',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: lastBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${person.name}',
    );
  }
}
              children: [
                pw.Text('الرصيد النهائي المستحق:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${lastBalance.toStringAsFixed(2)} ج.م (${lastBalance >= 0 ? "رصيد لك" : "رصيد عليك"})',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: lastBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${person.name}',
    );
  }
}
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('الرصيد النهائي المستحق:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${lastBalance.toStringAsFixed(2)} جنيه مصري (${lastBalance >= 0 ? "رصيد لك" : "رصيد عليك"})',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: lastBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${person.name}',
    );
  }
}
