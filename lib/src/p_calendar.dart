import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:p_calendar/src/date_time_extensions.dart';

part 'p_calendar_controller.dart';
part 'p_calendar_render_object.dart';
part 'p_calendar_theme.dart';

/// Model class for events used by [EventCalendar].
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.start,
    required this.end,
    this.metadata,
    this.color,
  });

  /// Identifier provided by the user when the events is created.
  final String id;

  /// Date that the event starts.
  final DateTime start;

  /// Date that the event ends.
  final DateTime end;

  /// Optional metadata provided by the user.
  final Object? metadata;

  /// Optional background color to use for the event when displayed.
  final Color? color;

  DateRange get dateRange => (start: start, end: end);

  Duration get duration => start.difference(end);
}

/// A record that keeps has a [start] and [end] date.
typedef DateRange = ({DateTime start, DateTime end});

/// Callback invoked by the calendar when a new event is added.
///
/// Check [CanAddCalendarEvent] to add provide conditioning when an event can be added.
typedef OnCalendarEventCreated = void Function(
  ({DateTime start, DateTime end}) event,
);

/// Callback invoked by the calendar before a new event is added on the calendar
/// to verify if it's valid.
typedef CanAddCalendarEvent = Future<bool> Function(
  DateRange range,
);

/// Callback that is triggered when tapping on a [CalendarEvent].
///
/// Provides the [event] itself and the [rect] (globally position) for this event.
typedef OnCalendarEventTap = void Function(
  CalendarEvent event,
  Rect rect,
);

enum EventCalendarType {
  week(daysCount: 7, skipDays: 7),
  businessWeek(daysCount: 5, skipDays: 7),
  day(daysCount: 1, skipDays: 1),
  ;

  const EventCalendarType({
    required this.daysCount,
    required this.skipDays,
  });

  final int daysCount;
  final int skipDays;
}

class EventCalendar extends StatefulWidget {
  const EventCalendar({
    super.key,
    required this.controller,
    required this.onEventCreated,
    required this.events,
    required this.minutesPerSlot,
    required this.onEventTap,
    required this.dayHeaderBuilder,
    required this.timeHeaderBuilder,
    this.availableRanges = const <DateRange>[],
    this.canAddEvent,
    this.calendarTheme,
  });

  static Future<void> disableContextMenu() async {
    if (kIsWeb) {
      await BrowserContextMenu.disableContextMenu();
    }
  }

  /// Controller that allows to interact with with a [EventCalendar].
  final EventCalendarController controller;

  /// Callback when an event is is created.
  final OnCalendarEventCreated onEventCreated;

  /// Callback guard to check if an event can be created.
  final CanAddCalendarEvent? canAddEvent;

  /// List of events to show
  final List<CalendarEvent> events;

  /// Minutes that the minute slot occupies.
  ///
  /// Valid options: [15, 30]
  final int minutesPerSlot;

  /// Callback triggered when a user taps on an event.
  final OnCalendarEventTap onEventTap;

  /// Date ranges that are not available for booking.
  ///
  /// If null (default value) or empty ranges are provided then all (non overlapping) slots are available.
  final List<DateRange> availableRanges;

  /// Theme for the calendar.
  final EventCalendarTheme? calendarTheme;

  /// Callback to build the header for a day column.
  final Widget Function(DateTime date) dayHeaderBuilder;

  /// Callback to build the header for a time row.
  final Widget Function(DateTime date) timeHeaderBuilder;

  @override
  State<EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  final ScrollController _scrollController = ScrollController();

  EventCalendarController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EventCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      controller: _scrollController,
      child: _EventCalendarObjectWidget(
        controller: widget.controller,
        onEventCreated: widget.onEventCreated,
        events: widget.events,
        minutesPerSlot: widget.minutesPerSlot,
        onEventTap: widget.onEventTap,
        scrollController: _scrollController,
        calendarTheme: widget.calendarTheme,
        canAddEvent: widget.canAddEvent,
        availableRanges: widget.availableRanges,
        children: <Widget>[
          for (int i = 0; i < widget.controller.viewType.daysCount; i += 1)
            widget.dayHeaderBuilder(_controller.firstDayOfView.addDays(i)),
          for (int i = 0; i < 24; i += 1)
            widget
                .timeHeaderBuilder(_controller.firstDayOfView.copyWith(hour: i))
        ],
      ),
    );
  }
}

/// Calendar widget
class _EventCalendarObjectWidget extends MultiChildRenderObjectWidget {
  const _EventCalendarObjectWidget({
    required this.controller,
    required this.onEventCreated,
    required this.events,
    required this.minutesPerSlot,
    required this.onEventTap,
    required this.scrollController,
    required this.availableRanges,
    this.canAddEvent,
    this.calendarTheme,
    required super.children,
  }) : assert(minutesPerSlot == 15 ||
            minutesPerSlot == 30 ||
            minutesPerSlot == 60);

  final EventCalendarController controller;

  final OnCalendarEventCreated onEventCreated;

  final CanAddCalendarEvent? canAddEvent;

  final List<CalendarEvent> events;

  final int minutesPerSlot;

  final OnCalendarEventTap onEventTap;

  final ScrollController scrollController;

  final List<DateRange> availableRanges;

  final EventCalendarTheme? calendarTheme;

  @override
  RenderEventCalendar createRenderObject(BuildContext context) {
    final RenderEventCalendar renderObject = RenderEventCalendar()
      .._onEventCreated = onEventCreated
      .._canAddEvent = canAddEvent
      .._events = events
      .._calendarTheme =
          calendarTheme ?? EventCalendarTheme.fromThemeData(Theme.of(context))
      .._minutesPerSlot = minutesPerSlot
      .._onEventTap = onEventTap
      .._scrollController = scrollController
      .._availableRanges = availableRanges;

    controller._attach(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderEventCalendar renderObject,
  ) {
    renderObject
      .._onEventCreated = onEventCreated
      .._canAddEvent = canAddEvent
      ..events = events
      .._calendarTheme =
          calendarTheme ?? EventCalendarTheme.fromThemeData(Theme.of(context))
      ..minutesPerSlot = minutesPerSlot
      .._onEventTap = onEventTap
      .._scrollController = scrollController
      .._availableRanges = availableRanges;
    controller._attach(renderObject);
  }
}
