class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Введите корректный email';
    }

    return null;
  }

  // Password validation
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }

    if (value.length < minLength) {
      return 'Пароль должен содержать минимум $minLength символов';
    }

    return null;
  }

  // Password confirmation validation
  static String? validatePasswordConfirmation(
    String? value,
    String? password,
  ) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите пароль';
    }

    if (value != password) {
      return 'Пароли не совпадают';
    }

    return null;
  }

  // Name validation
  static String? validateName(String? value, {int minLength = 2}) {
    if (value == null || value.isEmpty) {
      return 'Введите имя';
    }

    if (value.length < minLength) {
      return 'Имя должно содержать минимум $minLength символа';
    }

    return null;
  }

  // Phone validation (Kyrgyzstan format)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите номер телефона';
    }

    // Remove all non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    // Kyrgyzstan phone numbers: +996 XXX XXX XXX
    if (digitsOnly.length != 12 && !digitsOnly.startsWith('996')) {
      return 'Введите корректный номер телефона (+996 XXX XXX XXX)';
    }

    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return fieldName != null
          ? 'Введите $fieldName'
          : 'Это поле обязательно';
    }

    return null;
  }

  // Number validation
  static String? validateNumber(String? value, {int? min, int? max}) {
    if (value == null || value.isEmpty) {
      return 'Введите число';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return 'Введите корректное число';
    }

    if (min != null && number < min) {
      return 'Число должно быть больше или равно $min';
    }

    if (max != null && number > max) {
      return 'Число должно быть меньше или равно $max';
    }

    return null;
  }

  // Grade validation (9-11 or 0 for graduate)
  static String? validateGrade(int? value) {
    if (value == null) {
      return 'Выберите класс';
    }

    if (value != 0 && (value < 9 || value > 11)) {
      return 'Некорректный класс';
    }

    return null;
  }

  // URL validation
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Введите корректный URL';
    }

    return null;
  }

  // Test score validation (0-200 for ORT)
  static String? validateTestScore(int? value) {
    if (value == null) {
      return 'Введите балл';
    }

    if (value < 0 || value > 200) {
      return 'Балл должен быть от 0 до 200';
    }

    return null;
  }
}
