part of 'p_calendar.dart';

class EventCalendarController extends ChangeNotifier {
  EventCalendarController({
    EventCalendarType type = EventCalendarType.week,
  }) : _viewType = type {
    _firstDayOfView = _firstDateBasedOnViewType(DateTime.now());
    _timezoneOffset = _firstDayOfView.timeZoneOffset;
  }

  late DateTime _firstDayOfView;
  late Duration _timezoneOffset;

  /// Returns the starting date for the current [viewType].
  DateTime get firstDayOfView => _firstDayOfView;

  EventCalendarType _viewType;

  /// Rendering type for the calendar. Defaults to [EventCalendarType.week].
  EventCalendarType get viewType => _viewType;
  set viewType(EventCalendarType type) {
    _viewType = type;
    _renderObject?.type = viewType;
    today();
    notifyListeners();
  }

  RenderEventCalendar? _renderObject;
  void _attach(RenderEventCalendar renderObject) {
    renderObject._viewType = _viewType;

    _renderObject = renderObject;
    _renderObject?.markNeedsPaint();
  }

  void jumpToPreviousPage() {
    _firstDayOfView = _firstDayOfView.add(Duration(days: -_viewType.skipDays));
    _correctFirstDateOfView();

    _renderObject?.date = firstDayOfView;
    notifyListeners();
  }

  void jumpToNextPage() {
    _firstDayOfView = _firstDayOfView.add(Duration(days: _viewType.skipDays));
    _correctFirstDateOfView();

    _renderObject?.date = firstDayOfView;
    notifyListeners();
  }

  void today() {
    _firstDayOfView = _firstDateBasedOnViewType(DateTime.now());
    _renderObject?.date = _firstDayOfView;
    notifyListeners();
  }

  void goToDate(DateTime date) {
    _firstDayOfView = _firstDateBasedOnViewType(date);
    _renderObject?.date = _firstDayOfView;
    notifyListeners();
  }

  /// Check if the timezone offset has changed and add the difference of the hours to [_firstDayOfView]
  void _correctFirstDateOfView() {
    if (_firstDayOfView.timeZoneOffset != _timezoneOffset) {
      _firstDayOfView = _firstDayOfView
          .add((_firstDayOfView.timeZoneOffset - _timezoneOffset).abs());
      _timezoneOffset = _firstDayOfView.timeZoneOffset;
    }
  }

  DateTime _firstDateBasedOnViewType(DateTime date) {
    return switch (_viewType) {
      EventCalendarType.week ||
      EventCalendarType.businessWeek =>
        date.startOfWeek,
      EventCalendarType.day => date.startOfDay,
    };
  }
}
