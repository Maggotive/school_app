import 'package:flutter/material.dart';
// --- FIX: Corrected the import path ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:playgroup_pals/models/assessment_template.dart';
import 'package:uuid/uuid.dart';

class EditTemplateScreen extends StatefulWidget {
  final AssessmentTemplate template;
  const EditTemplateScreen({Key? key, required this.template}) : super(key: key);

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  late AssessmentTemplate _template;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final Uuid _uuid = const Uuid();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the template to work with
    _template = AssessmentTemplate(
      id: widget.template.id,
      name: widget.template.name,
      categories: List<AssessmentCategory>.from(
        widget.template.categories.map(
          (cat) => AssessmentCategory(
            id: cat.id,
            title: cat.title,
            order: cat.order,
            criteria: List<AssessmentCriterion>.from(
              cat.criteria.map(
                (crit) => AssessmentCriterion(
                  id: crit.id,
                  text: crit.text,
                  order: crit.order,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Persist all changes to Firestore
  Future<void> _saveTemplate() async {
    if (!mounted) return;
    setState(() { _isSaving = true; });

    // Update the order fields before saving
    for (int i = 0; i < _template.categories.length; i++) {
      _template.categories[i].order = i;
      for (int j = 0; j < _template.categories[i].criteria.length; j++) {
        _template.categories[i].criteria[j].order = j;
      }
    }

    final categoriesAsMaps =
        _template.categories.map((c) => c.toMap()).toList();
    try {
      await FirebaseFirestore.instance
          .collection('users/$userId/assessment_templates')
          .doc(_template.id)
          .update({'categories': categoriesAsMaps});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved!')),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
       if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  // Show dialog to add/edit a category or criterion
  Future<String?> _showTextDialog({String? title, String? label, String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? ''),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label ?? ''),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
  }

  // --- Category Functions ---
  void _addCategory() async {
    final title = await _showTextDialog(
      title: 'New Category',
      label: 'Category Title (e.g., Gross Motor)',
    );
    if (title != null && title.trim().isNotEmpty) {
      setState(() {
        _template.categories.add(AssessmentCategory(
          id: _uuid.v4(),
          title: title,
          order: _template.categories.length,
          criteria: [],
        ));
      });
      await _saveTemplate();
    }
  }

  void _editCategory(AssessmentCategory category) async {
    final newTitle = await _showTextDialog(
      title: 'Edit Category',
      label: 'Category Title',
      initialValue: category.title,
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      setState(() {
        category.title = newTitle;
      });
      await _saveTemplate();
    }
  }

  void _deleteCategory(AssessmentCategory category) {
    setState(() {
      _template.categories.remove(category);
    });
    _saveTemplate();
  }

  // --- Criterion Functions ---
  void _addCriterion(AssessmentCategory category) async {
    final text = await _showTextDialog(
      title: 'New Criterion',
      label: 'Criterion Text',
    );
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        category.criteria.add(AssessmentCriterion(
          id: _uuid.v4(),
          text: text,
          order: category.criteria.length,
        ));
      });
      await _saveTemplate();
    }
  }

  void _editCriterion(AssessmentCriterion criterion) async {
    final newText = await _showTextDialog(
      title: 'Edit Criterion',
      label: 'Criterion Text',
      initialValue: criterion.text,
    );
    if (newText != null && newText.trim().isNotEmpty) {
      setState(() {
        criterion.text = newText;
      });
      await _saveTemplate();
    }
  }

  void _deleteCriterion(AssessmentCategory category, AssessmentCriterion criterion) {
    setState(() {
      category.criteria.remove(criterion);
    });
    _saveTemplate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit "${_template.name}"'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator())),
            )
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 100), // Space for FAB
        itemCount: _template.categories.length,
        itemBuilder: (context, index) {
          final category = _template.categories[index];
          return _CategoryCard(
            key: ValueKey(category.id),
            category: category,
            reorderHandle: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            onEdit: () => _editCategory(category),
            onDelete: () => _deleteCategory(category),
            onAddCriterion: () => _addCriterion(category),
            onReorderCriterion: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = category.criteria.removeAt(oldIndex);
                category.criteria.insert(newIndex, item);
              });
              _saveTemplate();
            },
            onEditCriterion: _editCriterion,
            onDeleteCriterion: (criterion) => _deleteCriterion(category, criterion),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _template.categories.removeAt(oldIndex);
            _template.categories.insert(newIndex, item);
          });
          _saveTemplate();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        onPressed: _addCategory,
      ),
    );
  }
}

// --- NEW WIDGET: Category Card ---
class _CategoryCard extends StatelessWidget {
  final AssessmentCategory category;
  final Widget reorderHandle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddCriterion;
  final ReorderCallback onReorderCriterion;
  final ValueChanged<AssessmentCriterion> onEditCriterion;
  final ValueChanged<AssessmentCriterion> onDeleteCriterion;

  const _CategoryCard({
    Key? key,
    required this.category,
    required this.reorderHandle,
    required this.onEdit,
    required this.onDelete,
    required this.onAddCriterion,
    required this.onReorderCriterion,
    required this.onEditCriterion,
    required this.onDeleteCriterion,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: reorderHandle,
            title: Text(category.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
              ],
            ),
          ),
          const Divider(height: 1),
          if (category.criteria.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No criteria added yet.', style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.criteria.length,
              itemBuilder: (context, critIndex) {
                final criterion = category.criteria[critIndex];
                return ListTile(
                  key: ValueKey(criterion.id),
                  leading: ReorderableDragStartListener(
                    index: critIndex,
                    child: const Icon(Icons.drag_indicator, color: Colors.grey),
                  ),
                  title: Text(criterion.text),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                       if (value == 'edit') onEditCriterion(criterion);
                       if (value == 'delete') onDeleteCriterion(criterion);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                    ],
                  ),
                );
              },
              onReorder: onReorderCriterion,
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Criterion'),
              onPressed: onAddCriterion,
            ),
          )
        ],
      ),
    );
  }
}
