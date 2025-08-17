import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:io';

class FeeHistory extends StatefulWidget {
  final String studentId;
  final String studentName;
  final int year;

  const FeeHistory({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.year,
  }) : super(key: key);

  @override
  State<FeeHistory> createState() => _FeeHistoryState();
}

class _FeeHistoryState extends State<FeeHistory> {
  void _showConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: Corrected the "Undo" logic to prevent freezing ---
  void _updateFeeStatus(String feeType, String status, Map<String, dynamic> allFees) {
    final feeName =
        feeType == 'registration_fee' ? 'Registration Fee' : feeType;
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final feesRef = FirebaseFirestore.instance
        .collection('users/$userId/students/${widget.studentId}/fees');

    // For "Mark Paid", we always use the new, consistent ID format.
    final docIdForPaying = feeType == 'registration_fee'
        ? 'registration_fee'
        : DateFormat('yyyy-MM').format(DateFormat('MMMM yyyy').parse(feeType));

    if (status == 'Paid') {
      _showConfirmDialog(
        title: 'Confirm Payment',
        content: 'Mark $feeName as paid?',
        onConfirm: () {
          feesRef.doc(docIdForPaying).set({
            'monthYear': feeType, // Keep the display name for the PDF
            'status': 'Paid',
            'paymentDate': Timestamp.now(),
          });
        },
      );
    } else if (status == 'Due') {
      // For "Undo", we find the actual document ID to delete,
      // supporting both old and new formats.
      String? docIdToDelete;
      if (feeType == 'registration_fee') {
        docIdToDelete = 'registration_fee';
      } else {
         // Find the key in allFees that corresponds to the display name
        for (var entry in allFees.entries) {
          if (entry.value['monthYear'] == feeType) {
            docIdToDelete = entry.key;
            break;
          }
        }
        // Fallback for older records that might use the display name as the key
        if (docIdToDelete == null && allFees.containsKey(feeType)) {
          docIdToDelete = feeType;
        }
      }

      if (docIdToDelete != null) {
        _showConfirmDialog(
          title: 'Confirm Undo',
          content: 'Undo the payment for $feeName? This will mark it as due.',
          onConfirm: () {
            // Deleting the document is the most robust way to handle "Undo".
            feesRef.doc(docIdToDelete).delete();
          },
        );
      }
    }
  }

  Future<Uint8List?> _generatePdfBytes(Map<String, dynamic> allFees) async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final settingsDoc = await FirebaseFirestore.instance
        .collection('users/$userId/settings')
        .doc('app_settings')
        .get();
    final settingsData = settingsDoc.data() ?? {};

    final schoolName = settingsData['schoolName'] as String? ?? 'Playgroup Pals';
    final annualFee = settingsData['annualFee'] as double? ?? 0.0;
    final registrationFee =
        settingsData['registrationFee'] as double? ?? 0.0;
    final monthlyFee = annualFee > 0 ? annualFee / 12 : 0.0;

    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Inter-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Inter-Bold.ttf");
    final ttfBold = pw.Font.ttf(boldFontData);

    final primaryColor = PdfColor.fromHex("#0A84FF");
    final textColor = PdfColor.fromHex("#1D1D1F");
    final lightTextColor = PdfColor.fromHex("#8A8A8E");

    pw.ImageProvider? logoImage;
    if (settingsData['logoUrl'] != null) {
      try {
        logoImage = await networkImage(settingsData['logoUrl']);
      } catch (e) {
        logoImage = null;
      }
    }

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final openingBalance = annualFee + registrationFee;
          double runningBalance = openingBalance;

          final isRegFeePaid = allFees.containsKey('registration_fee') &&
              allFees['registration_fee']!['status'] == 'Paid';

          final Map<String, dynamic> uniquePaidMonthlyFees = {};
          allFees.forEach((key, value) {
            if (value['status'] == 'Paid' && key != 'registration_fee') {
              uniquePaidMonthlyFees[value['monthYear']] = value;
            }
          });

          final paidMonthlyFeesList = uniquePaidMonthlyFees.entries.toList()
            ..sort((a, b) {
              try {
                var dateA = DateFormat('MMMM yyyy').parse(a.key);
                var dateB = DateFormat('MMMM yyyy').parse(b.key);
                return dateA.compareTo(dateB);
              } catch (e) {
                return 0;
              }
            });

          double totalPaid = 0;
          if (isRegFeePaid) {
            totalPaid += registrationFee;
          }
          totalPaid += paidMonthlyFeesList.length * monthlyFee;
          final totalDue = openingBalance - totalPaid;

          double due30Days = 0;
          double due60Days = 0;
          double due90PlusDays = 0;
          final now = DateTime.now();

          if (!isRegFeePaid) {
            final registrationDueDate = DateTime(widget.year, 1, 1);
            if (registrationDueDate.isBefore(now)) {
              final difference = now.difference(registrationDueDate).inDays;
              if (difference >= 90) {
                due90PlusDays += registrationFee;
              } else if (difference >= 60) due60Days += registrationFee;
              else if (difference >= 30) due30Days += registrationFee;
            }
          }

          for (int i = 1; i <= 12; i++) {
            final monthDate = DateTime(widget.year, i);
            if (monthDate.isAfter(now)) continue;

            final monthYearKey = DateFormat('yyyy-MM').format(monthDate);
            final monthYearDisplay = DateFormat('MMMM yyyy').format(monthDate);

            if (!allFees.containsKey(monthYearKey) || allFees[monthYearKey]!['status'] != 'Paid') {
               if (!uniquePaidMonthlyFees.containsKey(monthYearDisplay)) {
                  final difference = now.difference(monthDate).inDays;
                  if (difference >= 90) {
                    due90PlusDays += monthlyFee;
                  } else if (difference >= 60) due60Days += monthlyFee;
                  else if (difference >= 30) due30Days += monthlyFee;
               }
            }
          }

          final double currentDue = totalDue - due30Days - due60Days - due90PlusDays;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22, color: textColor)),
                      pw.Text('Statement of Account - ${widget.year}', style: pw.TextStyle(fontSize: 14, color: lightTextColor)),
                    ]
                  ),
                  if (logoImage != null)
                    pw.SizedBox(width: 60, height: 60, child: pw.Image(logoImage)),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text('Student: ${widget.studentName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                   pw.Text('Date: ${DateFormat('d MMMM yyyy').format(DateTime.now())}', style: pw.TextStyle(color: lightTextColor)),
                ]
              ),
              pw.Divider(height: 20),
              
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor),
                headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                headers: ['Date Paid', 'Description', 'Amount Paid', 'Balance'],
                data: [
                  ['', 'Opening Balance', '', 'R ${openingBalance.toStringAsFixed(2)}'],
                  if (isRegFeePaid)
                    [
                      allFees['registration_fee']!['paymentDate'] != null
                          ? DateFormat('d MMM yyyy').format((allFees['registration_fee']!['paymentDate'] as Timestamp).toDate())
                          : 'N/A',
                      'Registration Fee',
                      'R ${registrationFee.toStringAsFixed(2)}',
                      'R ${(runningBalance -= registrationFee).toStringAsFixed(2)}'
                    ],
                  ...paidMonthlyFeesList.map((entry) {
                    final data = entry.value;
                    runningBalance -= monthlyFee;
                    return [
                      data['paymentDate'] != null ? DateFormat('d MMM yyyy').format((data['paymentDate'] as Timestamp).toDate()) : 'N/A',
                      data['monthYear'],
                      'R ${monthlyFee.toStringAsFixed(2)}',
                      'R ${runningBalance.toStringAsFixed(2)}'
                    ];
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 30),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Divider(color: PdfColors.grey200),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Due:'),
                          pw.Text('R ${totalDue.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ]
                      )
                    ]
                  )
                )
              ),
              pw.SizedBox(height: 20),
              
              pw.Text('Outstanding Balance Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Table.fromTextArray(
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignments: { for (var i = 0; i < 5; i++) i: pw.Alignment.centerRight },
                headers: ['Current', '30 Days', '60 Days', '90+ Days', 'Total Due'],
                data: [
                  [
                    'R ${currentDue.toStringAsFixed(2)}',
                    'R ${due30Days.toStringAsFixed(2)}',
                    'R ${due60Days.toStringAsFixed(2)}',
                    'R ${due90PlusDays.toStringAsFixed(2)}',
                    'R ${totalDue.toStringAsFixed(2)}'
                  ]
                ],
              ),
              
              pw.Spacer(),

              if (settingsData['bankName'] != null && settingsData['bankName'].isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Divider(),
                    pw.Text('Banking Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('Bank: ${settingsData['bankName']}'),
                    pw.Text('Account Number: ${settingsData['accountNumber']}'),
                    pw.Text('Branch Code: ${settingsData['branchCode']}'),
                  ]
                ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _shareStatement(Map<String, dynamic> fees) async {
    final pdfBytes = await _generatePdfBytes(fees);
    if (pdfBytes == null) return;
    final filename = 'Fees Statement ${widget.studentName} ${widget.year}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  Future<void> _saveStatement(Map<String, dynamic> fees) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Storage permission is required to save files.')),
            );
          }
          return;
        }
      }
    }

    final pdfBytes = await _generatePdfBytes(fees);
    if (pdfBytes == null) return;
    try {
      await FileSaver.instance.saveFile(
        name:
            'Fees Statement ${widget.studentName.replaceAll(' ', '-')} ${widget.year}',
        bytes: pdfBytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statement saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving statement: $e')),
        );
      }
    }
  }

  void _showExportStatementOptions(Map<String, dynamic> fees) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('Save to Device'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _saveStatement(fees);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareStatement(fees);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final feesRef = FirebaseFirestore.instance
        .collection('users/$userId/students/${widget.studentId}/fees');

    return StreamBuilder<QuerySnapshot>(
      stream: feesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFees = {
          for (var doc in snapshot.data!.docs)
            doc.id: doc.data() as Map<String, dynamic>
        };

        List<String> monthsToDisplay = [];
        for (int i = 1; i <= 12; i++) {
          monthsToDisplay
              .add(DateFormat('MMMM yyyy').format(DateTime(widget.year, i)));
        }

        final isRegFeePaid = allFees.containsKey('registration_fee') &&
            allFees['registration_fee']!['status'] == 'Paid';

        return Column(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF Statement'),
              onPressed: () => _showExportStatementOptions(allFees),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 16),
            _FeeListItem(
              title: 'Registration Fee',
              isPaid: isRegFeePaid,
              onUndo: () => _updateFeeStatus('registration_fee', 'Due', allFees),
              onMarkPaid: () => _updateFeeStatus('registration_fee', 'Paid', allFees),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: monthsToDisplay.length,
              itemBuilder: (context, index) {
                final monthYearDisplay = monthsToDisplay[index];
                final monthYearId = DateFormat('yyyy-MM').format(DateFormat('MMMM yyyy').parse(monthYearDisplay));
                
                final isPaid = (allFees.containsKey(monthYearId) && allFees[monthYearId]!['status'] == 'Paid') ||
                               (allFees.containsKey(monthYearDisplay) && allFees[monthYearDisplay]!['status'] == 'Paid');

                return _FeeListItem(
                  title: monthYearDisplay,
                  isPaid: isPaid,
                  onUndo: () => _updateFeeStatus(monthYearDisplay, 'Due', allFees),
                  onMarkPaid: () => _updateFeeStatus(monthYearDisplay, 'Paid', allFees),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _FeeListItem extends StatelessWidget {
  final String title;
  final bool isPaid;
  final VoidCallback onUndo;
  final VoidCallback onMarkPaid;

  const _FeeListItem({
    Key? key,
    required this.title,
    required this.isPaid,
    required this.onUndo,
    required this.onMarkPaid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isPaid
          ? Colors.green.withOpacity(0.05)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPaid
              ? Colors.green.withOpacity(0.2)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: isPaid
            ? TextButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Undo'),
              )
            : ElevatedButton(
                onPressed: onMarkPaid,
                child: const Text('Mark Paid'),
              ),
      ),
    );
  }
}
