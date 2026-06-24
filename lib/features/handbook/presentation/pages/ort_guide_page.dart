import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class OrtGuidePage extends StatelessWidget {
  const OrtGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Руководство по ОРТ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionCard(
            title: '🎯 Что такое ОРТ?',
            content: '''Общереспубликанское тестирование (ОРТ) - это стандартизированный экзамен для поступления в высшие учебные заведения Кыргызской Республики.

ОРТ проводится Центром оценки в образовании и методов обучения (ЦОиМО) два раза в год.

Цель ОРТ - объективная оценка знаний абитуриентов и справедливый отбор в ВУЗы.''',
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '📊 Структура теста',
            content: '''ОРТ состоит из 4 обязательных разделов:

1️⃣ МАТЕМАТИКА
• 30 вопросов
• 60 минут
• Алгебра, геометрия, задачи

2️⃣ РУССКИЙ ЯЗЫК
• 30 вопросов
• 50 минут
• Орфография, пунктуация, текст

3️⃣ КЫРГЫЗСКИЙ/АНГЛИЙСКИЙ (на выбор)
• 30 вопросов
• 50 минут
• Грамматика, лексика, текст

4️⃣ ИСТОРИЯ КЫРГЫЗСТАНА
• 30 вопросов
• 40 минут
• От древности до современности

ИТОГО: 120 вопросов, 200 минут (3 часа 20 минут)''',
            color: AppColors.mathColor,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '🎯 Система оценивания',
            content: '''Каждый правильный ответ = 1 балл

✅ Правильный ответ: +1 балл
❌ Неправильный ответ: 0 баллов
⚪ Пропущенный вопрос: 0 баллов

МАКСИМАЛЬНЫЙ БАЛЛ: 120

ПРОХОДНЫЕ БАЛЛЫ (примерно):
• Топ ВУЗы: 100-110+ баллов
• Средние ВУЗы: 80-100 баллов
• Минимум: 70 баллов

⚠️ Проходной балл меняется каждый год в зависимости от конкурса!''',
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '📅 Сроки и регистрация',
            content: '''ОСНОВНОЕ ТЕСТИРОВАНИЕ:
• Регистрация: Апрель-Май
• Тестирование: Июнь

ДОПОЛНИТЕЛЬНОЕ ТЕСТИРОВАНИЕ:
• Регистрация: Июнь-Июль
• Тестирование: Июль-Август

КАК ЗАРЕГИСТРИРОВАТЬСЯ:
1. Зайти на testing.kg
2. Создать личный кабинет
3. Заполнить анкету
4. Оплатить взнос (~500-700 сом)
5. Выбрать предметы и ВУЗы

ВАЖНО: Следите за объявлениями на testing.kg!''',
            color: AppColors.info,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '💡 Советы по подготовке',
            content: '''1️⃣ НАЧНИТЕ ЗАРАНЕЕ
• Идеально: за 12 месяцев
• Минимум: за 6 месяцев
• Не откладывайте!

2️⃣ СОСТАВЬТЕ ПЛАН
• Определите слабые темы
• Распределите время
• Следуйте графику

3️⃣ РЕШАЙТЕ ТЕСТЫ
• Минимум 3-4 теста в неделю
• Разбирайте ошибки
• Запоминайте формулы

4️⃣ ИСПОЛЬЗУЙТЕ РЕСУРСЫ
• YouTube: SEKOM, TSOOM, SOMO
• Сайты: testing.kg, ortest.online
• Книги: Методички SEKOM
• Приложения: ORT Master KG

5️⃣ ПОВТОРЯЙТЕ МАТЕРИАЛ
• Математика: формулы каждый день
• Русский: правила 3 раза в неделю
• История: даты регулярно

6️⃣ ПРОБНЫЕ ТЕСТЫ
• Решайте в условиях времени
• Анализируйте результаты
• Работайте над ошибками

7️⃣ НЕ ЗАБЫВАЙТЕ О ЗДОРОВЬЕ
• Спите 7-8 часов
• Делайте перерывы
• Занимайтесь спортом''',
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '📚 Рекомендуемые материалы',
            content: '''📺 YOUTUBE КАНАЛЫ:
• SEKOM - лучшие разборы по математике
• TSOOM - все предметы ОРТ
• SOMO - пробные тесты с решениями
• ORT KG - официальный канал

🌐 ВЕБ-САЙТЫ:
• testing.kg - официальный сайт ЦОиМО
• ortest.online - онлайн тесты
• ort.kg - база вопросов

📖 КНИГИ:
• Методички SEKOM (математика)
• Пособия SOMO (все предметы)
• Сборники ОРТ прошлых лет

📱 ПРИЛОЖЕНИЯ:
• ORT Master KG (это приложение!)
• ORT Test
• Matemat

💯 КУРСЫ:
• SEKOM (офлайн/онлайн)
• SOMO (офлайн)
• Частные репетиторы''',
            color: AppColors.accent,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '⚠️ Важные правила в день ОРТ',
            content: '''✅ ОБЯЗАТЕЛЬНО ВЗЯТЬ:
• Паспорт / ID карта
• Талон ОРТ (распечатанный)
• Ручка (черная/синяя)
• Запасная ручка

❌ ЗАПРЕЩЕНО:
• Телефоны и гаджеты
• Калькуляторы
• Шпаргалки
• Книги и тетради
• Разговоры во время теста

⏰ ПРИБЫТИЕ:
• Приезжайте за 30-40 минут
• Найдите свою аудиторию
• Успокойтесь перед началом

✍️ ВО ВРЕМЯ ТЕСТА:
• Читайте вопросы внимательно
• Начните с легких вопросов
• Следите за временем
• Не зацикливайтесь на одном вопросе
• Обязательно заполните ВСЕ ответы

🎯 СТРАТЕГИЯ:
1. Просмотрите весь тест (1-2 мин)
2. Решите легкие вопросы (30 мин)
3. Решите средние вопросы (20 мин)
4. Попробуйте сложные (5-7 мин)
5. Заполните оставшиеся наугад (2-3 мин)

⚡ ПОМНИТЕ:
Угадывание не отнимает баллы!
Лучше ответить наугад, чем оставить пустым!''',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
