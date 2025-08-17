import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgroup_pals/models/assessment_template.dart';
import 'package:playgroup_pals/screens/edit_template_screen.dart';
import 'package:playgroup_pals/data/default_assessment_data.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';

class ManageAssessmentTemplatesScreen extends StatefulWidget {
  const ManageAssessmentTemplatesScreen({Key? key}) : super(key: key);

  @override
  State<ManageAssessmentTemplatesScreen> createState() =>
      _ManageAssessmentTemplatesScreenState();
}

class _ManageAssessmentTemplatesScreenState
    extends State<ManageAssessmentTemplatesScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final Uuid _uuid = const Uuid();

  // Create a template pre-filled with the default criteria
  Future<void> _createDefaultTemplate(String name) async {
    List<Map<String, dynamic>> categories = [];
    int categoryOrder = 0;
    defaultAssessmentData.forEach((categoryTitle, criteriaList) {
      int criterionOrder = 0;
      List<Map<String, dynamic>> criteria = criteriaList.map((criterionText) {
        return AssessmentCriterion(
          id: _uuid.v4(),
          text: criterionText,
          order: criterionOrder++,
        ).toMap();
      }).toList();

      categories.add(AssessmentCategory(
        id: _uuid.v4(),
        title: categoryTitle,
        order: categoryOrder++,
        criteria: criteria.map((c) => AssessmentCriterion.fromMap(c)).toList(),
      ).toMap());
    });

    final newTemplate = {'name': name, 'categories': categories};
    await FirebaseFirestore.instance
        .collection('users/$userId/assessment_templates')
        .add(newTemplate);
  }

  // Import criteria from an Excel file
  Future<void> _importFromExcel(String name) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      Map<String, List<String>> importedData = {};
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;
        // Start from the second row to skip header
        for (int i = 1; i < sheet.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.length >= 2 && row[0]?.value != null && row[1]?.value != null) {
            final category = row[0]!.value.toString().trim();
            final criterion = row[1]!.value.toString().trim();
            if (importedData.containsKey(category)) {
              importedData[category]!.add(criterion);
            } else {
              importedData[category] = [criterion];
            }
          }
        }
      }

      List<Map<String, dynamic>> categories = [];
      int categoryOrder = 0;
      importedData.forEach((categoryTitle, criteriaList) {
        int criterionOrder = 0;
        List<Map<String, dynamic>> criteria = criteriaList.map((criterionText) {
          return AssessmentCriterion(
            id: _uuid.v4(),
            text: criterionText,
            order: criterionOrder++,
          ).toMap();
        }).toList();

        categories.add(AssessmentCategory(
          id: _uuid.v4(),
          title: categoryTitle,
          order: categoryOrder++,
          criteria: criteria.map((c) => AssessmentCriterion.fromMap(c)).toList(),
        ).toMap());
      });

      final newTemplate = {'name': name, 'categories': categories};
      await FirebaseFirestore.instance
          .collection('users/$userId/assessment_templates')
          .add(newTemplate);
    }
  }

  // Show options for creating a new template
  Future<void> _showCreateTemplateOptions() async {
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Template'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template Name (e.g., Final-Term)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(nameController.text), child: const Text('Next')),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    if (!mounted) return; // Guard against async gaps
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Create from Default Criteria'),
              onTap: () {
                Navigator.of(ctx).pop();
                _createDefaultTemplate(name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Import from Excel'),
              subtitle: const Text('Format: Column A=Category, Column B=Criterion'),
              onTap: () {
                Navigator.of(ctx).pop();
                _importFromExcel(name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Create a Blank Template'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final newTemplate = {'name': name, 'categories': []};
                await FirebaseFirestore.instance
                    .collection('users/$userId/assessment_templates')
                    .add(newTemplate);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameTemplate(AssessmentTemplate template) async {
    final nameController = TextEditingController(text: template.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Template Name'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(nameController.text), child: const Text('Save')),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users/$userId/assessment_templates')
          .doc(template.id)
          .update({'name': newName});
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this template and all its criteria? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(child: const Text('No'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Delete')
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
        await FirebaseFirestore.instance
        .collection('users/$userId/assessment_templates')
        .doc(templateId)
        .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Assessment Templates'),
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
            return _EmptyState(onCreate: _showCreateTemplateOptions);
          }

          final templates = snapshot.data!.docs
              .map((doc) => AssessmentTemplate.fromFirestore(doc))
              .toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: templates.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateListItem(
                template: template,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => EditTemplateScreen(template: template),
                  ));
                },
                onRename: () => _renameTemplate(template),
                onDelete: () => _deleteTemplate(template.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTemplateOptions,
        label: const Text('New Template'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// --- NEW WIDGET: Template List Item ---
class _TemplateListItem extends StatelessWidget {
  final AssessmentTemplate template;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TemplateListItem({
    Key? key,
    required this.template,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 20, top: 8, bottom: 8, right: 4),
        leading: Icon(
          Icons.description_outlined,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          template.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${template.categories.length} categories, ${template.categories.fold<int>(0, (prev, cat) => prev + cat.criteria.length)} criteria'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') {
              onRename();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'rename',
              child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename')),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete')),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// --- NEW WIDGET: Empty State ---
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({Key? key, required this.onCreate}) : super(key: key);

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
              'Tap the "New Template" button to create your first assessment template.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
             const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create a Template'),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}
