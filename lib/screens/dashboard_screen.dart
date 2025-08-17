import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playgroup_pals/screens/add_edit_student_screen.dart';
import 'package:playgroup_pals/screens/settings_screen.dart';
import 'package:playgroup_pals/screens/student_detail_screen.dart';
import 'package:share_plus/share_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isProcessing = false;

  late int _selectedYear;
  late int _currentYear;
  late int _lastYear;
  late int _nextYear;
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _selectedYear = _currentYear;
    _lastYear = _currentYear - 1;
    _nextYear = _currentYear + 1;

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchTerm = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  /// Always use this to change the year! This enforces the allowed range.
  void _setYearSafely(int newYear) {
    // Strictly clamp year
    if (newYear < _lastYear) newYear = _lastYear;
    if (newYear > _nextYear) newYear = _nextYear;
    if (_selectedYear != newYear) {
      setState(() {
        _selectedYear = newYear;
      });
    }
  }

  Future<List<int>?> _generateExcelBytes() async {
    final query = FirebaseFirestore.instance
        .collection('users/$userId/students')
        .where('year', isEqualTo: _selectedYear);

    final studentsSnapshot = await query.get();

    if (!mounted) return null;

    if (studentsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No students to export for $_selectedYear.')),
      );
      return null;
    }

    final studentDocs = List<QueryDocumentSnapshot>.from(studentsSnapshot.docs);
    studentDocs.sort((a, b) {
      final nameA = (a.data() as Map<String, dynamic>)['studentName']?.toString().toLowerCase() ?? '';
      final nameB = (b.data() as Map<String, dynamic>)['studentName']?.toString().toLowerCase() ?? '';
      return nameA.compareTo(nameB);
    });

    final excelDoc = excel.Excel.createExcel();
    final sheetName = 'Checklist $_selectedYear';

    try {
      excelDoc.rename('Sheet1', sheetName);
    } catch (_) {}

    final sheet = excelDoc[sheetName];

    final headerStyle = excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    final dataStyle = excel.CellStyle(
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    sheet.cell(excel.CellIndex.indexByString('A1'))
      ..value = excel.TextCellValue('Student Name')
      ..cellStyle = headerStyle;
    sheet.cell(excel.CellIndex.indexByString('B1'))
      ..value = excel.TextCellValue('')
      ..cellStyle = headerStyle;

    for (var i = 0; i < studentDocs.length; i++) {
      final doc = studentDocs[i];
      final data = doc.data() as Map<String, dynamic>;
      final studentName = data['studentName']?.toString() ?? '';

      sheet.cell(excel.CellIndex.indexByString('A${i + 2}'))
        ..value = excel.TextCellValue(studentName)
        ..cellStyle = dataStyle;

      sheet.cell(excel.CellIndex.indexByString('B${i + 2}')).cellStyle = dataStyle;
    }

    final saved = excelDoc.save();
    return saved;
  }

  String get _dynamicFilename => 'Playgroup $_selectedYear Class List';

  Future<void> _exportFile(bool share) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      // Only request permission for saving to public directories
      if (!share && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          _showErrorSnackBar('Storage permission is required to save files.');
          if (await Permission.storage.isPermanentlyDenied) openAppSettings();
          return;
        }
      }

      final fileBytes = await _generateExcelBytes();
      if (fileBytes == null) return;

      if (share) {
        // Sharing via temp dir: no permissions needed!
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/$_dynamicFilename.xlsx";
        final file = File(path);
        await file.writeAsBytes(fileBytes, flush: true);
        await Share.shareXFiles([XFile(path)], text: _dynamicFilename);
      } else {
        await FileSaver.instance.saveFile(
          name: _dynamicFilename,
          bytes: Uint8List.fromList(fileBytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File saved: $_dynamicFilename.xlsx')),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error exporting file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onActionSelected(String action) {
    switch (action) {
      case 'export':
        _exportFile(false);
        break;
      case 'share':
        _exportFile(true);
        break;
      case 'settings':
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
        break;
      case 'logout':
        FirebaseAuth.instance.signOut();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          _isProcessing
              ? const Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3)),
                )
              : PopupMenuButton<String>(
                  onSelected: _onActionSelected,
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'export',
                      child: ListTile(
                          leading: Icon(Icons.save_alt), title: Text('Export Class List')),
                    ),
                    const PopupMenuItem<String>(
                      value: 'share',
                      child: ListTile(
                          leading: Icon(Icons.share), title: Text('Share Class List')),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: ListTile(
                          leading: Icon(Icons.settings_outlined), title: Text('Settings')),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: ListTile(
                          leading: Icon(Icons.logout), title: Text('Logout')),
                    ),
                  ],
                ),
        ],
      ),
      body: Column(
        children: [
          _DashboardHeader(
            selectedYear: _selectedYear,
            searchController: _searchController,
            canGoBack: _selectedYear > _lastYear,
            canGoForward: _selectedYear < _nextYear,
            onYearChanged: _setYearSafely,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users/$userId/students')
                  .where('year', isEqualTo: _selectedYear)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _EmptyState(year: _selectedYear);
                }

                var students = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

                if (_searchTerm.isNotEmpty) {
                  students = students.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['studentName'] as String?) ?? '';
                    return name.toLowerCase().contains(_searchTerm.toLowerCase());
                  }).toList();
                }

                students.sort((a, b) {
                  final nameA = (a.data() as Map<String, dynamic>)['studentName']?.toString().toLowerCase() ?? '';
                  final nameB = (b.data() as Map<String, dynamic>)['studentName']?.toString().toLowerCase() ?? '';
                  return nameA.compareTo(nameB);
                });

                if (students.isEmpty) {
                  return const Center(child: Text('No students match your search.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: students.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return StudentListItem(
                      studentId: student.id,
                      studentData: student.data() as Map<String, dynamic>,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddEditStudentScreen(year: _selectedYear),
          ));
        },
        label: const Text('Add Student'),
        icon: const Icon(Icons.add),
        heroTag: 'add_student',
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final int selectedYear;
  final TextEditingController searchController;
  final ValueChanged<int> onYearChanged;
  final bool canGoBack;
  final bool canGoForward;

  const _DashboardHeader({
    Key? key,
    required this.selectedYear,
    required this.searchController,
    required this.onYearChanged,
    required this.canGoBack,
    required this.canGoForward,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withAlpha(50))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: canGoBack ? () => onYearChanged(selectedYear - 1) : null,
              ),
              Text(
                'Class of $selectedYear',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: canGoForward ? () => onYearChanged(selectedYear + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => searchController.clear(),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentListItem extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> studentData;

  const StudentListItem({
    Key? key,
    required this.studentId,
    required this.studentData,
  }) : super(key: key);

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return parts[0][0].toUpperCase() + parts.last[0].toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentMonthKey = DateFormat('MMMM-yyyy').format(DateTime.now());
    final bool hasAllergies = (studentData['allergies'] as String?)?.trim().isNotEmpty ?? false;
    final String studentName = studentData['studentName'] ?? 'No Name';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withAlpha(40),
          foregroundColor: theme.colorScheme.primary,
          child:
              Text(_getInitials(studentName), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(studentName,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users/$userId/students/$studentId/fees')
                  .doc(currentMonthKey)
                  .snapshots(),
              builder: (context, feeSnapshot) {
                bool isPaid = false;
                if (feeSnapshot.hasData && feeSnapshot.data!.exists) {
                  final feeData = feeSnapshot.data!.data() as Map<String, dynamic>;
                  isPaid = feeData['status'] == 'Paid';
                }
                return _StatusChip(
                  label: '${DateFormat('MMMM').format(DateTime.now())} Fees',
                  isPositive: isPaid,
                  positiveText: 'Paid',
                  negativeText: 'Due',
                );
              },
            ),
            if (hasAllergies) ...[
              const SizedBox(height: 6),
              _StatusChip(
                label: 'Allergies: ${studentData['allergies']}',
                isPositive: false,
                icon: Icons.warning_amber_rounded,
              ),
            ]
          ],
        ),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.primary),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => StudentDetailScreen(studentId: studentId),
          ));
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isPositive;
  final String? positiveText;
  final String? negativeText;
  final IconData? icon;

  const _StatusChip({
    Key? key,
    required this.label,
    required this.isPositive,
    this.positiveText,
    this.negativeText,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positiveColor = Colors.green.shade700;
    final negativeColor = theme.colorScheme.error;
    final color = isPositive ? positiveColor : negativeColor;

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        text: '$label: ',
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150)),
        children: [
          TextSpan(
            text: isPositive ? (positiveText ?? '') : (negativeText ?? ''),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int year;
  const _EmptyState({Key? key, required this.year}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No Students in $year',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the "Add Student" button to get started and build your class list.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
