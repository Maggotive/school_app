import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgroup_pals/models/student_assessment.dart';
import 'package:playgroup_pals/screens/add_edit_student_screen.dart';
import 'package:playgroup_pals/screens/assessment_scoresheet_screen.dart';
import 'package:playgroup_pals/screens/generate_report_screen.dart';
import 'package:playgroup_pals/screens/infographic_screen.dart';
import 'package:playgroup_pals/screens/select_template_screen.dart';
import 'package:playgroup_pals/widgets/fee_history.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  bool _isGenerating = false;

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  Future<void> _generateInfographic(StudentAssessment assessment, String studentName) async {
    setState(() {
      _isGenerating = true;
    });

    // It's recommended to store API keys securely and not hardcode them.
    // This is left as is based on the original code.
    const String apiKey = 'AIzaSyBMqL-fnfV0N0unM9t0QpuXGTzUXLL2EFY';
    const String url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    String assessmentDetails = assessment.categories.map((category) {
      String criteriaDetails = category.criteria.map((criterion) {
        final score = assessment.scores[criterion.id] ?? 0;
        return "- ${criterion.text}: Score $score/3";
      }).join("\n");
      return "Category: ${category.title}\n$criteriaDetails";
    }).join("\n\n");

    final prompt = """
      Generate a single HTML file for a visual, parent-friendly infographic for a playgroup child named $studentName.
      Base the content ONLY on the following scores:
      $assessmentDetails

      **HTML & CSS Requirements:**
      - Must be a single, self-contained HTML file.
      - All CSS must be inline. No external files.
      - Use a playful, colorful theme with a fun, rounded, and easy-to-read sans-serif font like 'Poppins' or a generic 'sans-serif' font family. Avoid cursive fonts and 'Comic Sans MS'.
      - The layout must be responsive and mobile-friendly using flexbox or grid.

      **Content Requirements:**
      - **Summarize, do not list everything.**
      - Create a "My Superpowers! 💪" section highlighting 3-4 key strengths from the highest scores.
      - Create a "My Next Adventure! 🌱" section highlighting 1-2 areas for practice, framed positively.
      - **Include a cute, simple graph or visual.** For example, create a simple bar chart using inline SVG that shows the average score for each category. This gives parents a quick visual summary.
      - Use emojis and simple SVG icons to make it visually engaging.
      - **Do not include teacher's comments.**

      Output ONLY the raw HTML code, starting with `<!DOCTYPE html>`.
      """;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{'parts': [{'text': prompt}]}]
        }),
      ).timeout(const Duration(seconds: 120));

      if (!_isGenerating || !mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        String infographicHtml = decodedResponse['candidates'][0]['content']['parts'][0]['text'];
        
        infographicHtml = infographicHtml.replaceAll("```html", "").replaceAll("```", "").trim();

        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => InfographicScreen(
            infographicHtml: infographicHtml,
            studentName: studentName,
          ),
        ));
      } else {
        throw Exception('Failed to generate infographic. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Could not generate infographic. Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  String _formatPhoneNumberForWhatsapp(String number) {
    String digitsOnly = number.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10 && digitsOnly.startsWith('0')) {
      return '27${digitsOnly.substring(1)}';
    }
    return digitsOnly;
  }

  Future<void> _launchURL(Uri url) async {
    if (!await launchUrl(url)) {
      _showErrorSnackBar('Could not launch $url');
    }
  }

  Future<void> _showSendReminderOptions(Map<String, dynamic> studentData) async {
    final settingsDoc = await FirebaseFirestore.instance.collection('users/$userId/settings').doc('app_settings').get();
    final settingsData = settingsDoc.data() ?? {};

    final schoolName = settingsData['schoolName'] ?? 'Playgroup Pals';
    final bankName = settingsData['bankName'] ?? '[Your Bank Name]';
    final accountNumber = settingsData['accountNumber'] ?? '[Your Account Number]';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Father / Guardian 1'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final parentName = studentData['fatherName'] ?? 'Parent';
                  final phoneNumber = _formatPhoneNumberForWhatsapp(studentData['fatherContact'] ?? '');
                  final currentMonth = DateFormat('MMMM').format(DateTime.now());

                  final message = """Assalaamualaikum $parentName,

Hope you are well.

This is a gentle reminder from $schoolName regarding the outstanding school fees for ${studentData['studentName']} for the month of $currentMonth.

If you have already made the payment, please disregard this message. Otherwise, you can make the payment to the following account:
Bank: $bankName
Account Number: $accountNumber

Thank you for your prompt attention to this matter.

JazakAllah,
$schoolName""";

                  final whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
                  _launchURL(whatsappUri);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Mother / Guardian 2'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final parentName = studentData['motherName'] ?? 'Parent';
                  final phoneNumber = _formatPhoneNumberForWhatsapp(studentData['motherContact'] ?? '');
                  final currentMonth = DateFormat('MMMM').format(DateTime.now());

                  final message = """Assalaamualaikum $parentName,

Hope you are well.

This is a gentle reminder from $schoolName regarding the outstanding school fees for ${studentData['studentName']} for the month of $currentMonth.

If you have already made the payment, please disregard this message. Otherwise, you can make the payment to the following account:
Bank: $bankName
Account Number: $accountNumber

Thank you for your prompt attention to this matter.

JazakAllah,
$schoolName""";

                  final whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
                  _launchURL(whatsappUri);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _deleteAssessment(String assessmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users/$userId/students/${widget.studentId}/assessments')
          .doc(assessmentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Assessment deleted successfully.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting assessment: $e');
    }
  }

  void _confirmDeleteDialog(BuildContext context, {required String title, required String content, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(ctx).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentRef = FirebaseFirestore.instance.collection('users/$userId/students').doc(widget.studentId);

    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: studentRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Scaffold(
                      appBar: AppBar(title: const Text("Error")),
                      body: const Center(child: Text("Student not found.")));
              }
              final studentData = snapshot.data!.data() as Map<String, dynamic>;
              final int studentYear = studentData['year'] ?? DateTime.now().year;
              final String studentName = studentData['studentName'] ?? 'No Name';

              return Scaffold(
                appBar: AppBar(
                  title: Text(studentName),
                  actions: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AddEditStudentScreen(
                              studentId: widget.studentId,
                              year: studentYear,
                            ),
                          ));
                        } else if (value == 'delete') {
                          _confirmDeleteDialog(
                            context,
                            title: 'Delete Student?',
                            content: 'Are you sure you want to permanently delete $studentName? This action cannot be undone.',
                            onConfirm: () async {
                              await studentRef.delete();
                              if(mounted) Navigator.of(context).pop();
                            }
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit Student')),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete Student')),
                        ),
                      ],
                    )
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const _SectionHeader(title: 'Student Information'),
                    _DetailCard(
                      children: [
                        _InfoTile(icon: Icons.cake_outlined, title: 'Date of Birth', subtitle: studentData['dateOfBirth'] ?? 'N/A'),
                        _InfoTile(icon: Icons.warning_amber_rounded, title: 'Allergies', subtitle: studentData['allergies'] ?? 'None', highlight: true),
                      ],
                    ),
                    
                    const _SectionHeader(title: 'Guardian Information'),
                    _ContactCard(
                      title: 'Father / Guardian 1',
                      name: studentData['fatherName'],
                      contact: studentData['fatherContact'],
                      email: studentData['fatherEmail'],
                      onCall: () => _launchURL(Uri.parse('tel:${studentData['fatherContact'] ?? ''}')),
                      onMessage: () => _launchURL(Uri.parse('https://wa.me/${_formatPhoneNumberForWhatsapp(studentData['fatherContact'] ?? '')}')),
                    ),
                    const SizedBox(height: 12),
                     _ContactCard(
                      title: 'Mother / Guardian 2',
                      name: studentData['motherName'],
                      contact: studentData['motherContact'],
                      email: studentData['motherEmail'],
                      onCall: () => _launchURL(Uri.parse('tel:${studentData['motherContact'] ?? ''}')),
                      onMessage: () => _launchURL(Uri.parse('https://wa.me/${_formatPhoneNumberForWhatsapp(studentData['motherContact'] ?? '')}')),
                    ),
                    const SizedBox(height: 12),
                    _ContactCard(
                      title: 'Emergency Contact',
                      name: studentData['emergencyContactName'],
                      contact: studentData['emergencyContactNumber'],
                      isEmergency: true,
                      onCall: () => _launchURL(Uri.parse('tel:${studentData['emergencyContactNumber'] ?? ''}')),
                    ),

                    const _SectionHeader(title: 'Assessments & Reports'),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Assessment'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => SelectTemplateScreen(
                            studentId: widget.studentId,
                            studentName: studentName,
                            studentYear: studentYear,
                          ),
                        ));
                      },
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: studentRef.collection('assessments').orderBy('dateCompleted', descending: true).snapshots(),
                      builder: (context, assessmentSnapshot) {
                        if (!assessmentSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                        if (assessmentSnapshot.data!.docs.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No assessments completed yet.'),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assessmentSnapshot.data!.docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = assessmentSnapshot.data!.docs[index];
                            final assessment = StudentAssessment.fromFirestore(doc);
                            return _AssessmentListItem(
                              assessment: assessment, 
                              studentName: studentName,
                              onGenerateInfographic: () => _generateInfographic(assessment, studentName),
                              onEdit: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => AssessmentScoresheetScreen(
                                    studentId: widget.studentId,
                                    studentName: studentName,
                                    existingAssessment: assessment,
                                  ),
                                ));
                              },
                              onViewReport: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => GenerateReportScreen(
                                    assessment: assessment,
                                    studentName: studentName,
                                  ),
                                ));
                              },
                              onDelete: () => _confirmDeleteDialog(
                                context,
                                title: 'Delete Assessment?',
                                content: 'Are you sure you want to delete the assessment "${assessment.templateName}"? This cannot be undone.',
                                onConfirm: () => _deleteAssessment(assessment.id)
                              ),
                            );
                          },
                        );
                      },
                    ),
                    
                    const _SectionHeader(title: 'Fee History'),
                     Card(
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Column(
                           children: [
                             ElevatedButton.icon(
                               icon: const Icon(Icons.send_outlined),
                               label: const Text('Send Fee Reminder'),
                               onPressed: () => _showSendReminderOptions(studentData),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Theme.of(context).colorScheme.secondary,
                                 foregroundColor: Colors.white,
                                 minimumSize: const Size(double.infinity, 44)
                               ),
                             ),
                             const Divider(height: 24),
                             FeeHistory(
                               studentId: widget.studentId, 
                               studentName: studentName,
                               year: studentYear,
                             ),
                           ],
                         ),
                       ),
                     ),
                  ],
                ),
              );
            },
          ),
          if (_isGenerating)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        const Text('Generating Infographic...', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isGenerating = false;
                            });
                          },
                          child: const Text('Cancel'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- NEW WIDGETS FOR UI OVERHAUL ---

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;

  const _InfoTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlight = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.error;

    return ListTile(
      leading: Icon(icon, color: highlight ? highlightColor : theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          color: highlight ? highlightColor : null,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String title;
  final String? name;
  final String? contact;
  final String? email;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final bool isEmergency;

  const _ContactCard({
    Key? key,
    required this.title,
    this.name,
    this.contact,
    this.email,
    this.onCall,
    this.onMessage,
    this.isEmergency = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = name != null && name!.isNotEmpty;

    return Card(
      color: isEmergency ? theme.colorScheme.error.withAlpha(30) : theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            if (!hasName) const Text('No details provided.'),
            if (hasName) ...[
              Text(name!, style: theme.textTheme.bodyLarge),
              if (contact != null && contact!.isNotEmpty) Text(contact!, style: theme.textTheme.bodyMedium),
              if (email != null && email!.isNotEmpty) Text(email!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onCall != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(foregroundColor: isEmergency ? theme.colorScheme.error : null),
                      ),
                    ),
                  if (onCall != null && onMessage != null) const SizedBox(width: 8),
                  if (onMessage != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onMessage,
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Message'),
                      ),
                    ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _AssessmentListItem extends StatelessWidget {
  final StudentAssessment assessment;
  final String studentName;
  final VoidCallback onGenerateInfographic;
  final VoidCallback onEdit;
  final VoidCallback onViewReport;
  final VoidCallback onDelete;

  const _AssessmentListItem({
    Key? key,
    required this.assessment,
    required this.studentName,
    required this.onGenerateInfographic,
    required this.onEdit,
    required this.onViewReport,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(assessment.templateName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Completed: ${DateFormat.yMMMd().format(assessment.dateCompleted.toDate())}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch(value) {
              case 'infographic': onGenerateInfographic(); break;
              case 'report': onViewReport(); break;
              case 'edit': onEdit(); break;
              case 'delete': onDelete(); break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'infographic', child: ListTile(leading: Icon(Icons.auto_awesome_outlined), title: Text('Infographic'))),
            const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('View Report'))),
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
          ],
        ),
      ),
    );
  }
}
