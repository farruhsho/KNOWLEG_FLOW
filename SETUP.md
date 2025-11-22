# Инструкция по настройке ORT Master KG

## 📋 Предварительные требования

Перед началом убедитесь, что у вас установлено:

- **Flutter SDK 3.9.2+** ([Установить Flutter](https://flutter.dev/docs/get-started/install))
- **Dart SDK 3.0+** (входит в состав Flutter)
- **Git** ([Установить Git](https://git-scm.com/downloads))
- **Android Studio** или **Xcode** (для iOS)
- **VS Code** или **Android Studio** с плагинами Flutter/Dart

## 🚀 Быстрый старт (без Firebase)

Если вы хотите просто запустить приложение без подключения к Firebase:

```bash
# 1. Клонировать репозиторий
git clone https://github.com/farruhsho/KNOWLEG_FLOW.git
cd KNOWLEG_FLOW

# 2. Переключиться на ветку разработки
git checkout claude/ort-exam-app-01FyxZ2mpUZLeXCHNqSfvniR

# 3. Установить зависимости
flutter pub get

# 4. Запустить приложение (без Firebase функционала)
flutter run
```

**Примечание:** Без Firebase не будут работать:
- Аутентификация
- Синхронизация данных
- Push-уведомления
- Аналитика

## 🔥 Полная настройка с Firebase

### Шаг 1: Создание Firebase проекта

1. Перейдите на [Firebase Console](https://console.firebase.google.com)
2. Нажмите **Add project** / **Создать проект**
3. Введите название: `ort-master-kg` (или любое другое)
4. Отключите Google Analytics (можно включить позже)
5. Нажмите **Create project**

### Шаг 2: Добавление приложений

#### Android приложение

1. В Firebase Console выберите проект
2. Нажмите на иконку Android
3. Введите **Android package name**: `kg.ortmaster.app`
4. Введите **App nickname**: `ORT Master KG Android`
5. Пропустите SHA-1 (не обязательно для разработки)
6. Нажмите **Register app**
7. **Скачайте `google-services.json`**
8. Поместите файл в: `android/app/google-services.json`

```bash
# Проверьте, что файл на месте
ls android/app/google-services.json
```

#### iOS приложение

1. Нажмите на иконку iOS
2. Введите **iOS bundle ID**: `kg.ortmaster.app`
3. Введите **App nickname**: `ORT Master KG iOS`
4. Пропустите App Store ID
5. Нажмите **Register app**
6. **Скачайте `GoogleService-Info.plist`**
7. Откройте проект в Xcode: `open ios/Runner.xcworkspace`
8. Перетащите файл в папку `Runner` в Xcode
9. Убедитесь, что выбрано **Copy items if needed**

### Шаг 3: Настройка Firebase сервисов

#### 3.1 Authentication (Аутентификация)

1. В Firebase Console → **Authentication**
2. Нажмите **Get started**
3. Включите провайдеры:
   - **Email/Password** ✅
   - **Google** ✅ (потребуется настроить OAuth consent screen)
   - **Phone** ✅ (для SMS OTP)

**Для Google Sign-In:**
- Скачайте Web client ID
- Настройте OAuth consent screen в Google Cloud Console
- Добавьте SHA-1 fingerprint для Android

```bash
# Получить SHA-1 для debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### 3.2 Cloud Firestore (База данных)

1. В Firebase Console → **Firestore Database**
2. Нажмите **Create database**
3. Выберите **Start in test mode** (для разработки)
4. Выберите регион: `us-central` или ближайший
5. Нажмите **Enable**

**Создайте коллекции:**
```
- users/
- subjects/
- lessons/
- questions/
- mock_tests/
- user_attempts/
- payments/
- flashcards/
```

**Настройте индексы (firestore.indexes.json):**
```json
{
  "indexes": [
    {
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject_id", "order": "ASCENDING" },
        { "fieldPath": "difficulty", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "user_attempts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "uid", "order": "ASCENDING" },
        { "fieldPath": "finished_at", "order": "DESCENDING" }
      ]
    }
  ]
}
```

#### 3.3 Cloud Storage (Хранилище файлов)

1. В Firebase Console → **Storage**
2. Нажмите **Get started**
3. Выберите **Start in test mode**
4. Нажмите **Done**

**Создайте структуру папок:**
```
- /lessons/images/
- /lessons/videos/
- /questions/images/
- /flashcards/images/
- /user_avatars/
```

#### 3.4 Cloud Functions (Серверная логика)

```bash
# Установить Firebase CLI
npm install -g firebase-tools

# Войти в Firebase
firebase login

# Инициализировать Functions
cd KNOWLEG_FLOW
firebase init functions

# Выбрать TypeScript
# Установить зависимости
```

**Создать функцию для scoring:**
```typescript
// functions/src/index.ts
export const scoreAttempt = functions.firestore
  .document('user_attempts/{attemptId}')
  .onCreate(async (snap, context) => {
    const attempt = snap.data();
    // Логика подсчета баллов
    const score = calculateScore(attempt.answers);
    await snap.ref.update({ score });
  });
```

#### 3.5 Remote Config (Удаленная конфигурация)

1. В Firebase Console → **Remote Config**
2. Добавьте параметры:

| Ключ | Значение по умолчанию | Тип |
|------|----------------------|-----|
| `next_ort_date` | "Июль 2025" | String |
| `registration_url` | "https://testing.kg" | String |
| `practice_tests_url` | "https://ort.kg" | String |
| `show_announcement` | false | Boolean |
| `announcement_text` | "" | String |

#### 3.6 Cloud Messaging (Push-уведомления)

1. В Firebase Console → **Cloud Messaging**
2. Скачайте **Server key** для FCM
3. Настройте APNs ключ для iOS

### Шаг 4: Обновление Firebase Options

Запустите FlutterFire CLI для автоматической генерации:

```bash
# Установить FlutterFire CLI
flutter pub global activate flutterfire_cli

# Настроить Firebase
flutterfire configure
```

Это автоматически обновит `lib/firebase_options.dart` с правильными ключами.

### Шаг 5: Запуск приложения

```bash
# Установить зависимости
flutter pub get

# Запустить на Android
flutter run

# Или на iOS
flutter run -d ios

# Или на конкретном устройстве
flutter devices
flutter run -d <device-id>
```

## 🧪 Тестирование

### Unit тесты
```bash
flutter test
```

### Integration тесты
```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
```

### Локальная разработка с Firebase Emulator

```bash
# Установить Firebase Emulator
firebase init emulators

# Выбрать: Authentication, Firestore, Functions, Storage

# Запустить эмулятор
firebase emulators:start

# В приложении использовать localhost
# (см. lib/core/network/firebase_service.dart)
```

## 📊 Наполнение тестовыми данными

### Создать тестовые предметы

```javascript
// В Firebase Console → Firestore → Add document

// subjects/math
{
  "title": {
    "ru": "Математика",
    "ky": "Математика",
    "en": "Mathematics"
  },
  "description": {
    "ru": "Основы математики для ОРТ",
    "ky": "ОРТ үчүн математиканын негиздери",
    "en": "Mathematics basics for ORT"
  },
  "icon": "📐",
  "color": "#8B5CF6",
  "total_lessons": 0,
  "total_questions": 0
}
```

### Создать тестовые вопросы

```javascript
// questions/q001
{
  "subject_id": "math",
  "type": "mcq",
  "difficulty": 3,
  "stem": {
    "ru": "Сколько будет 2 + 2?",
    "ky": "2 + 2 канча болот?",
    "en": "What is 2 + 2?"
  },
  "options": [
    {
      "id": "A",
      "text": { "ru": "3", "ky": "3", "en": "3" }
    },
    {
      "id": "B",
      "text": { "ru": "4", "ky": "4", "en": "4" }
    },
    {
      "id": "C",
      "text": { "ru": "5", "ky": "5", "en": "5" }
    },
    {
      "id": "D",
      "text": { "ru": "6", "ky": "6", "en": "6" }
    }
  ],
  "correct": "B",
  "explanation": {
    "ru": "2 + 2 = 4",
    "ky": "2 + 2 = 4",
    "en": "2 + 2 = 4"
  },
  "tags": ["arithmetic", "basic"],
  "created_by": "admin",
  "created_at": "2025-01-01T00:00:00Z"
}
```

## 🔐 Настройка безопасности

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User documents
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }

    // Public read for subjects, lessons, questions
    match /subjects/{subjectId} {
      allow read: if true;
      allow write: if false; // Only via Cloud Functions
    }

    match /lessons/{lessonId} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /questions/{questionId} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // User attempts
    match /user_attempts/{attemptId} {
      allow read: if request.auth.uid == resource.data.uid;
      allow create: if request.auth.uid == request.resource.data.uid;
      allow update, delete: if false;
    }

    // Payments
    match /payments/{paymentId} {
      allow read: if request.auth.uid == resource.data.uid;
      allow create: if request.auth.uid == request.resource.data.uid;
      allow update, delete: if false;
    }
  }
}
```

### Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User avatars
    match /user_avatars/{userId}/{fileName} {
      allow read: if true;
      allow write: if request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }

    // Public media (lessons, questions)
    match /lessons/{allPaths=**} {
      allow read: if true;
      allow write: if false; // Only via Admin SDK
    }

    match /questions/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

## 🛠️ Устранение неполадок

### Проблема: Firebase не инициализируется

**Решение:**
1. Проверьте наличие файлов конфигурации
2. Убедитесь, что package name совпадает
3. Очистите кэш: `flutter clean && flutter pub get`
4. Пересоберите приложение

### Проблема: Google Sign-In не работает

**Решение:**
1. Добавьте SHA-1 fingerprint в Firebase
2. Обновите `google-services.json`
3. Настройте OAuth consent screen
4. Проверьте, что Web client ID правильный

### Проблема: Не приходят push-уведомления

**Решение:**
1. Проверьте разрешения в манифесте Android
2. Для iOS настройте APNs в Firebase
3. Запросите разрешения у пользователя
4. Проверьте FCM token в логах

## 📚 Дополнительные ресурсы

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev)
- [Firestore Data Modeling](https://firebase.google.com/docs/firestore/data-model)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)

## 💬 Поддержка

Если возникли проблемы:
1. Проверьте [Issues](https://github.com/farruhsho/KNOWLEG_FLOW/issues)
2. Создайте новый Issue с подробным описанием
3. Напишите в Telegram: @ortmaster_support

---

**Удачи в разработке! 🚀**
