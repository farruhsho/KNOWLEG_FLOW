# ORT Master KG - App Store Preparation Guide

## iOS App Store Requirements

### 1. Privacy Manifest (PrivacyInfo.xcprivacy)

Создайте файл `ios/Runner/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeName</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### 2. App Transport Security (ATS)

В `ios/Runner/Info.plist` уже должно быть:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

### 3. App Icons (1024x1024)

Создайте иконку 1024x1024 px:
- Формат: PNG
- Без прозрачности
- Без скругленных углов (iOS сделает автоматически)

Поместите в: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### 4. Screenshots

Требуемые размеры для App Store:
- **iPhone 6.7"**: 1290 x 2796 px (iPhone 15 Pro Max)
- **iPhone 6.5"**: 1242 x 2688 px (iPhone 11 Pro Max)
- **iPhone 5.5"**: 1242 x 2208 px (iPhone 8 Plus)
- **iPad Pro 12.9"**: 2048 x 2732 px

Минимум 3 скриншота, максимум 10.

### 5. App Description (Русский)

**Название**: ORT Master KG - Подготовка к ОРТ

**Подзаголовок**: Эффективная подготовка к Общереспубликанскому Тестированию

**Описание**:
```
ORT Master KG - ваш персональный помощник для подготовки к Общереспубликанскому Тестированию в Кыргызстане.

🎯 ОСНОВНЫЕ ВОЗМОЖНОСТИ:

📚 Обширная База Вопросов
• Тысячи вопросов по всем предметам ОРТ
• Математика, логика, грамматика, чтение
• Регулярные обновления контента

📊 Умная Аналитика
• Отслеживание прогресса в реальном времени
• AI прогноз вашего балла ОРТ
• Анализ слабых мест
• Персональные рекомендации

🎮 Геймификация
• Система уровней и достижений
• Ежедневные миссии
• Стрики и награды
• Соревнуйтесь с друзьями

📖 Справочник
• Формулы по математике
• Правила грамматики
• Логические приемы
• Стратегии чтения

🌐 Многоязычность
• Русский интерфейс
• Кыргызский интерфейс
• Английский интерфейс

📱 Оффлайн Режим
• Работает без интернета
• Автоматическая синхронизация
• Экономия трафика

✨ ПОЧЕМУ ORT MASTER KG?

• Соответствие формату ОРТ
• Современный дизайн
• Быстрая работа
• Регулярные обновления
• Бесплатные базовые функции

Начните подготовку к ОРТ уже сегодня!
```

**Ключевые слова**: ОРТ, тест, подготовка, Кыргызстан, экзамен, образование, обучение, математика

**Категория**: Образование

**Возрастной рейтинг**: 4+

---

## Android Play Market Requirements

### 1. Permissions (AndroidManifest.xml)

В `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### 2. Privacy Policy URL

Создайте Privacy Policy и разместите на:
- Firebase Hosting
- GitHub Pages
- Собственный сайт

Пример URL: `https://ortmaster.kg/privacy-policy`

### 3. Feature Graphic (1024 x 500)

Создайте горизонтальный баннер:
- Размер: 1024 x 500 px
- Формат: PNG или JPEG
- Без прозрачности

### 4. App Icons

Размеры для Android:
- **512 x 512 px**: Высокое разрешение (для Play Store)
- **192 x 192 px**: xxxhdpi
- **144 x 144 px**: xxhdpi
- **96 x 96 px**: xhdpi
- **72 x 72 px**: hdpi
- **48 x 48 px**: mdpi

### 5. Screenshots

Требования:
- Минимум 2, максимум 8
- Формат: PNG или JPEG
- Размеры: 
  - Телефон: 1080 x 1920 px (минимум)
  - Планшет: 1200 x 1920 px (минимум)

### 6. Play Store Description (Русский)

**Краткое описание** (80 символов):
```
Подготовка к ОРТ: тесты, аналитика, AI прогноз. Работает оффлайн!
```

**Полное описание**:
```
🎓 ORT MASTER KG - ТВОЙ ПУТЬ К УСПЕХУ НА ОРТ!

Готовься к Общереспубликанскому Тестированию эффективно с ORT Master KG - самым современным приложением для подготовки к ОРТ в Кыргызстане.

━━━━━━━━━━━━━━━━━━━━━━
📚 ЧТО ВНУТРИ?
━━━━━━━━━━━━━━━━━━━━━━

✅ ТЫСЯЧИ ВОПРОСОВ
• Все предметы ОРТ
• Математика и логика
• Грамматика и чтение
• Регулярные обновления

✅ УМНАЯ АНАЛИТИКА
• График прогресса
• AI прогноз балла
• Анализ ошибок
• Персональные советы

✅ ГЕЙМИФИКАЦИЯ
• Уровни и достижения
• Ежедневные миссии
• Система стриков
• Награды за прогресс

✅ СПРАВОЧНИК
• Математические формулы
• Правила грамматики
• Логические приемы
• Стратегии решения

✅ ОФФЛАЙН РЕЖИМ
• Работает без интернета
• Автосинхронизация
• Экономия трафика

✅ МНОГОЯЗЫЧНОСТЬ
• Русский
• Кыргызский
• Английский

━━━━━━━━━━━━━━━━━━━━━━
🎯 ПРЕИМУЩЕСТВА
━━━━━━━━━━━━━━━━━━━━━━

🔹 Соответствие формату ОРТ
🔹 Современный дизайн
🔹 Быстрая работа
🔹 Регулярные обновления
🔹 Бесплатные функции

━━━━━━━━━━━━━━━━━━━━━━
📱 НАЧНИ СЕЙЧАС!
━━━━━━━━━━━━━━━━━━━━━━

Скачай ORT Master KG и начни подготовку к ОРТ уже сегодня!

#ОРТ #Образование #Кыргызстан #Подготовка #Тесты
```

**Категория**: Образование

**Возрастной рейтинг**: Для всех

---

## Assets Checklist

### iOS
- [ ] App Icon 1024x1024
- [ ] Screenshots (6.7", 6.5", 5.5")
- [ ] iPad Screenshots (12.9")
- [ ] Privacy Manifest
- [ ] App Description
- [ ] Keywords

### Android
- [ ] App Icon 512x512
- [ ] Feature Graphic 1024x500
- [ ] Screenshots (phone, tablet)
- [ ] Privacy Policy URL
- [ ] App Description
- [ ] Promotional text

---

## Privacy Policy Template

```markdown
# Privacy Policy for ORT Master KG

Last updated: [DATE]

## Information We Collect

- Email address (for account creation)
- Name (for personalization)
- Test results and progress data
- Device information (for analytics)

## How We Use Information

- Provide app functionality
- Track learning progress
- Improve user experience
- Send notifications about updates

## Data Storage

- Data stored in Firebase Firestore
- Encrypted in transit and at rest
- Automatic backups

## Third-Party Services

- Firebase (Google)
- Analytics services

## Your Rights

- Access your data
- Delete your account
- Export your data

## Contact

Email: support@ortmaster.kg
```

---

## Submission Checklist

### Before Submission
- [ ] Test on real devices
- [ ] All features working
- [ ] No crashes
- [ ] Privacy Policy published
- [ ] All assets prepared
- [ ] Descriptions written
- [ ] Screenshots captured
- [ ] Icons generated

### iOS Submission
- [ ] Xcode archive created
- [ ] App uploaded to App Store Connect
- [ ] Metadata filled
- [ ] Screenshots uploaded
- [ ] Privacy info completed
- [ ] Submitted for review

### Android Submission
- [ ] Signed APK/AAB created
- [ ] App uploaded to Play Console
- [ ] Metadata filled
- [ ] Screenshots uploaded
- [ ] Privacy policy linked
- [ ] Submitted for review
