# Phase 9: Sample Tests & Deep Search - Legal & Technical Guide

## ⚠️ ВАЖНОЕ ЮРИДИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ

**КРИТИЧЕСКИ ВАЖНО**: Веб-скрапинг может нарушать:
- Условия использования сайтов
- Авторские права
- Законы о защите данных
- Законы о компьютерных преступлениях

**ПЕРЕД РЕАЛИЗАЦИЕЙ ОБЯЗАТЕЛЬНО**:
1. ✅ Получите письменное разрешение от владельцев сайтов
2. ✅ Проконсультируйтесь с юристом
3. ✅ Проверьте robots.txt каждого сайта
4. ✅ Соблюдайте Terms of Service
5. ✅ Добавьте атрибуцию источников

---

## 🚫 Рекомендация: НЕ ИСПОЛЬЗОВАТЬ ВЕБ-СКРАПИНГ

### Альтернативные Подходы (Рекомендуется)

#### 1. Партнерство с Контент-Провайдерами
- Свяжитесь с testing.kg, ortest.online, ed.kyrg.info
- Запросите официальное API или лицензию
- Заключите соглашение о сотрудничестве

#### 2. Создание Собственного Контента
- Наймите преподавателей для создания вопросов
- Используйте существующую админ панель
- Обеспечьте качество и уникальность

#### 3. Краудсорсинг
- Позвольте пользователям добавлять вопросы
- Модерация через админ панель
- Система рейтингов и проверки

---

## 📋 Техническая Реализация (Только для Легального Контента)

### Если у вас ЕСТЬ разрешение, вот структура:

### 1. Web Scraping Service (ТОЛЬКО С РАЗРЕШЕНИЕМ)

```dart
/// ⚠️ ИСПОЛЬЗОВАТЬ ТОЛЬКО С ПИСЬМЕННЫМ РАЗРЕШЕНИЕМ
class WebScrapingService {
  // НЕ РЕАЛИЗОВАНО - ТРЕБУЕТСЯ ЮРИДИЧЕСКОЕ РАЗРЕШЕНИЕ
  
  /// Проверка robots.txt перед скрапингом
  Future<bool> isScrapingAllowed(String url) async {
    // Проверить robots.txt
    // Проверить rate limits
    // Проверить Terms of Service
    throw UnimplementedError('Требуется юридическое разрешение');
  }
  
  /// Скрапинг с соблюдением этики
  Future<void> scrapeWithPermission({
    required String url,
    required String permissionDocument,
  }) async {
    throw UnimplementedError('Требуется юридическое разрешение');
  }
}
```

### 2. Legal Disclaimer UI

**Создайте файл**: `lib/shared/widgets/legal_disclaimer.dart`

```dart
import 'package:flutter/material.dart';

class LegalDisclaimer extends StatelessWidget {
  final String source;
  final String licenseInfo;

  const LegalDisclaimer({
    super.key,
    required this.source,
    required this.licenseInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Источник контента',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Источник: $source'),
          Text('Лицензия: $licenseInfo'),
          const SizedBox(height: 8),
          const Text(
            'Весь контент используется с разрешения правообладателей.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
```

### 3. ORT Format Structure

```dart
class ORTTest {
  final String id;
  final String title;
  final List<ORTQuestion> questions; // Должно быть 30
  final Duration duration; // 90 минут
  final String source;
  final String license;
  
  const ORTTest({
    required this.id,
    required this.title,
    required this.questions,
    this.duration = const Duration(minutes: 90),
    required this.source,
    required this.license,
  });
  
  // Валидация формата ОРТ
  bool isValidORTFormat() {
    return questions.length == 30 && 
           duration.inMinutes == 90;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'questions': questions.map((q) => q.toJson()).toList(),
      'duration_minutes': duration.inMinutes,
      'source': source,
      'license': license,
      'format_version': '1.0',
    };
  }
}
```

---

## 🤖 ML Embeddings (Требует Backend)

### Duplicate Detection с ML

**ВАЖНО**: Требует Python backend или Cloud Functions

```python
# Cloud Function (Python)
from sentence_transformers import SentenceTransformer
import numpy as np

model = SentenceTransformer('all-MiniLM-L6-v2')

def detect_duplicates(question_text, existing_questions):
    """
    Обнаружение дубликатов с использованием embeddings
    """
    # Создать embedding для нового вопроса
    new_embedding = model.encode([question_text])[0]
    
    # Сравнить с существующими
    similarities = []
    for existing in existing_questions:
        existing_embedding = model.encode([existing['text']])[0]
        similarity = cosine_similarity(new_embedding, existing_embedding)
        similarities.append({
            'question_id': existing['id'],
            'similarity': similarity
        })
    
    # Фильтр по порогу 85%
    duplicates = [s for s in similarities if s['similarity'] > 0.85]
    
    return duplicates
```

### Альтернатива: Используйте TextSimilarityService

Мы уже реализовали `TextSimilarityService` в Фазе 6:
- Levenshtein Distance
- Jaccard Similarity  
- Cosine Similarity
- Комбинированный скор >85%

**Это работает БЕЗ ML backend!**

---

## 📝 Рекомендуемый План Действий

### Вместо Веб-Скрапинга:

1. **Создайте Контент Вручную**
   - Используйте админ панель
   - Наймите преподавателей
   - Обеспечьте качество

2. **Партнерство**
   - Свяжитесь с testing.kg
   - Запросите API доступ
   - Заключите соглашение

3. **Краудсорсинг**
   - Пользователи добавляют вопросы
   - Модерация через админку
   - Система рейтингов

4. **Используйте Существующие Инструменты**
   - TextSimilarityService для дубликатов
   - Админ панель для CRUD
   - Firebase для хранения

---

## ✅ Что УЖЕ Реализовано

1. ✅ **Duplicate Detection**: TextSimilarityService (>85%)
2. ✅ **Admin Panel**: CRUD для вопросов
3. ✅ **ORT Format**: QuestionModel поддерживает формат
4. ✅ **Timer**: Реализован в quiz_page.dart
5. ✅ **JSON Format**: Все модели имеют toJson/fromJson

---

## 🚨 Юридический Чек-лист

Если вы все же хотите использовать веб-скрапинг:

- [ ] Получено письменное разрешение от testing.kg
- [ ] Получено письменное разрешение от ortest.online
- [ ] Получено письменное разрешение от ed.kyrg.info
- [ ] Получено разрешение на YouTube контент
- [ ] Проконсультировались с юристом
- [ ] Проверили robots.txt всех сайтов
- [ ] Добавили атрибуцию источников
- [ ] Реализовали rate limiting
- [ ] Добавили User-Agent идентификацию
- [ ] Готовы к возможным юридическим последствиям

---

## 💡 Итоговая Рекомендация

**НЕ РЕАЛИЗОВЫВАЙТЕ ВЕБ-СКРАПИНГ** без юридических разрешений.

**ВМЕСТО ЭТОГО**:
1. Используйте существующую админ панель
2. Создавайте контент вручную
3. Ищите партнерства
4. Используйте уже реализованный TextSimilarityService

**Ваше приложение УЖЕ имеет все необходимые инструменты для работы с контентом легально и эффективно!**

---

*Документ создан: 27 ноября 2025*  
*Статус: Рекомендация - НЕ РЕАЛИЗОВЫВАТЬ без юридических разрешений*
