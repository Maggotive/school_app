// lib/models/student_assessment.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgroup_pals/models/assessment_template.dart';

// Represents the "snapshot in time" of a student's assessment.
// It stores a copy of the criteria and the scores given.
class StudentAssessment {
  final String id;
  final String studentId;
  final String templateId;
  final String templateName;
  final Timestamp dateCompleted;
  final String comments;
  final String height;
  final String weight;
  final List<AssessmentCategory> categories; // A copy of the categories and criteria
  final Map<String, int> scores; // A map of {criterionId: score}

  StudentAssessment({
    required this.id,
    required this.studentId,
    required this.templateId,
    required this.templateName,
    required this.dateCompleted,
    required this.comments,
    required this.height,
    required this.weight,
    required this.categories,
    required this.scores,
  });

  // Creates a StudentAssessment object from a Firestore document
  factory StudentAssessment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StudentAssessment(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      templateId: data['templateId'] ?? '',
      templateName: data['templateName'] ?? '',
      dateCompleted: data['dateCompleted'] ?? Timestamp.now(),
      comments: data['comments'] ?? '',
      height: data['height'] ?? '',
      weight: data['weight'] ?? '',
      categories: (data['categories'] as List<dynamic>?)
              ?.map((c) => AssessmentCategory.fromMap(c as Map<String, dynamic>))
              .toList() ?? [],
      scores: Map<String, int>.from(data['scores'] ?? {}),
    );
  }

  // Converts a StudentAssessment object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'templateId': templateId,
      'templateName': templateName,
      'dateCompleted': dateCompleted,
      'comments': comments,
      'height': height,
      'weight': weight,
      'categories': categories.map((c) => c.toMap()).toList(),
      'scores': scores,
    };
  }
}
