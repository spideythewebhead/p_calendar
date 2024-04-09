part of 'p_calendar.dart';

class EventCalendarTheme {
  EventCalendarTheme({
    required this.slotColor,
    required this.dividerColor,
    required this.unavailableSlotsColor,
    required this.inProgressSlotColor,
    required this.subSlotsIndicatorColor,
    required this.backgroundColor,
    required this.timeIndicatorColor,
  });

  final Color slotColor;
  final Color dividerColor;
  final Color unavailableSlotsColor;
  final Color inProgressSlotColor;
  final Color subSlotsIndicatorColor;
  final Color backgroundColor;
  final Color timeIndicatorColor;

  factory EventCalendarTheme.fromThemeData(ThemeData theme) {
    return EventCalendarTheme(
      slotColor: theme.colorScheme.primaryContainer,
      dividerColor: theme.dividerColor,
      unavailableSlotsColor: theme.disabledColor,
      inProgressSlotColor: theme.colorScheme.secondaryContainer,
      subSlotsIndicatorColor: theme.colorScheme.onSurface,
      backgroundColor: theme.colorScheme.background,
      timeIndicatorColor: theme.colorScheme.tertiary,
    );
  }

  EventCalendarTheme copyWith({
    Color? slotColor,
    Color? dividerColor,
    Color? unavailableSlotsColor,
    Color? inProgressSlotColor,
    Color? subSlotsIndicatorColor,
    Color? backgroundColor,
    Color? timeIndicatorColor,
  }) {
    return EventCalendarTheme(
      slotColor: slotColor ?? this.slotColor,
      dividerColor: dividerColor ?? this.dividerColor,
      unavailableSlotsColor:
          unavailableSlotsColor ?? this.unavailableSlotsColor,
      inProgressSlotColor: inProgressSlotColor ?? this.inProgressSlotColor,
      subSlotsIndicatorColor:
          subSlotsIndicatorColor ?? this.subSlotsIndicatorColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      timeIndicatorColor: timeIndicatorColor ?? this.timeIndicatorColor,
    );
  }
}
