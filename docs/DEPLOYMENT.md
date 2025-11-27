# ORT Master KG - Руководство по Развертыванию

## Предварительные Требования

### Установленное ПО
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio / Xcode
- Firebase CLI
- Git

### Учетные Записи
- Firebase проект
- Google Play Console (для Android)
- Apple Developer Account (для iOS)

## Настройка Проекта

### 1. Клонирование Репозитория
```bash
git clone <repository-url>
cd knowledge_flow
```

### 2. Установка Зависимостей
```bash
flutter pub get
```

### 3. Настройка Firebase

#### Android
1. Скачайте `google-services.json` из Firebase Console
2. Поместите в `android/app/`

#### iOS
1. Скачайте `GoogleService-Info.plist` из Firebase Console
2. Поместите в `ios/Runner/`

### 4. Настройка Переменных Окружения

Создайте `.env` файл:
```env
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
```

## Сборка Приложения

### Development Build
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios
```

### Release Build

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle (рекомендуется)
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

## Firestore Настройка

### Коллекции
Создайте следующие коллекции в Firestore:
- `users` - Пользователи
- `admins` - Администраторы
- `questions` - Вопросы
- `subjects` - Предметы
- `lessons` - Уроки
- `missions` - Миссии
- `user_progress` - Прогресс пользователей
- `user_gamification` - Геймификация

### Индексы
Создайте составные индексы:
```
users: email (ASC), createdAt (DESC)
questions: subjectId (ASC), difficulty (ASC)
user_progress: userId (ASC), lastUpdated (DESC)
```

### Правила Безопасности
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Admins
    match /admins/{adminId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'superadmin';
    }
    
    // Questions (read-only for users)
    match /questions/{questionId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.permissions.hasAny(['manage_questions']);
    }
    
    // User Progress
    match /user_progress/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

## Инициализация Данных

### Создание Первого Администратора
```dart
// Выполните в Firebase Console или через скрипт
{
  "email": "admin@ort.kg",
  "name": "Super Admin",
  "role": "superadmin",
  "permissions": [
    "manage_users",
    "manage_questions",
    "manage_missions",
    "manage_lessons",
    "manage_subjects",
    "use_ai_generator",
    "view_analytics",
    "manage_admins",
    "delete_content"
  ],
  "created_at": Timestamp.now(),
  "is_active": true
}
```

### Загрузка Тестовых Данных
```bash
# Используйте Firebase CLI
firebase firestore:import test_data/
```

## Тестирование

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Анализ Кода
```bash
flutter analyze
```

## Развертывание

### Firebase Hosting (Web)
```bash
flutter build web --release
firebase deploy --only hosting
```

### Google Play Store
1. Создайте подписанный App Bundle
2. Загрузите в Play Console
3. Заполните метаданные приложения
4. Отправьте на проверку

### Apple App Store
1. Создайте архив в Xcode
2. Загрузите через App Store Connect
3. Заполните метаданные приложения
4. Отправьте на проверку

## Мониторинг

### Firebase Analytics
Уже настроен в приложении

### Crashlytics
```bash
flutter pub add firebase_crashlytics
```

### Performance Monitoring
```bash
flutter pub add firebase_performance
```

## Обслуживание

### Обновление Зависимостей
```bash
flutter pub upgrade
```

### Миграция Данных
Используйте Cloud Functions для миграции данных при обновлениях схемы

### Резервное Копирование
Настройте автоматическое резервное копирование Firestore

## Поддержка

### Логи
Проверяйте логи в Firebase Console

### Обратная Связь
Настройте форму обратной связи в приложении

## Чек-лист Развертывания

- [ ] Firebase проект настроен
- [ ] Firestore коллекции созданы
- [ ] Правила безопасности настроены
- [ ] Первый администратор создан
- [ ] Тестовые данные загружены
- [ ] Release build успешно собран
- [ ] Тестирование пройдено
- [ ] Метаданные приложения заполнены
- [ ] Скриншоты подготовлены
- [ ] Privacy Policy опубликована
- [ ] Приложение отправлено на проверку
