import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgroup_pals/models/assessment_template.dart';
import 'package:playgroup_pals/screens/assessment_scoresheet_screen.dart';
import 'package:playgroup_pals/screens/manage_assessment_templates_screen.dart';

class SelectTemplateScreen extends StatelessWidget {
  final String studentId;
  final int studentYear;
  final String studentName;

  const SelectTemplateScreen({
    Key? key,
    required this.studentId,
    required this.studentYear,
    required this.studentName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Template'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users/$userId/assessment_templates')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // --- NEW: Themed Empty State ---
            return _EmptyState();
          }

          final templates = snapshot.data!.docs
              .map((doc) => AssessmentTemplate.fromFirestore(doc))
              .toList();

          // --- MODIFIED: Using ListView.separated for better spacing ---
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: templates.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              // --- NEW: Refactored to a dedicated widget ---
              return _TemplateListItem(
                template: template,
                onTap: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => AssessmentScoresheetScreen(
                      studentId: studentId,
                      studentName: studentName,
                      template: template,
                    ),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- NEW WIDGET: Template List Item ---
class _TemplateListItem extends StatelessWidget {
  final AssessmentTemplate template;
  final VoidCallback onTap;

  const _TemplateListItem({
    Key? key,
    required this.template,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(
          Icons.description_outlined,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          template.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${template.categories.length} categories'),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}

// --- NEW WIDGET: Empty State ---
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No Templates Found',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new assessment template in the settings menu to get started.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Go to Settings'),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const ManageAssessmentTemplatesScreen(),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
