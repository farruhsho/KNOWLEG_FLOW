import '../models/subject_model.dart';
import '../models/lesson_model.dart';
import '../models/question_model.dart';

class MockDataService {
  // Mock Subjects
  static List<SubjectModel> getSubjects() {
    return [
      SubjectModel(
        id: 'math',
        title: {
          'ru': 'Математика',
          'ky': 'Математика',
          'en': 'Mathematics',
        },
        description: {
          'ru': 'Алгебра, геометрия, тригонометрия',
          'ky': 'Алгебра, геометрия, тригонометрия',
          'en': 'Algebra, geometry, trigonometry',
        },
        icon: '📐',
        color: '#8B5CF6',
        moduleIds: ['math-1', 'math-2'],
        difficultyTags: ['basic', 'intermediate', 'advanced'],
        totalLessons: 24,
        totalQuestions: 240,
      ),
      SubjectModel(
        id: 'physics',
        title: {
          'ru': 'Физика',
          'ky': 'Физика',
          'en': 'Physics',
        },
        description: {
          'ru': 'Механика, электричество, оптика',
          'ky': 'Механика, электр, оптика',
          'en': 'Mechanics, electricity, optics',
        },
        icon: '⚡',
        color: '#3B82F6',
        totalLessons: 18,
        totalQuestions: 180,
      ),
      SubjectModel(
        id: 'chemistry',
        title: {
          'ru': 'Химия',
          'ky': 'Химия',
          'en': 'Chemistry',
        },
        description: {
          'ru': 'Органическая и неорганическая химия',
          'ky': 'Органикалык жана органикалык эмес химия',
          'en': 'Organic and inorganic chemistry',
        },
        icon: '🧪',
        color: '#10B981',
        totalLessons: 20,
        totalQuestions: 200,
      ),
      SubjectModel(
        id: 'biology',
        title: {
          'ru': 'Биология',
          'ky': 'Биология',
          'en': 'Biology',
        },
        description: {
          'ru': 'Анатомия, ботаника, генетика',
          'ky': 'Анатомия, ботаника, генетика',
          'en': 'Anatomy, botany, genetics',
        },
        icon: '🧬',
        color: '#06B6D4',
        totalLessons: 22,
        totalQuestions: 220,
      ),
      SubjectModel(
        id: 'history',
        title: {
          'ru': 'История Кыргызстана',
          'ky': 'Кыргызстандын тарыхы',
          'en': 'History of Kyrgyzstan',
        },
        description: {
          'ru': 'От древности до современности',
          'ky': 'Байыркы мезгилден азыркы учурга чейин',
          'en': 'From ancient times to present',
        },
        icon: '📜',
        color: '#EF4444',
        totalLessons: 16,
        totalQuestions: 160,
      ),
    ];
  }

  // Mock Lessons for a subject
  static List<LessonModel> getLessonsBySubject(String subjectId) {
    final now = DateTime.now();

    if (subjectId == 'math') {
      return [
        LessonModel(
          id: 'math-lesson-1',
          subjectId: 'math',
          title: {
            'ru': 'Введение в алгебру',
            'ky': 'Алгебрага киришүү',
            'en': 'Introduction to Algebra',
          },
          content: {
            'ru':
                'Алгебра - это раздел математики, который изучает общие свойства действий над различными величинами и решение уравнений, связанных с этими действиями.\n\nОсновные понятия:\n• Переменные и константы\n• Уравнения и неравенства\n• Функции и графики',
            'ky':
                'Алгебра - математиканын бир бөлүгү, ар кандай чоңдуктар үстүндөгү аракеттердин жалпы касиеттерин жана бул аракеттер менен байланышкан теңдемелерди чечүүнү изилдейт.',
            'en':
                'Algebra is a branch of mathematics that studies the general properties of operations on various quantities and solving equations related to these operations.',
          },
          mediaUrls: [],
          estimatedTimeMinutes: 15,
          tags: ['algebra', 'basics'],
          order: 1,
          createdBy: 'admin',
          createdAt: now,
        ),
        LessonModel(
          id: 'math-lesson-2',
          subjectId: 'math',
          title: {
            'ru': 'Линейные уравнения',
            'ky': 'Сызыктуу теңдемелер',
            'en': 'Linear Equations',
          },
          content: {
            'ru':
                'Линейное уравнение - это уравнение вида ax + b = 0, где a и b - константы, а x - переменная.\n\nПримеры:\n• 2x + 5 = 13\n• 3x - 7 = 5\n• x/2 + 3 = 8\n\nШаги решения:\n1. Перенести все члены с x влево\n2. Перенести константы вправо\n3. Разделить обе части на коэффициент при x',
            'ky':
                'Сызыктуу теңдеме - ax + b = 0 түрүндөгү теңдеме, мында a жана b - константалар, x - өзгөрмө.',
            'en':
                'A linear equation is an equation of the form ax + b = 0, where a and b are constants and x is a variable.',
          },
          mediaUrls: [],
          estimatedTimeMinutes: 20,
          tags: ['algebra', 'equations'],
          order: 2,
          createdBy: 'admin',
          createdAt: now,
        ),
        LessonModel(
          id: 'math-lesson-3',
          subjectId: 'math',
          title: {
            'ru': 'Квадратные уравнения',
            'ky': 'Квадраттык теңдемелер',
            'en': 'Quadratic Equations',
          },
          content: {
            'ru':
                'Квадратное уравнение - это уравнение вида ax² + bx + c = 0.\n\nФормула корней:\nx = (-b ± √(b² - 4ac)) / 2a\n\nДискриминант:\nD = b² - 4ac\n\nЕсли D > 0 - два корня\nЕсли D = 0 - один корень\nЕсли D < 0 - нет действительных корней',
            'ky':
                'Квадраттык теңдеме - ax² + bx + c = 0 түрүндөгү теңдеме.',
            'en':
                'A quadratic equation is an equation of the form ax² + bx + c = 0.',
          },
          mediaUrls: [],
          estimatedTimeMinutes: 25,
          tags: ['algebra', 'equations', 'advanced'],
          order: 3,
          createdBy: 'admin',
          createdAt: now,
        ),
      ];
    }

    // Default lessons for other subjects
    return List.generate(5, (index) {
      return LessonModel(
        id: '$subjectId-lesson-${index + 1}',
        subjectId: subjectId,
        title: {
          'ru': 'Урок ${index + 1}',
          'ky': 'Сабак ${index + 1}',
          'en': 'Lesson ${index + 1}',
        },
        content: {
          'ru': 'Содержание урока ${index + 1} по предмету $subjectId',
          'ky': '$subjectId предмети боюнча ${index + 1} сабактын мазмуну',
          'en': 'Content of lesson ${index + 1} for subject $subjectId',
        },
        mediaUrls: [],
        estimatedTimeMinutes: 15 + (index * 5),
        tags: ['topic-${index + 1}'],
        order: index + 1,
        createdBy: 'admin',
        createdAt: now,
      );
    });
  }

  // Mock Questions
  static List<QuestionModel> getQuestions({int count = 10, String? subjectId}) {
    final now = DateTime.now();
    final questions = <QuestionModel>[];

    for (int i = 0; i < count; i++) {
      questions.add(
        QuestionModel(
          id: 'question-${i + 1}',
          subjectId: subjectId ?? 'math',
          type: 'mcq',
          difficulty: (i % 5) + 1,
          stem: {
            'ru': 'Вопрос ${i + 1}: Сколько будет ${i + 1} + ${i + 1}?',
            'ky': 'Суроо ${i + 1}: ${i + 1} + ${i + 1} канча болот?',
            'en': 'Question ${i + 1}: What is ${i + 1} + ${i + 1}?',
          },
          options: [
            OptionModel(
              id: 'A',
              text: {
                'ru': '${(i + 1) * 2 - 1}',
                'ky': '${(i + 1) * 2 - 1}',
                'en': '${(i + 1) * 2 - 1}',
              },
            ),
            OptionModel(
              id: 'B',
              text: {
                'ru': '${(i + 1) * 2}',
                'ky': '${(i + 1) * 2}',
                'en': '${(i + 1) * 2}',
              },
            ),
            OptionModel(
              id: 'C',
              text: {
                'ru': '${(i + 1) * 2 + 1}',
                'ky': '${(i + 1) * 2 + 1}',
                'en': '${(i + 1) * 2 + 1}',
              },
            ),
            OptionModel(
              id: 'D',
              text: {
                'ru': '${(i + 1) * 2 + 2}',
                'ky': '${(i + 1) * 2 + 2}',
                'en': '${(i + 1) * 2 + 2}',
              },
            ),
          ],
          correctAnswer: 'B',
          explanation: {
            'ru': '${i + 1} + ${i + 1} = ${(i + 1) * 2}',
            'ky': '${i + 1} + ${i + 1} = ${(i + 1) * 2}',
            'en': '${i + 1} + ${i + 1} = ${(i + 1) * 2}',
          },
          tags: ['arithmetic', 'basic'],
          createdBy: 'admin',
          createdAt: now,
        ),
      );
    }

    return questions;
  }

  // Get subject by ID
  static SubjectModel? getSubjectById(String id) {
    try {
      return getSubjects().firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get lesson by ID
  static LessonModel? getLessonById(String id) {
    for (final subject in getSubjects()) {
      final lessons = getLessonsBySubject(subject.id);
      try {
        return lessons.firstWhere((l) => l.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }
}
