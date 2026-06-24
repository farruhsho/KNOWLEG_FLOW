# 📊 ORT MASTER KG - COMPREHENSIVE BUGS ANALYSIS & ACTION PLAN

**Date:** November 26, 2025
**Project:** knowledge_flow (ORT Master KG)
**Platform:** Flutter (Cross-platform: Android/iOS)
**Status:** Post-Analysis - Ready for systematic fixes

---

## ✅ COMPLETED FIXES (Session 1)

| Issue | File | Fix Applied | Status |
|-------|------|-------------|--------|
| Merge conflict markers | `dashboard_page.dart:155-160` | Resolved HEAD/branch conflict | ✅ FIXED |
| Undefined method | `dashboard_page.dart:171` | Changed `_loadGamificationData` → `_loadData` | ✅ FIXED |
| Merge conflict | `subject_detail_page.dart:164-168` | Resolved navigation conflict | ✅ FIXED |
| Compilation | Entire codebase | Verified: 0 errors, only warnings | ✅ VERIFIED |

---

## 🔴 CRITICAL ISSUES REMAINING

### 1. Missing Core Screens

| Screen | Status | Priority | Impact |
|--------|--------|----------|--------|
| Handbook | ❌ Not implemented | HIGH | Missing educational content |
| Tests List | ❌ Empty tab | HIGH | Users can't browse tests |
| Subjects Grid | ⚠️ Placeholder | HIGH | Limited subject exploration |
| Progress Charts | ❌ Not shown | MEDIUM | No visual progress tracking |

### 2. Navigation & UX Issues

```
Issue: Bottom nav uses IndexedStack but content is placeholder
Location: dashboard_page.dart:69-76
Impact: Users see "Предметы" and "Тесты" text instead of actual content
Fix: Implement _SubjectsTab and _TestsTab with real data
```

```
Issue: No "Free ORT" flow
Location: Home screen lacks sample test access
Impact: New users can't try the app without subscription
Fix: Add "Free ORT" button → Category list → Unlock 2 free tests
```

### 3. Data Loading & Firebase Issues

```
Issue: Subjects/Questions use fallback data when Firestore is empty
Location: firebase_data_service.dart:26-36
Impact: App shows dummy data instead of real content
Fix: Pre-populate Firestore using admin_generate_questions_page.dart
```

### 4. Profile Screen Gaps

```
Missing Features:
- ❌ Progress graphs (line/bar charts with fl_chart)
- ❌ Regional rankings (Oblast → District → Village hierarchy)
- ❌ Badges display (achievements grid)
- ❌ Error classification chart
- ❌ AI recommendations ("Focus on Logic - 60% errors")
- ❌ Region selector (editable once/year, Firestore validation)
```

### 5. Admin Panel Limitations

```
Current State:
- ✅ Login works
- ✅ Question generation scaffold exists
- ❌ No AI integration for test generation
- ❌ No duplicate detection algorithm
- ❌ No deep search (YouTube SEKOM/TSOOM, testing.kg scraping)
- ❌ No CRUD UI for editing existing questions
```

---

## 🟡 HIGH PRIORITY ENHANCEMENTS

### 1. Localization Hardcoding

**Problem:** 90% of UI text is hardcoded in Russian
**Example:** `dashboard_page.dart:185` → `'Добрый день!'`
**Fix:**
```dart
// Instead of:
Text('Добрый день!')

// Use:
Text(AppLocalizations.of(context)!.goodDay)
```

**Impact:** Breaks Kyrgyz/English language support

---

### 2. Offline Mode Missing

**Current:** No Hive caching implemented (despite dependency in pubspec.yaml)
**Required:**
```dart
// Cache subjects locally
await Hive.openBox('subjects');
box.put('subjects_cache', subjects);

// Use cache when offline
if (snapshot.docs.isEmpty && hasCache) {
  return getCachedSubjects();
}
```

---

### 3. Firebase Security Rules Undefined

**Risk:** Anyone can read/write all data
**Required Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Questions are read-only for users
    match /questions/{questionId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }

    // User progress private
    match /user_progress/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Ratings are public read, system write only
    match /ratings/{type} {
      allow read: if true;
      allow write: if false; // Cloud Function only
    }
  }
}
```

---

## 🟠 MEDIUM PRIORITY IMPROVEMENTS

### 1. Progress Calculation Accuracy

**Current Issue:** `dashboard_page.dart:355-369`
```dart
// Incorrect: Shows raw count, not weighted score
value: '${_userProgress?.averageScore ?? 0}'

// Should be:
final weightedScore = calculateWeightedScore(
  userProgress.testResults,
  difficultyWeights: {1: 1.0, 2: 1.2, 3: 1.5, 4: 1.8, 5: 2.0}
);
```

### 2. Answer Visibility (Quiz UI)

**Status:** Already has good contrast (white bg, black text)
**Enhancement:** Add hover effect on desktop
```dart
child: MouseRegion(
  cursor: SystemMouseCursors.click,
  child: InkWell(...)
)
```

### 3. Post-Test Screen

**Current:** Works correctly with reward dialog
**Enhancement:** Add AI explanations per question
```dart
// In quiz_results_page.dart (create this)
for (var i = 0; i < questions.length; i++) {
  if (userAnswers[i] != questions[i].correctAnswer) {
    Text(questions[i].getExplanation('ru')),
    Text('💡 Совет: [AI generated tip]'),
  }
}
```

---

## 🚀 IMPLEMENTATION ROADMAP

### Phase 1: Core Functionality (Week 1)

**Priority:** CRITICAL
**Goal:** Make app fully functional with real data

#### Day 1-2: Data Population
- [ ] Run `admin_generate_questions_page.dart` to create 100 sample questions
- [ ] Verify Firestore collections: `subjects`, `questions`, `lessons`
- [ ] Test data loading in app (remove fallback reliance)

#### Day 3-4: Missing Screens
- [ ] Implement Handbook screen (see code below)
- [ ] Create Tests List tab with filters (category, language, difficulty)
- [ ] Enhance Subjects tab with GridView

#### Day 5-7: Profile Enhancements
- [ ] Add fl_chart progress graphs (line + bar)
- [ ] Implement regional rankings (Firestore query)
- [ ] Create region selector dropdown (Kyrgyz geo data)

---

### Phase 2: Advanced Features (Week 2)

#### Day 8-10: Offline Support
- [ ] Implement Hive caching for subjects/questions
- [ ] Add sync indicator in UI
- [ ] Test offline → online sync flow

#### Day 11-12: Admin AI Generator
- [ ] Integrate AI API (Claude/GPT) for question generation
- [ ] Implement duplicate detection (cosine similarity >0.85)
- [ ] Add manual approval workflow

#### Day 13-14: Security & Optimization
- [ ] Deploy Firestore security rules
- [ ] Optimize queries (add indexes)
- [ ] Test with 1000+ questions

---

### Phase 3: Polish & Publishing (Week 3)

#### Day 15-17: Localization
- [ ] Extract all hardcoded strings to `l10n/app_en.arb`, `app_ru.arb`, `app_ky.arb`
- [ ] Regenerate localization files: `flutter gen-l10n`
- [ ] Test language switching

#### Day 18-19: Testing & QA
- [ ] Write widget tests for critical flows
- [ ] Test on Android (API 24+) and iOS (12+)
- [ ] Fix any crashes from Firebase Analytics

#### Day 20-21: App Store Prep
- [ ] Create 1024x1024 icon (with Kyrgyz flag colors)
- [ ] Write privacy policy (GDPR compliant)
- [ ] Generate screenshots (5.5" and 6.5" displays)
- [ ] Build release APK/IPA

---

## 📝 CODE SNIPPETS FOR MISSING FEATURES

### 1. Handbook Screen Implementation

Create `lib/features/handbook/presentation/pages/handbook_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HandbookPage extends StatefulWidget {
  const HandbookPage({super.key});

  @override
  State<HandbookPage> createState() => _HandbookPageState();
}

class _HandbookPageState extends State<HandbookPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник ОРТ'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Математика'),
            Tab(text: 'Русский язык'),
            Tab(text: 'Кыргызский язык'),
            Tab(text: 'Английский'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMathFormulas(),
          _buildRussianGrammar(),
          _buildKyrgyzGrammar(),
          _buildEnglishGuide(),
          _buildHistoryTimeline(),
        ],
      ),
    );
  }

  Widget _buildMathFormulas() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _FormulaCard(
          title: 'Квадратное уравнение',
          formula: 'ax² + bx + c = 0',
          solution: 'x = (-b ± √(b²-4ac)) / 2a',
        ),
        _FormulaCard(
          title: 'Площадь круга',
          formula: 'S = πr²',
        ),
        // Add more formulas...
      ],
    );
  }

  // Implement other tabs similarly...
}

class _FormulaCard extends StatelessWidget {
  final String title;
  final String formula;
  final String? solution;

  const _FormulaCard({
    required this.title,
    required this.formula,
    this.solution,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formula,
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (solution != null) ...[
              const SizedBox(height: 8),
              Text('Решение: $solution'),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Add to router** (`app_router.dart`):
```dart
GoRoute(
  path: '/handbook',
  builder: (context, state) => const HandbookPage(),
),
```

**Add to bottom nav**:
```dart
items: const [
  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
  BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Предметы'),
  BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Тесты'),
  BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Справочник'), // NEW
  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
],
```

---

### 2. Tests List Tab (Real Implementation)

Replace `_TestsTab` in `dashboard_page.dart`:

```dart
class _TestsTab extends ConsumerStatefulWidget {
  const _TestsTab();

  @override
  ConsumerState<_TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends ConsumerState<_TestsTab> {
  final _firebaseDataService = FirebaseDataService();
  String? _selectedCategory;
  String? _selectedLanguage;
  int? _selectedDifficulty;
  List<QuestionModel> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _firebaseDataService.getQuestions(
        count: 50,
        subjectId: _selectedCategory,
        difficulty: _selectedDifficulty,
      );
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тесты')),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    hint: const Text('Категория'),
                    value: _selectedCategory,
                    isExpanded: true,
                    items: ['math', 'russian', 'kyrgyz', 'english', 'history']
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(_getCategoryName(cat)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategory = val);
                      _loadTests();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    hint: const Text('Сложность'),
                    value: _selectedDifficulty,
                    isExpanded: true,
                    items: [1, 2, 3, 4, 5]
                        .map((diff) => DropdownMenuItem(
                              value: diff,
                              child: Text('Уровень $diff'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedDifficulty = val);
                      _loadTests();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Tests List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? const Center(child: Text('Тесты не найдены'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(question.getStem('ru'), maxLines: 2),
                              subtitle: Text(
                                'Сложность: ${question.difficulty}/5',
                              ),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () {
                                // Start quiz with this question
                                context.push('/quiz/${question.subjectId}');
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String cat) {
    const names = {
      'math': 'Математика',
      'russian': 'Русский язык',
      'kyrgyz': 'Кыргызский язык',
      'english': 'Английский',
      'history': 'История',
    };
    return names[cat] ?? cat;
  }
}
```

---

### 3. Profile Progress Graphs (fl_chart)

Add to `profile_page.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';

// In ProfilePage build method, after user info card:
const SizedBox(height: 24),
Text(
  'Прогресс по времени',
  style: Theme.of(context).textTheme.titleLarge,
),
const SizedBox(height: 12),
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text('День ${value.toInt()}');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _getProgressSpots(), // Implement this
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    ),
  ),
),

// Add method:
List<FlSpot> _getProgressSpots() {
  // Fetch from Firestore: user_progress/{userId}/daily_scores
  // For demo:
  return [
    FlSpot(0, 150),
    FlSpot(1, 160),
    FlSpot(2, 155),
    FlSpot(3, 170),
    FlSpot(4, 180),
    FlSpot(5, 175),
    FlSpot(6, 190),
  ];
}
```

---

### 4. Offline Caching with Hive

Add to `firebase_data_service.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';

// In getSubjects():
Future<List<SubjectModel>> getSubjects() async {
  try {
    // Try Firestore first
    final snapshot = await _firestore
        .collection('subjects')
        .orderBy('order', descending: false)
        .get()
        .timeout(const Duration(seconds: 5)); // Add timeout

    if (snapshot.docs.isNotEmpty) {
      final subjects = snapshot.docs
          .map((doc) => SubjectModel.fromFirestore(doc.data(), doc.id))
          .toList();

      // Cache to Hive
      final box = await Hive.openBox('subjects');
      await box.put('subjects_cache', subjects.map((s) => s.toFirestore()).toList());

      return subjects;
    }

    throw Exception('No subjects in Firestore');
  } catch (e) {
    print('⚠️ Firestore error, using cache: $e');

    // Load from Hive cache
    final box = await Hive.openBox('subjects');
    final cached = box.get('subjects_cache') as List<dynamic>?;

    if (cached != null) {
      return cached
          .map((data) => SubjectModel.fromFirestore(
                Map<String, dynamic>.from(data),
                data['id'] ?? '',
              ))
          .toList();
    }

    // Fallback to dummy data
    return _getFallbackSubjects();
  }
}
```

---

### 5. Firebase Security Rules (firestore.rules)

Create `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function isAdmin() {
      return isSignedIn() &&
             get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'admin';
    }

    // Subjects (read-only for users)
    match /subjects/{subjectId} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    // Questions (read-only for users)
    match /questions/{questionId} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    // Lessons (read-only for users)
    match /lessons/{lessonId} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    // User progress (private)
    match /user_progress/{userId} {
      allow read, write: if isOwner(userId);
    }

    // Gamification (private)
    match /gamification/{userId} {
      allow read, write: if isOwner(userId);
    }

    // Daily quests (private)
    match /daily_quests/{userId} {
      allow read, write: if isOwner(userId);
    }

    // Rankings (public read, Cloud Function write)
    match /ratings/{type} {
      allow read: if isSignedIn();
      allow write: if false; // Only Cloud Functions
    }

    // Admins collection (read-only)
    match /admins/{adminId} {
      allow read: if isSignedIn();
      allow write: if false; // Manual setup only
    }
  }
}
```

Deploy with:
```bash
firebase deploy --only firestore:rules
```

---

## 🧠 AI TEST GENERATOR ARCHITECTURE

### Deep Search Sources

1. **YouTube Transcripts:**
```dart
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<List<String>> scrapeYouTubeChannel(String channelId) async {
  final yt = YoutubeExplode();
  final channel = await yt.channels.get(channelId);
  final videos = await yt.channels.getUploads(channel.id).take(10).toList();

  final transcripts = <String>[];
  for (var video in videos) {
    try {
      final manifest = await yt.videos.closedCaptions.getManifest(video.id);
      final trackInfo = manifest.getByLanguage('ru');
      final track = await yt.videos.closedCaptions.get(trackInfo);
      transcripts.add(track.getByTime(Duration.zero).text);
    } catch (e) {
      print('No transcript for ${video.title}');
    }
  }

  return transcripts;
}
```

2. **Website Scraping (testing.kg):**
```dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

Future<List<Map<String, dynamic>>> scrapePDFLinks(String url) async {
  final dio = Dio();
  final response = await dio.get(url);
  final document = html_parser.parse(response.data);

  final pdfLinks = document
      .querySelectorAll('a[href\$=".pdf"]')
      .map((link) => {
            'url': link.attributes['href'],
            'title': link.text,
          })
      .toList();

  return pdfLinks;
}
```

3. **Duplicate Detection (Cosine Similarity):**
```dart
import 'package:ml_linalg/linalg.dart';

double cosineSimilarity(List<double> vec1, List<double> vec2) {
  final v1 = Vector.fromList(vec1);
  final v2 = Vector.fromList(vec2);

  final dotProduct = v1.dot(v2);
  final magnitude1 = v1.norm();
  final magnitude2 = v2.norm();

  return dotProduct / (magnitude1 * magnitude2);
}

Future<bool> isDuplicate(QuestionModel newQuestion, List<QuestionModel> existing) async {
  // Use sentence embeddings (would need API call to embedding service)
  final newEmbedding = await getEmbedding(newQuestion.getStem('ru'));

  for (var existingQ in existing) {
    final existingEmbedding = await getEmbedding(existingQ.getStem('ru'));
    final similarity = cosineSimilarity(newEmbedding, existingEmbedding);

    if (similarity > 0.85) {
      return true; // Duplicate found
    }
  }

  return false;
}
```

---

## 📱 APP STORE / PLAY MARKET CHECKLIST

### Android (Google Play)

- [ ] **App Signing:** Generate keystore with `keytool`
  ```bash
  keytool -genkey -v -keystore ~/ort-master.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ort
  ```

- [ ] **Build Release APK:**
  ```bash
  flutter build appbundle --release
  ```

- [ ] **Required Assets:**
  - App icon: 512x512 PNG
  - Feature graphic: 1024x500 PNG
  - Screenshots: 5.5" (1242x2208) and 6.5" (1284x2778)

- [ ] **Privacy Policy URL:** Host on Firebase Hosting
  ```markdown
  # Privacy Policy - ORT Master KG

  We collect:
  - User email (authentication)
  - Test scores (progress tracking)
  - Device info (analytics)

  We do NOT sell data. Firebase handles all storage.
  ```

- [ ] **Permissions in AndroidManifest.xml:**
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
  ```

### iOS (App Store)

- [ ] **Bundle ID:** `kg.ortmaster.app`
- [ ] **App Icon:** 1024x1024 PNG (no transparency, no alpha)
- [ ] **Provisioning Profile:** Create in Apple Developer Console
- [ ] **Build IPA:**
  ```bash
  flutter build ipa --release
  ```

- [ ] **Info.plist permissions:**
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Upload profile pictures</string>
  ```

- [ ] **App Store Connect Metadata:**
  - Title: "ORT Master KG - Подготовка к ОРТ"
  - Subtitle: "Тесты, уроки, практика для ОРТ"
  - Keywords: "ОРТ, тесты, Кыргызстан, экзамен, подготовка"

---

## 🎯 SUCCESS METRICS

After implementing all fixes, validate:

| Metric | Target | How to Test |
|--------|--------|-------------|
| App compilation | 0 errors | `flutter analyze` |
| Firestore data | 100+ questions | Check Firebase Console |
| Offline mode | Works without internet | Airplane mode test |
| Performance | <2s screen loads | Use DevTools profiler |
| Security | Rules deny unauthorized access | Try accessing data while logged out |
| Localization | All screens support ru/ky/en | Switch language in settings |
| Crash-free rate | >99.5% | Monitor Firebase Crashlytics |

---

## 📞 NEXT STEPS

1. **Prioritize:** Start with Phase 1 (Core Functionality)
2. **Track Progress:** Use GitHub Issues for each task
3. **Test Continuously:** Run `flutter test` after each fix
4. **Deploy Incrementally:** Release to TestFlight/Internal Testing first

For urgent fixes, focus on:
- ✅ Merge conflicts (DONE)
- ⚡ Handbook screen
- ⚡ Tests list tab
- ⚡ Firebase security rules

---

**Generated by:** Claude Code (Sonnet 4.5)
**Last Updated:** November 26, 2025
**Estimated Total Work:** ~60-80 hours (3 weeks for 1 developer)
