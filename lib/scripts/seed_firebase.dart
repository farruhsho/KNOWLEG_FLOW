import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to seed Firebase with initial data
/// Run: dart run lib/scripts/seed_firebase.dart
Future<void> main() async {
  // ignore: avoid_print
  print('🌱 Starting Firebase seed...');
  
  // Initialize Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  
  // Read seed data
  final file = File('firebase_seed_data.json');
  if (!file.existsSync()) {
    // ignore: avoid_print
    print('❌ firebase_seed_data.json not found!');
    return;
  }
  
  final jsonString = await file.readAsString();
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  
  // Seed subjects
  // ignore: avoid_print
  print('\n📚 Seeding subjects...');
  final subjects = data['subjects'] as List;
  for (final subject in subjects) {
    final subjectData = subject as Map<String, dynamic>;
    final id = subjectData['id'] as String;
    await firestore.collection('subjects').doc(id).set(subjectData);
    // ignore: avoid_print
    print('  ✅ Added subject: ${subjectData['name']['ru']}');
  }
  
  // Seed lessons
  // ignore: avoid_print
  print('\n📖 Seeding lessons...');
  final lessons = data['lessons'] as List;
  for (final lesson in lessons) {
    final lessonData = lesson as Map<String, dynamic>;
    final id = lessonData['id'] as String;
    await firestore.collection('lessons').doc(id).set(lessonData);
    // ignore: avoid_print
    print('  ✅ Added lesson: ${lessonData['title']['ru']}');
  }
  
  // ignore: avoid_print
  
  print('\n✅ Firebase seed completed successfully!');
  // ignore: avoid_print
  print('📊 Summary:');
  // ignore: avoid_print
  print('  - Subjects: ${subjects.length}');
  // ignore: avoid_print
  print('  - Lessons: ${lessons.length}');
}
