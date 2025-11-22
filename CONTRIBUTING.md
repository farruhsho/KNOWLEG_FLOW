# Руководство по внесению вклада в ORT Master KG

Спасибо за интерес к проекту! Мы рады любому вкладу. 🎉

## 📋 Содержание

- [Кодекс поведения](#кодекс-поведения)
- [Как начать](#как-начать)
- [Процесс разработки](#процесс-разработки)
- [Стандарты кода](#стандарты-кода)
- [Структура коммитов](#структура-коммитов)
- [Pull Request процесс](#pull-request-процесс)
- [Тестирование](#тестирование)

## 📜 Кодекс поведения

- Будьте уважительны к другим участникам
- Конструктивная критика приветствуется
- Помогайте новичкам
- Никакого харассмента или дискриминации

## 🚀 Как начать

1. **Fork репозитория**
   ```bash
   # Нажмите кнопку "Fork" на GitHub
   git clone https://github.com/ваш-username/KNOWLEG_FLOW.git
   cd KNOWLEG_FLOW
   ```

2. **Добавьте upstream remote**
   ```bash
   git remote add upstream https://github.com/farruhsho/KNOWLEG_FLOW.git
   ```

3. **Создайте ветку для разработки**
   ```bash
   git checkout -b feature/ваша-фича
   # или
   git checkout -b fix/ваш-fix
   ```

4. **Установите зависимости**
   ```bash
   flutter pub get
   ```

5. **Настройте Firebase** (см. [SETUP.md](SETUP.md))

## 🔄 Процесс разработки

### 1. Синхронизация с upstream

Перед началом работы:
```bash
git fetch upstream
git rebase upstream/main
```

### 2. Разработка

- Пишите чистый, читаемый код
- Следуйте архитектуре Clean Architecture
- Используйте Riverpod для state management
- Добавляйте комментарии для сложной логики

### 3. Тестирование

```bash
# Запустите тесты
flutter test

# Проверьте coverage
flutter test --coverage

# Запустите анализатор
flutter analyze
```

### 4. Коммит изменений

```bash
git add .
git commit -m "feat: добавлена новая фича X"
```

### 5. Push в ваш fork

```bash
git push origin feature/ваша-фича
```

### 6. Создайте Pull Request

- Перейдите на GitHub
- Нажмите "New Pull Request"
- Заполните template
- Дождитесь review

## 📝 Стандарты кода

### Именование

```dart
// Classes: PascalCase
class UserRepository {}

// Functions/Methods: camelCase
void getUserById() {}

// Variables: camelCase
String userName = 'John';

// Constants: SCREAMING_SNAKE_CASE
const int MAX_SCORE = 200;

// Private members: _camelCase
String _privateField;
```

### Структура файлов

```
lib/
├── features/
│   └── feature_name/
│       ├── data/
│       │   ├── models/          # Data Transfer Objects
│       │   ├── datasources/     # API, Database
│       │   └── repositories/    # Repository implementations
│       ├── domain/
│       │   ├── entities/        # Business objects
│       │   ├── repositories/    # Repository interfaces
│       │   └── usecases/        # Business logic
│       └── presentation/
│           ├── pages/           # Screen widgets
│           ├── widgets/         # Reusable UI components
│           └── providers/       # Riverpod providers
```

### Документация кода

```dart
/// Calculates ORT test score based on answers
///
/// Takes a list of [answers] and returns the total score
/// calculated according to official ORT scoring rules.
///
/// Returns a score between 0 and 200.
///
/// Example:
/// ```dart
/// final score = calculateScore(userAnswers);
/// print('Your score: $score');
/// ```
int calculateScore(List<Answer> answers) {
  // Implementation
}
```

### Widgets

```dart
// Предпочитайте Stateless widgets где возможно
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

// Используйте const constructors
const Text('Hello');
const SizedBox(height: 16);

// Извлекайте сложные виджеты в методы или отдельные классы
Widget _buildComplexWidget() {
  return Column(
    children: [
      // ...
    ],
  );
}
```

### State Management (Riverpod)

```dart
// Provider example
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.read(userRepositoryProvider));
});

// Consumer example
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);

    return userState.when(
      data: (user) => Text(user.name),
      loading: () => LoadingIndicator(),
      error: (error, stack) => ErrorView(message: error.toString()),
    );
  }
}
```

## 📦 Структура коммитов

Используйте [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: Новая функциональность
- **fix**: Исправление бага
- **docs**: Изменения в документации
- **style**: Форматирование кода (не влияет на логику)
- **refactor**: Рефакторинг кода
- **test**: Добавление тестов
- **chore**: Обновление зависимостей, конфигурации

### Примеры

```bash
feat(auth): add phone OTP authentication

Implemented SMS OTP login flow using Firebase Auth.
Users can now sign in using their phone number.

Closes #123

---

fix(quiz): correct timer countdown bug

Timer was not pausing when app went to background.
Fixed by listening to app lifecycle changes.

Fixes #456

---

docs(readme): update installation instructions

Added steps for Firebase setup and
troubleshooting common issues.

---

refactor(dashboard): extract stats card to separate widget

Improved code reusability and maintainability
by creating StatsCard widget.
```

## 🔍 Pull Request процесс

### PR Template

```markdown
## Описание
Краткое описание изменений

## Тип изменения
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Чеклист
- [ ] Код следует стандартам проекта
- [ ] Добавлены unit тесты
- [ ] Все тесты проходят
- [ ] Обновлена документация
- [ ] Не осталось console.log / print
- [ ] Нет конфликтов с main веткой

## Скриншоты (если применимо)
Добавьте скриншоты UI изменений

## Связанные Issue
Closes #123
Related to #456
```

### Code Review

Ваш PR будет проверен на:
- ✅ Соответствие стандартам кода
- ✅ Наличие тестов
- ✅ Производительность
- ✅ Безопасность
- ✅ Доступность (a11y)
- ✅ Локализация

### После одобрения

1. Ваш PR будет смерджен в main
2. Изменения появятся в следующем релизе
3. Вас добавят в Contributors

## 🧪 Тестирование

### Unit тесты

```dart
// test/features/auth/auth_service_test.dart
void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('should sign in with valid credentials', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';

      // Act
      final result = await authService.signIn(email, password);

      // Assert
      expect(result.isRight(), true);
    });

    test('should return error with invalid credentials', () async {
      // Arrange
      const email = 'wrong@example.com';
      const password = 'wrongpass';

      // Act
      final result = await authService.signIn(email, password);

      // Assert
      expect(result.isLeft(), true);
    });
  });
}
```

### Widget тесты

```dart
// test/features/auth/login_page_test.dart
void main() {
  testWidgets('LoginPage should show email and password fields',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
```

### Integration тесты

```dart
// integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete login flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Navigate to login
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Enter credentials
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password_field')),
      'password123',
    );

    // Submit
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Verify dashboard
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
```

## 🐛 Reporting Bugs

Создайте Issue с:
- Описанием бага
- Шагами для воспроизведения
- Ожидаемым поведением
- Фактическим поведением
- Скриншотами/видео
- Версией приложения
- ОС и версией

## 💡 Feature Requests

Создайте Issue с:
- Описанием функциональности
- Use case / сценарий использования
- Почему это важно
- Возможные альтернативы

## 📞 Связь

- **Issues**: Для багов и feature requests
- **Discussions**: Для вопросов и обсуждений
- **Email**: dev@ortmaster.kg
- **Telegram**: @ortmaster_dev

## 🙏 Спасибо!

Каждый вклад ценен! Вместе мы создаем лучшее приложение для подготовки к ОРТ.

---

**Happy Coding! 🚀**
