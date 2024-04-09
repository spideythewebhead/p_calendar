part of 'p_calendar.dart';

class EventCalendarController extends ChangeNotifier {
  EventCalendarController({
    EventCalendarType type = EventCalendarType.week,
  }) : _viewType = type;

  DateTime _firstDayOfView = DateTime.now().startOfWeek;

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

  void previousWeek() {
    _firstDayOfView =
        _firstDayOfView.add(Duration(days: -_viewType.skipDays)).startOfDay;
    _renderObject?.date = firstDayOfView;
    notifyListeners();
  }

  void nextWeek() {
    _firstDayOfView =
        _firstDayOfView.add(Duration(days: _viewType.skipDays)).startOfDay;
    _renderObject?.date = firstDayOfView;
    notifyListeners();
  }

  void today() {
    _firstDayOfView = switch (_viewType) {
      EventCalendarType.week ||
      EventCalendarType.businessWeek =>
        DateTime.now().startOfWeek,
      EventCalendarType.day => DateTime.now().startOfDay,
    };
    _renderObject?.date = _firstDayOfView;
    notifyListeners();
  }
}
