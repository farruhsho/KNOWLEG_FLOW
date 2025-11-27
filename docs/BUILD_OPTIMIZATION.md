# Build Optimization Guide

## Android Optimization

### ProGuard/R8 Configuration
Уже включено в `android/app/build.gradle`:
```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

### Split APKs
Добавьте в `android/app/build.gradle`:
```gradle
android {
    splits {
        abi {
            enable true
            reset()
            include 'armeabi-v7a', 'arm64-v8a', 'x86_64'
            universalApk false
        }
    }
}
```

### App Bundle
Используйте App Bundle вместо APK:
```bash
flutter build appbundle --release
```

## iOS Optimization

### Bitcode (если требуется)
В `ios/Podfile`:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
```

### Strip Debug Symbols
Уже включено в release build

## Image Optimization

### WebP Conversion
Конвертируйте PNG/JPG в WebP:
```bash
# Установите cwebp
# Конвертация
cwebp input.png -q 80 -o output.webp
```

### Оптимизация размера
- Используйте векторные иконы (SVG/Font)
- Сжимайте изображения перед добавлением
- Используйте разные разрешения для разных экранов

## Dependency Optimization

### Анализ зависимостей
```bash
flutter pub deps --style=compact
```

### Удаление неиспользуемых
Проверьте `pubspec.yaml` и удалите неиспользуемые пакеты

## Bundle Size Analysis

### Анализ размера
```bash
# Android
flutter build apk --analyze-size

# iOS
flutter build ios --analyze-size
```

### Целевые размеры
- **Android APK**: < 30 MB
- **iOS IPA**: < 40 MB
- **Total**: < 50 MB (с учетом split APKs)

## Performance Tips

1. **Lazy Loading**:
   - Используйте `LazyImage` для изображений
   - Используйте `ListView.builder` вместо `ListView`

2. **Кэширование**:
   - Кэшируйте часто используемые данные
   - Используйте `MemoryOptimizer` для управления кэшем

3. **Анимации**:
   - Используйте `PerformanceUtils.shouldUseAnimations()`
   - Адаптируйте длительность анимаций под устройство

4. **Рендеринг**:
   - Используйте `const` конструкторы где возможно
   - Избегайте пересборки виджетов без необходимости
   - Используйте `RepaintBoundary` для сложных виджетов

## Monitoring

### Performance Overlay
```dart
MaterialApp(
  showPerformanceOverlay: true, // Только для debug
)
```

### Memory Profiling
Используйте DevTools для мониторинга памяти

## Checklist

- [ ] Включен ProGuard/R8 для Android
- [ ] Настроены split APKs
- [ ] Оптимизированы изображения (WebP)
- [ ] Удалены неиспользуемые зависимости
- [ ] Используется lazy loading
- [ ] Настроено кэширование
- [ ] Проверен размер bundle (< 50 MB)
- [ ] Протестировано на low-end устройствах
