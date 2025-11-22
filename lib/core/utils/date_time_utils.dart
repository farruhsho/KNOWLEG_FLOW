import 'package:intl/intl.dart';

class DateTimeUtils {
  // Format date to readable string
  static String formatDate(DateTime date, {String? locale}) {
    return DateFormat('dd MMMM yyyy', locale).format(date);
  }

  // Format time
  static String formatTime(DateTime date, {String? locale}) {
    return DateFormat('HH:mm', locale).format(date);
  }

  // Format date and time
  static String formatDateTime(DateTime date, {String? locale}) {
    return DateFormat('dd MMMM yyyy, HH:mm', locale).format(date);
  }

  // Format duration (e.g., "1h 30m")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else if (minutes > 0) {
      return '${minutes}м ${seconds}с';
    } else {
      return '${seconds}с';
    }
  }

  // Format timer (e.g., "01:30:45")
  static String formatTimer(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  // Time ago (e.g., "5 minutes ago")
  static String timeAgo(DateTime date, {String? locale}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${_pluralizeMinutes(minutes)} назад';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${_pluralizeHours(hours)} назад';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${_pluralizeDays(days)} назад';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${_pluralizeWeeks(weeks)} назад';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${_pluralizeMonths(months)} назад';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${_pluralizeYears(years)} назад';
    }
  }

  // Calculate days until
  static int daysUntil(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    return difference.inDays;
  }

  // Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  // Helper methods for Russian pluralization
  static String _pluralizeMinutes(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'минута';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'минуты';
    }
    return 'минут';
  }

  static String _pluralizeHours(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'час';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'часа';
    }
    return 'часов';
  }

  static String _pluralizeDays(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'день';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'дня';
    }
    return 'дней';
  }

  static String _pluralizeWeeks(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'неделя';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'недели';
    }
    return 'недель';
  }

  static String _pluralizeMonths(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'месяц';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'месяца';
    }
    return 'месяцев';
  }

  static String _pluralizeYears(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'год';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'года';
    }
    return 'лет';
  }
}
