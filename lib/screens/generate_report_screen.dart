import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student_assessment.dart';
import 'package:file_saver/file_saver.dart';

class GenerateReportScreen extends StatefulWidget {
  final StudentAssessment assessment;
  final String studentName;

  const GenerateReportScreen({
    Key? key,
    required this.assessment,
    required this.studentName,
  }) : super(key: key);

  @override
  GenerateReportScreenState createState() => GenerateReportScreenState();
}

class GenerateReportScreenState extends State<GenerateReportScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  Uint8List? _pdfBytes;

  // --- NEW: Helper for showing themed snackbars ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<Uint8List> _generatePdfBytes() async {
    // If bytes are already generated, return them to avoid regeneration
    if (_pdfBytes != null) return _pdfBytes!;

    final pdf = pw.Document();
    // Using Inter font to match the app's new theme
    final fontData = await rootBundle.load("assets/fonts/Inter-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final assessment = widget.assessment;

    final sky50 = PdfColor.fromHex("#F0F9FF");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 1.2 * PdfPageFormat.cm,
          marginRight: 1.2 * PdfPageFormat.cm,
          marginTop: 1.5 * PdfPageFormat.cm,
          marginBottom: 1.5 * PdfPageFormat.cm,
        ),
        theme: pw.ThemeData.withFont(base: ttf),
        build: (pw.Context context) {
          return [
            // Centered Student Name Header
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 10),
                margin: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(width: 1.5, color: PdfColors.grey200)),
                ),
                child: pw.Text(
                  widget.studentName,
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800),
                ),
              ),
            ),
            
            // Height and Weight Section
            if (assessment.height.isNotEmpty || assessment.weight.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    if (assessment.height.isNotEmpty)
                      pw.Column(children: [
                        pw.Text('Height', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.Text('${assessment.height} cm', style: const pw.TextStyle(fontSize: 8)),
                      ]),
                    if (assessment.weight.isNotEmpty)
                      pw.Column(children: [
                        pw.Text('Weight', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.Text('${assessment.weight} kg', style: const pw.TextStyle(fontSize: 8)),
                      ]),
                  ],
                ),
              ),

            // Categories Section with improved page break handling
            pw.Wrap(
              children: assessment.categories.map((category) {
                return pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        category.title,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.TableHelper.fromTextArray(
                        border: pw.TableBorder.all(color: PdfColors.grey600, width: 1.0),
                        cellStyle: const pw.TextStyle(fontSize: 8),
                        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        cellAlignments: {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.center,
                        },
                        cellPadding: const pw.EdgeInsets.all(4),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(5),
                          1: const pw.FlexColumnWidth(1),
                        },
                        headers: ['Criteria', 'Score'],
                        data: category.criteria.map((criterion) {
                          final score = assessment.scores[criterion.id] ?? 0;
                          return [criterion.text, score.toString()];
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Comments Section
            if (assessment.comments.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Teacher\'s Comments',
                  style:
                      pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(top: 4),
                decoration: pw.BoxDecoration(
                  color: sky50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromHex("#E0F2FE")),
                ),
                child: pw.Text(assessment.comments, style: const pw.TextStyle(fontSize: 9)),
              ),
            ]
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    if (mounted) {
      setState(() {
        _pdfBytes = bytes;
      });
    }
    return bytes;
  }

  Future<void> _savePdf() async {
    try {
      final bytes = _pdfBytes ?? await _generatePdfBytes();
      await FileSaver.instance.saveFile(
        name: 'Report-${widget.studentName}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      _showSnackBar('Report saved to Downloads!');
    } catch (e) {
      _showSnackBar('Error saving report: $e', isError: true);
    }
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = _pdfBytes ?? await _generatePdfBytes();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Report-${widget.studentName}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(path)],
          text: 'Progress Report for ${widget.studentName}');
    } catch (e) {
      _showSnackBar('Error sharing report: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report for ${widget.studentName}'),
        // --- MODIFIED: Actions moved to a PopupMenuButton for a cleaner UI ---
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                _sharePdf();
              } else if (value == 'save') {
                _savePdf();
              }
            },
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share Report')),
              ),
              const PopupMenuItem<String>(
                value: 'save',
                child: ListTile(leading: Icon(Icons.save_alt_outlined), title: Text('Save to Device')),
              ),
            ],
          ),
        ],
      ),
      body: PdfPreview(
        // --- MODIFIED: Themed the PDF previewer to match the app ---
        pdfPreviewPageDecoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        build: (format) => _generatePdfBytes(),
        onPrinted: (context) => _showSnackBar('Document printed successfully'),
        onShared: (context) => _showSnackBar('Document shared successfully'),
      ),
    );
  }
}
