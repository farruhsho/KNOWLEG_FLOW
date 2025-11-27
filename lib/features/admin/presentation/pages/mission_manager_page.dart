import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/daily_mission_model.dart';
import '../../../../shared/widgets/loading_view.dart';

/// Mission Manager Page - Configure daily missions
class MissionManagerPage extends ConsumerStatefulWidget {
  const MissionManagerPage({super.key});

  @override
  ConsumerState<MissionManagerPage> createState() => _MissionManagerPageState();
}

class _MissionManagerPageState extends ConsumerState<MissionManagerPage> {
  final _firestore = FirebaseFirestore.instance;
  List<DailyMissionModel> _missions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('daily_missions')
          .orderBy('created_at', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _missions = snapshot.docs
              .map((doc) => DailyMissionModel.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMissions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showMissionEditor(context, null);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Mission'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загрузка миссий...')
          : _missions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No missions configured'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showMissionEditor(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Mission'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMissions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _missions.length,
                    itemBuilder: (context, index) {
                      final mission = _missions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.stars, color: AppColors.warning),
                          ),
                          title: Text(mission.title['ru'] ?? mission.title.values.first),
                          subtitle: Text(
                            '${mission.type} - ${mission.targetCount} - ${mission.rewardXP} XP',
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showMissionEditor(context, mission);
                              } else if (value == 'delete') {
                                _confirmDelete(mission);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showMissionEditor(BuildContext context, DailyMissionModel? mission) {
    final titleController = TextEditingController(text: mission?.title['ru'] ?? '');
    final descController = TextEditingController(text: mission?.description['ru'] ?? '');
    final targetController = TextEditingController(text: mission?.targetCount.toString() ?? '5');
    final xpController = TextEditingController(text: mission?.rewardXP.toString() ?? '50');
    String selectedType = mission?.type ?? 'test_count';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(mission == null ? 'Create Mission' : 'Edit Mission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (Russian)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Russian)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Mission Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'test_count', child: Text('Complete Tests')),
                    DropdownMenuItem(value: 'study_time', child: Text('Study Time')),
                    DropdownMenuItem(value: 'lesson_complete', child: Text('Complete Lessons')),
                    DropdownMenuItem(value: 'streak', child: Text('Streak Days')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Count',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: xpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'XP Reward',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newMission = DailyMissionModel(
                  id: mission?.id ?? '',
                  title: {'ru': titleController.text},
                  description: {'ru': descController.text},
                  type: selectedType,
                  targetCount: int.tryParse(targetController.text) ?? 5,
                  rewardXP: int.tryParse(xpController.text) ?? 50,
                  createdAt: mission?.createdAt ?? DateTime.now(),
                  expiresAt: DateTime.now().add(const Duration(days: 1)),
                  isActive: true,
                );

                if (mission == null) {
                  await _firestore.collection('daily_missions').add(newMission.toFirestore());
                } else {
                  await _firestore.collection('daily_missions').doc(mission.id).update(newMission.toFirestore());
                }

                Navigator.pop(context);
                _loadMissions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mission saved successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(DailyMissionModel mission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mission'),
        content: Text('Are you sure you want to delete "${mission.title['ru']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('daily_missions').doc(mission.id).delete();
              Navigator.pop(context);
              _loadMissions();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
