# ORT Master KG 🎓

**Comprehensive ORT exam preparation app for Kyrgyzstan students**

ORT Master KG is a Flutter-based mobile application designed to help students in Kyrgyzstan prepare for the ORT (General Republican Testing) exam. The app provides practice tests, mock exams, flashcards, and detailed analytics to maximize students' exam performance.

## 🌟 Features

### Free Features
- ✅ Diagnostic test to identify weak subjects
- ✅ Subject-based learning modules with lessons
- ✅ Short practice quizzes (10-20 questions)
- ✅ Flashcards with SRS (Spaced Repetition System)
- ✅ Progress tracking and analytics
- ✅ Heat map of weak topics
- ✅ Daily goals and streaks
- ✅ Offline lesson access
- ✅ Bilingual support (Kyrgyz/Russian/English)

### Premium Features
- 💰 Full ORT mock tests (130 questions, 195 minutes)
- 💰 Detailed test reports with score breakdown
- 💰 Unlimited practice quizzes
- 💰 Advanced analytics and recommendations
- 💰 Ad-free experience

## 🏗️ Tech Stack

### Frontend
- **Flutter 3.9+** - Cross-platform UI framework
- **Dart 3.0+** - Programming language
- **Riverpod** - State management
- **go_router** - Navigation
- **Hive** - Local storage
- **fl_chart** - Data visualization

### Backend (Firebase)
- **Firebase Auth** - Authentication (Email/Google/Phone)
- **Cloud Firestore** - NoSQL database
- **Firebase Storage** - Media files
- **Cloud Functions** - Server-side logic
- **Firebase Analytics** - User analytics
- **Crashlytics** - Crash reporting
- **Remote Config** - Feature flags
- **Cloud Messaging** - Push notifications

### Architecture
- **Clean Architecture** - Separation of concerns
- **MVVM Pattern** - Presentation layer
- **Repository Pattern** - Data layer
- **Dependency Injection** - GetIt

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/        # App constants
│   ├── errors/          # Error handling
│   ├── network/         # Firebase services
│   ├── routes/          # Navigation
│   ├── theme/           # App theme and colors
│   └── utils/           # Utility functions
├── features/
│   ├── auth/            # Authentication
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── dashboard/       # Home screen
│   ├── subjects/        # Subject management
│   ├── lessons/         # Lesson viewer
│   ├── quiz/            # Practice quizzes
│   ├── mock_test/       # Full mock tests
│   ├── flashcards/      # SRS flashcards
│   ├── profile/         # User profile
│   ├── analytics/       # Progress analytics
│   ├── payments/        # Payment integration
│   └── onboarding/      # First-time user flow
├── shared/
│   ├── models/          # Data models
│   └── widgets/         # Reusable widgets
└── main.dart
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.9.2 or higher
- Dart SDK 3.0 or higher
- Android Studio / VS Code
- Git
- Firebase account (for backend setup)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/KNOWLEG_FLOW.git
cd KNOWLEG_FLOW
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Firebase Setup**

Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

#### For Android:
- Download `google-services.json`
- Place it in `android/app/`

#### For iOS:
- Download `GoogleService-Info.plist`
- Place it in `ios/Runner/`

4. **Configure Firebase services**

Enable the following in Firebase Console:
- Authentication (Email/Password, Google, Phone)
- Cloud Firestore
- Storage
- Cloud Functions
- Analytics
- Crashlytics
- Remote Config
- Cloud Messaging

5. **Create Firestore indexes**

Run the Firebase CLI to deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

6. **Generate localization files**
```bash
flutter gen-l10n
```

7. **Run the app**
```bash
flutter run
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory (optional):
```
FIREBASE_API_KEY=your_api_key
PAYMENT_GATEWAY_URL=https://payment.example.com
```

### Remote Config Keys

Configure these in Firebase Remote Config:
- `next_ort_date` - Next ORT registration date
- `registration_url` - Testing.kg URL
- `practice_tests_url` - ORT.kg URL
- `show_announcement` - Boolean for announcements
- `announcement_text` - Announcement message

## 📱 Supported Platforms

- ✅ Android (API 21+)
- ✅ iOS (13.0+)
- 🚧 Web (Coming soon)

## 🌐 Localization

The app supports three languages:
- **Kyrgyz (ky)** - Кыргызча
- **Russian (ru)** - Русский (Default)
- **English (en)** - English

Translation files are located in `lib/l10n/`:
- `app_en.arb`
- `app_ru.arb`
- `app_ky.arb`

## 💳 Payment Integration

### MBank Integration

1. Contact MBank for merchant credentials
2. Configure payment webhook URL in Cloud Functions
3. Update payment settings in `lib/features/payments/`

### Pricing (KGS)
- Single mock test: 100 KGS
- 5 mock tests pack: 400 KGS
- Monthly subscription: 500 KGS

## 📊 ORT Test Structure

The app simulates the real ORT exam format:

### Section 1: Main Test (60 questions, 90 min)
- Verbal (30q): Analogies, sentence completion, reading comprehension
- Math (30q): Arithmetic, algebra, geometry, logic

### Section 2: Subject Test (40 questions, 60 min)
Choose one: Math, Physics, Chemistry, Biology, History, Geography

### Section 3: Language Test (30 questions, 45 min)
Choose one: Kyrgyz, Russian, English

**Total: 130 questions, 195 minutes, Max score: 200**

## 🧪 Testing

Run unit tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
```

## 📦 Building for Release

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Official Resources

- [Testing.kg](https://testing.kg) - Official ORT registration
- [ORT.kg](https://ort.kg) - Practice tests
- [ЦООМО](https://coomocenter.kg) - Center for Education Assessment

## 📧 Contact

For questions or support, contact:
- Email: support@ortmaster.kg
- Website: https://ortmaster.kg

## 🙏 Acknowledgments

- ЦООМО for ORT exam standards
- Flutter team for the amazing framework
- All contributors and beta testers

---

**Made with ❤️ for Kyrgyzstan students**
