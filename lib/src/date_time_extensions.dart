import 'package:flutter/foundation.dart';

extension DateTimeExtensions on DateTime {
  DateTime get startOfDay {
    return (isUtc ? DateTime.utc : DateTime.new)(year, month, day);
  }

  DateTime get endOfDay {
    return (isUtc ? DateTime.utc : DateTime.new)(
      year,
      month,
      day,
      23,
      59,
      59,
      999,
      // setting the microseconds 999 moves the date to the next day on web
      kIsWeb ? 0 : 999,
    );
  }

  /// Adds the provided [days] (positive or negative)
  ///
  /// This method takes care of Daylight Saving Time
  DateTime addDays(int days) {
    return (isUtc ? DateTime.utc : DateTime.new)(
      year,
      month,
      day + days,
      hour,
      minute,
      second,
      millisecond,
      // setting the microseconds 999 moves the date to the next day on web
      microsecond,
    );
  }

  DateTime get startOfWeek {
    return addDays(DateTime.monday - startOfDay.weekday).startOfDay;
  }

  DateTime get endOfWeek {
    return addDays(DateTime.sunday - startOfDay.weekday).endOfDay;
  }

  DateTime get nextDay {
    return addDays(1);
  }

  bool isSameDate(DateTime other) {
    return other.year == year && other.month == month && other.day == day;
  }

  bool isBetween(DateTime a, DateTime b) {
    return compareTo(a) >= 0 && compareTo(b) <= 0;
  }

  Duration duration(DateTime other) {
    return difference(other).abs();
  }

  bool isToday() {
    return isSameDate(isUtc ? DateTime.timestamp() : DateTime.now());
  }
}
