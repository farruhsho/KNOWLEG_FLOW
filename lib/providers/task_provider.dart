import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

// Riverpod provider
final taskProvider = ChangeNotifierProvider<TaskProvider>((ref) {
  return TaskProvider();
});

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [
    Task(
      id: '1',
      title: 'Основы Flutter',
      description: 'Изучите основы разработки на Flutter',
      category: 'Flutter',
      difficulty: 1,
      questions: [
        Question(
          id: 'q1',
          question: 'Что такое Widget в Flutter?',
          options: [
            'Функция для создания UI',
            'Базовый элемент интерфейса',
            'Система управления состоянием',
            'Библиотека для анимаций',
          ],
          correctAnswerIndex: 1,
          explanation: 'Widget - это базовый элемент интерфейса в Flutter. Всё в Flutter является виджетом.',
        ),
        Question(
          id: 'q2',
          question: 'Какой виджет используется для создания текста?',
          options: [
            'TextWidget',
            'Label',
            'Text',
            'TextView',
          ],
          correctAnswerIndex: 2,
          explanation: 'В Flutter для отображения текста используется виджет Text.',
        ),
      ],
    ),
    Task(
      id: '2',
      title: 'State Management',
      description: 'Управление состоянием в Flutter приложениях',
      category: 'Flutter',
      difficulty: 2,
      questions: [
        Question(
          id: 'q1',
          question: 'Что такое setState()?',
          options: [
            'Функция для создания состояния',
            'Метод для обновления UI',
            'Конструктор класса',
            'Функция инициализации',
          ],
          correctAnswerIndex: 1,
          explanation: 'setState() - это метод, который уведомляет Flutter о необходимости перестроить UI.',
        ),
        Question(
          id: 'q2',
          question: 'Какой виджет является Stateful?',
          options: [
            'Container',
            'Text',
            'StatefulWidget',
            'StatelessWidget',
          ],
          correctAnswerIndex: 2,
          explanation: 'StatefulWidget - это виджет, который может изменять своё состояние.',
        ),
        Question(
          id: 'q3',
          question: 'Когда использовать StatelessWidget?',
          options: [
            'Когда виджет не меняет состояние',
            'Когда нужны анимации',
            'Только для текста',
            'Никогда',
          ],
          correctAnswerIndex: 0,
          explanation: 'StatelessWidget используется для виджетов, которые не меняют своё состояние.',
        ),
      ],
    ),
    Task(
      id: '3',
      title: 'Layouts и UI',
      description: 'Создание красивых пользовательских интерфейсов',
      category: 'UI/UX',
      difficulty: 2,
      questions: [
        Question(
          id: 'q1',
          question: 'Какой виджет используется для вертикального расположения элементов?',
          options: [
            'Row',
            'Column',
            'Stack',
            'Flex',
          ],
          correctAnswerIndex: 1,
          explanation: 'Column используется для вертикального расположения виджетов.',
        ),
        Question(
          id: 'q2',
          question: 'Какой виджет используется для горизонтального расположения?',
          options: [
            'Column',
            'Row',
            'Vertical',
            'Horizontal',
          ],
          correctAnswerIndex: 1,
          explanation: 'Row используется для горизонтального расположения виджетов.',
        ),
      ],
    ),
    Task(
      id: '4',
      title: 'Навигация',
      description: 'Навигация между экранами в Flutter',
      category: 'Navigation',
      difficulty: 3,
      questions: [
        Question(
          id: 'q1',
          question: 'Какой метод используется для перехода на новый экран?',
          options: [
            'Navigator.push()',
            'Navigator.go()',
            'Navigator.navigate()',
            'Navigator.open()',
          ],
          correctAnswerIndex: 0,
          explanation: 'Navigator.push() используется для перехода на новый экран.',
        ),
        Question(
          id: 'q2',
          question: 'Как вернуться на предыдущий экран?',
          options: [
            'Navigator.back()',
            'Navigator.pop()',
            'Navigator.return()',
            'Navigator.previous()',
          ],
          correctAnswerIndex: 1,
          explanation: 'Navigator.pop() используется для возврата на предыдущий экран.',
        ),
      ],
    ),
    Task(
      id: '5',
      title: 'Асинхронное программирование',
      description: 'Работа с Future и async/await',
      category: 'Dart',
      difficulty: 4,
      questions: [
        Question(
          id: 'q1',
          question: 'Что такое Future в Dart?',
          options: [
            'Тип данных для чисел',
            'Асинхронная операция',
            'Класс для работы с датами',
            'Функция обратного вызова',
          ],
          correctAnswerIndex: 1,
          explanation: 'Future представляет результат асинхронной операции, который будет доступен в будущем.',
        ),
        Question(
          id: 'q2',
          question: 'Какое ключевое слово используется с async функциями?',
          options: [
            'wait',
            'await',
            'async',
            'future',
          ],
          correctAnswerIndex: 1,
          explanation: 'await используется для ожидания завершения асинхронной операции.',
        ),
      ],
    ),
  ];

  List<Task> get tasks => _tasks;

  List<Task> get completedTasks => _tasks.where((task) => task.isCompleted).toList();

  List<Task> get pendingTasks => _tasks.where((task) => !task.isCompleted).toList();

  int get totalTasks => _tasks.length;

  int get completedTasksCount => completedTasks.length;

  double get progressPercentage => totalTasks > 0 ? (completedTasksCount / totalTasks) * 100 : 0;

  Task? getTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Task> getTasksByCategory(String category) {
    return _tasks.where((task) => task.category == category).toList();
  }

  void completeTask(String taskId, int score) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      _tasks[taskIndex] = _tasks[taskIndex].copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
        score: score,
      );
      notifyListeners();
    }
  }

  void resetTask(String taskId) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      _tasks[taskIndex] = _tasks[taskIndex].copyWith(
        isCompleted: false,
        completedAt: null,
        score: null,
      );
      notifyListeners();
    }
  }

  void resetAllTasks() {
    for (int i = 0; i < _tasks.length; i++) {
      _tasks[i] = _tasks[i].copyWith(
        isCompleted: false,
        completedAt: null,
        score: null,
      );
    }
    notifyListeners();
  }
}
