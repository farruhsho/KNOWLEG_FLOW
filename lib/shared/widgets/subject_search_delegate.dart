import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject_model.dart';

/// Search delegate for subjects
class SubjectSearchDelegate extends SearchDelegate<SubjectModel?> {
  final FirebaseFirestore firestore;

  SubjectSearchDelegate(this.firestore);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text('Введите название предмета'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('subjects').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final subjects = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return SubjectModel.fromFirestore(data);
            })
            .where((subject) =>
                subject.getTitle('ru').toLowerCase().contains(query.toLowerCase()) ||
                subject.getTitle('ky').toLowerCase().contains(query.toLowerCase()))
            .toList();

        if (subjects.isEmpty) {
          return const Center(
            child: Text('Предметы не найдены'),
          );
        }

        return ListView.builder(
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return ListTile(
              leading: Text(subject.icon, style: const TextStyle(fontSize: 24)),
              title: Text(subject.getTitle('ru')),
              subtitle: Text(subject.getDescription('ru')),
              onTap: () {
                close(context, subject);
              },
            );
          },
        );
      },
    );
  }
}
