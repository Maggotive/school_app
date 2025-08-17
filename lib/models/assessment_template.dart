// lib/models/assessment_template.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a single criterion within a category, e.g., "I can throw and catch a ball".
class AssessmentCriterion {
  String id;
  String text;
  int order; // Used for maintaining the display order

  AssessmentCriterion({required this.id, required this.text, required this.order});

  // Converts a criterion object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'order': order,
    };
  }

  // Creates a criterion object from a Firestore Map
  factory AssessmentCriterion.fromMap(Map<String, dynamic> map) {
    return AssessmentCriterion(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      order: map['order'] ?? 0,
    );
  }
}

// Represents a category of criteria, e.g., "Gross Motor Development".
class AssessmentCategory {
  String id;
  String title;
  int order;
  List<AssessmentCriterion> criteria;

  AssessmentCategory({
    required this.id,
    required this.title,
    required this.order,
    required this.criteria,
  });

  // Converts a category object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'criteria': criteria.map((c) => c.toMap()).toList(),
    };
  }

  // Creates a category object from a Firestore Map
  factory AssessmentCategory.fromMap(Map<String, dynamic> map) {
    var criteriaList = (map['criteria'] as List<dynamic>?)
            ?.map((c) => AssessmentCriterion.fromMap(c as Map<String, dynamic>))
            .toList() ?? [];
    // Sort criteria by their order field
    criteriaList.sort((a, b) => a.order.compareTo(b.order));
    return AssessmentCategory(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      order: map['order'] ?? 0,
      criteria: criteriaList,
    );
  }
}

// Represents the entire assessment template, e.g., "Mid-Term Report".
class AssessmentTemplate {
  final String id;
  final String name;
  List<AssessmentCategory> categories;

  AssessmentTemplate({required this.id, required this.name, required this.categories});

  // Creates a template object from a Firestore document
  factory AssessmentTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var categoryList = (data['categories'] as List<dynamic>?)
            ?.map((c) => AssessmentCategory.fromMap(c as Map<String, dynamic>))
            .toList() ?? [];
    // Sort categories by their order field
    categoryList.sort((a, b) => a.order.compareTo(b.order));
    return AssessmentTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      categories: categoryList,
    );
  }
}
