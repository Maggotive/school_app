import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgroup_pals/models/assessment_template.dart';
// --- FIX: Corrected the import path ---
import 'package:playgroup_pals/models/student_assessment.dart';
import 'package:playgroup_pals/screens/generate_report_screen.dart';

class AssessmentScoresheetScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final AssessmentTemplate? template;
  final StudentAssessment? existingAssessment;

  const AssessmentScoresheetScreen({
    Key? key,
    required this.studentId,
    required this.studentName,
    this.template,
    this.existingAssessment,
  }) : super(key: key);

  @override
  State<AssessmentScoresheetScreen> createState() =>
      _AssessmentScoresheetScreenState();
}

class _AssessmentScoresheetScreenState extends State<AssessmentScoresheetScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = false;

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _commentsController = TextEditingController();
  late Map<String, int> _scores;
  late List<AssessmentCategory> _categories;
  late String _templateName;
  late String _templateId;
  String? _existingAssessmentId;

  @override
  void initState() {
    super.initState();
    _scores = {};
    
    if (widget.existingAssessment != null) {
      final assessment = widget.existingAssessment!;
      _existingAssessmentId = assessment.id;
      _heightController.text = assessment.height;
      _weightController.text = assessment.weight;
      _commentsController.text = assessment.comments;
      _scores = Map<String, int>.from(assessment.scores);
      _categories = assessment.categories;
      _templateName = assessment.templateName;
      _templateId = assessment.templateId;
    } else {
      final template = widget.template!;
      _categories = template.categories;
      _templateName = template.name;
      _templateId = template.id;
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<String> _saveAssessment() async {
    setState(() { _isLoading = true; });

    final assessmentData = {
      'studentId': widget.studentId,
      'templateId': _templateId,
      'templateName': _templateName,
      'dateCompleted': Timestamp.now(),
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
      'scores': _scores,
      'categories': _categories.map((c) => c.toMap()).toList(),
      'comments': _commentsController.text.trim(),
    };

    final collectionRef = FirebaseFirestore.instance
        .collection('users/$userId/students/${widget.studentId}/assessments');

    String docId;
    if (_existingAssessmentId != null) {
      docId = _existingAssessmentId!;
      await collectionRef.doc(docId).update(assessmentData);
    } else {
      final docRef = await collectionRef.add(assessmentData);
      docId = docRef.id;
      // Update state with the new ID for subsequent saves
      _existingAssessmentId = docId;
    }

    if (mounted) {
      setState(() { _isLoading = false; });
    }
    return docId;
  }

  Future<void> _saveAndExit() async {
    await _saveAssessment();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _proceedToReport() async {
    final docId = await _saveAssessment();
    final doc = await FirebaseFirestore.instance
        .collection('users/$userId/students/${widget.studentId}/assessments')
        .doc(docId)
        .get();
    final latestAssessment = StudentAssessment.fromFirestore(doc);

    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => GenerateReportScreen(
          assessment: latestAssessment,
          studentName: widget.studentName,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- FIX: Removed unused 'theme' variable ---
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingAssessment == null ? 'New Assessment' : 'Edit Assessment'),
        // --- MODIFIED: Replaced button with a cleaner icon button ---
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: 'Save & Exit',
            onPressed: _isLoading ? null : _saveAndExit,
          ),
        ],
      ),
      // --- NEW: Bottom action bar for primary actions ---
      bottomNavigationBar: _BottomActionBar(
        isLoading: _isLoading,
        onProceedToReport: _proceedToReport,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- NEW: Grouped into themed cards ---
                _VitalsCard(
                  heightController: _heightController,
                  weightController: _weightController,
                ),
                const SizedBox(height: 16),
                ..._categories.map((category) {
                  return _CategoryExpansionCard(
                    category: category,
                    scores: _scores,
                    onScoreChanged: (criterionId, score) {
                      setState(() {
                        _scores[criterionId] = score;
                      });
                    },
                  );
                }).toList(),
                const SizedBox(height: 16),
                _CommentsCard(commentsController: _commentsController),
                const SizedBox(height: 80), // Padding for bottom action bar
              ],
            ),
    );
  }
}

// --- NEW WIDGET: Bottom Action Bar ---
class _BottomActionBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onProceedToReport;

  const _BottomActionBar({
    Key? key,
    required this.isLoading,
    required this.onProceedToReport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            // --- FIX: Used withAlpha to address deprecation ---
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.article_outlined),
        label: const Text('Save & Generate Report'),
        onPressed: isLoading ? null : onProceedToReport,
      ),
    );
  }
}

// --- NEW WIDGET: Vitals Card ---
class _VitalsCard extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;

  const _VitalsCard({
    Key? key,
    required this.heightController,
    required this.weightController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: heightController,
                decoration: const InputDecoration(
                  labelText: 'Height',
                  prefixIcon: Icon(Icons.height),
                  suffixText: 'cm',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  prefixIcon: Icon(Icons.scale_outlined),
                  suffixText: 'kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW WIDGET: Category Expansion Card ---
class _CategoryExpansionCard extends StatelessWidget {
  final AssessmentCategory category;
  final Map<String, int> scores;
  final Function(String, int) onScoreChanged;

  const _CategoryExpansionCard({
    Key? key,
    required this.category,
    required this.scores,
    required this.onScoreChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          category.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: category.criteria.map((criterion) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(child: Text(criterion.text)),
                const SizedBox(width: 16),
                _ScoreSelector(
                  score: scores[criterion.id] ?? 0,
                  onChanged: (newScore) {
                    onScoreChanged(criterion.id, newScore);
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- NEW WIDGET: Custom Score Selector ---
class _ScoreSelector extends StatelessWidget {
  final int score;
  final ValueChanged<int> onChanged;

  const _ScoreSelector({
    Key? key,
    required this.score,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ToggleButtons(
      isSelected: [score == 1, score == 2, score == 3],
      onPressed: (index) => onChanged(index + 1),
      borderRadius: BorderRadius.circular(8),
      selectedColor: Colors.white,
      fillColor: theme.colorScheme.primary,
      color: theme.colorScheme.primary,
      constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
      children: const [
        Text('1'),
        Text('2'),
        Text('3'),
      ],
    );
  }
}

// --- NEW WIDGET: Comments Card ---
class _CommentsCard extends StatelessWidget {
  final TextEditingController commentsController;

  const _CommentsCard({Key? key, required this.commentsController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: commentsController,
          decoration: const InputDecoration(
            labelText: 'Teacher\'s Comments',
            hintText: 'Enter your personalized comments here...',
            prefixIcon: Icon(Icons.edit_note_outlined),
          ),
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
  }
}
