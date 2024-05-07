part of 'p_calendar.dart';

class EventCalendarParentData extends ContainerBoxParentData<RenderBox> {}

class RenderEventCalendar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EventCalendarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EventCalendarParentData>
    implements MouseTrackerAnnotation {
  RenderEventCalendar({List<RenderBox>? children}) {
    addAll(children);
  }

  late final Timer _nowUpdateTimer;

  final List<_EventDrawData> _eventsDrawData = <_EventDrawData>[];
  final List<Rect> _unvailableRangesRects = <Rect>[];

  late OnCalendarEventCreated _onEventCreated;
  late OnCalendarEventTap _onEventTap;
  late ScrollController _scrollController;
  late EventCalendarTheme _calendarTheme;

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! EventCalendarParentData) {
      child.parentData = EventCalendarParentData();
    }
  }

  DateTime _now = DateTime.now();

  double _dayColumnWidth = 0.0;

  Offset _drawOffset = Offset.zero;

  CanAddCalendarEvent? _canAddEvent;

  bool _isAddingEventFromTouchOrTrackpad = false;
  Timer? _handleIsAddingEventFromTouchOrTrackpadTimer;

  PointerEvent _lastPointerEvent = const PointerCancelEvent();

  double _scrollOffset = 0.0;

  Timer? _autoScrollTimer;

  late List<CalendarEvent> _events = <CalendarEvent>[];
  set events(List<CalendarEvent> value) {
    if (value != _events) {
      _events = value;
      markNeedsPaint();
    }
  }

  List<CalendarEvent> get _effectEventsForWeek {
    final (DateTime startDate, DateTime endDate) = switch (_viewType) {
      EventCalendarType.day => (_date.startOfDay, _date.endOfDay),
      EventCalendarType.week || EventCalendarType.businessWeek => (
          _date.startOfWeek,
          _date.startOfWeek.addDays(_viewType.daysCount).endOfDay
        ),
    };

    return _events
        .where((CalendarEvent event) =>
            event.start.isBetween(startDate, endDate) ||
            event.end.isBetween(startDate, endDate))
        .toList();
  }

  int _minutesPerSlot = 15;
  set minutesPerSlot(int value) {
    if (value != _minutesPerSlot) {
      _minutesPerSlot = value;
      markNeedsLayout();
      markNeedsPaint();
    }
  }

  List<DateRange> _unavailableRanges = const <DateRange>[];
  set unavailableSlots(List<DateRange> value) {
    if (value != _unavailableRanges) {
      _unavailableRanges = value;
      markNeedsPaint();
    }
  }

  // DayHeaderBuilder? _dayHeaderBuilder;
  // set dayHeaderBuilder(DayHeaderBuilder? value) {
  //   if (value != _dayHeaderBuilder) {
  //     _dayHeaderBuilder = value;
  //     markNeedsLayout();
  //     markNeedsPaint();
  //   }
  // }

  DateTime _date = DateTime.now().startOfWeek;
  set date(DateTime value) {
    if (value != _date) {
      _date = value;
      markNeedsPaint();
    }
  }

  late EventCalendarType _viewType;
  set type(EventCalendarType value) {
    if (value != _viewType) {
      _viewType = value;
      markNeedsLayout();
    }
  }

  int get _slotsPerHour => 60 ~/ _minutesPerSlot;
  int get _subSlotsPerHour => 60 ~/ _minutesPerSlot;
  double get _subSlotHeight => _biggestTimeHeaderHeight / _subSlotsPerHour;

  MouseCursor _cursor = SystemMouseCursors.basic;
  @override
  MouseCursor get cursor => _cursor;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  bool _validForMouseTracker = false;
  @override
  bool get validForMouseTracker => _validForMouseTracker;

  // flag to check if the we have a touch down from a "move" event (which is consumed as scroll)
  // for touch / trackpad.
  bool _isTouchScrolling = false;

  static const double _padding = 16.0;

  static const double _minItemHeight = 30.0;
  static const double _minItemWidth = 60.0;

  double _biggestDayHeaderHeight = 0.0;

  double _biggestTimeHeaderWidth = 0.0;
  double _biggestTimeHeaderHeight = 0.0;

  @override
  void performLayout() {
    final List<RenderBox> children = getChildrenAsList();

    _biggestTimeHeaderHeight = 0.0;
    _biggestTimeHeaderWidth = 0.0;
    _biggestDayHeaderHeight = 0.0;

    final BoxConstraints timeHeaderConstraints = constraints.copyWith(
      minWidth: _minItemWidth,
      maxWidth: 100.0,
      minHeight: _minItemWidth,
    );
    for (int i = 0; i < 24; i += 1) {
      final RenderBox child = children[_viewType.daysCount + i];
      child.layout(timeHeaderConstraints, parentUsesSize: true);
      _biggestTimeHeaderHeight =
          max(_biggestTimeHeaderHeight, child.size.height);
      _biggestTimeHeaderWidth = max(_biggestTimeHeaderWidth, child.size.width);
    }
    _biggestTimeHeaderWidth = _biggestTimeHeaderWidth.ceilToDouble();
    _biggestTimeHeaderHeight = _biggestTimeHeaderHeight.ceilToDouble();

    _dayColumnWidth =
        ((constraints.maxWidth - _biggestTimeHeaderWidth) / _viewType.daysCount)
            .ceilToDouble();

    final BoxConstraints dayHeaderConstraints =
        BoxConstraints(minHeight: _minItemHeight, maxWidth: _dayColumnWidth);
    for (int i = 0; i < _viewType.daysCount; i += 1) {
      final RenderBox child = children[i];
      child.layout(dayHeaderConstraints, parentUsesSize: true);
      (child.parentData as EventCalendarParentData).offset =
          Offset(i * _dayColumnWidth + _biggestTimeHeaderWidth, 0.0);
      _biggestDayHeaderHeight = max(_biggestDayHeaderHeight, child.size.height);
    }
    _biggestDayHeaderHeight = _biggestDayHeaderHeight.ceilToDouble();

    for (int i = 0; i < 24; i += 1) {
      (children[_viewType.daysCount + i].parentData as BoxParentData).offset =
          Offset(0.0, i * _biggestTimeHeaderHeight + _biggestDayHeaderHeight);
    }

    size = constraints
        .tighten(
            height: 24 * _biggestTimeHeaderHeight + _biggestDayHeaderHeight)
        .biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _drawOffset = offset;

    final Canvas canvas = context.canvas;

    final Paint dividerPaint = Paint()
      ..color = _calendarTheme.dividerColor
      ..isAntiAlias = false
      ..strokeWidth = 0.0;

    if (!_hoveredSlot.isInvalid) {
      canvas.drawRect(
        Rect.fromLTWH(
          _hoveredSlot.x * _dayColumnWidth + _biggestTimeHeaderWidth,
          _hoveredSlot.y * _subSlotHeight +
              _biggestDayHeaderHeight +
              _drawOffset.dy,
          _dayColumnWidth,
          _subSlotHeight,
        ),
        Paint()..color = _calendarTheme.inProgressSlotColor.withOpacity(0.25),
      );
    }

    final List<RenderBox> children = getChildrenAsList();

    // Paint time headers (widgets)
    for (int i = 0; i < 24; i += 1) {
      final RenderBox child = children[_viewType.daysCount + i];
      final Offset paintOffset =
          offset + (child.parentData as BoxParentData).offset;
      context.paintChild(child, paintOffset);
    }

    // Horizontal lines, after each time header
    for (int i = 1; i < 24; i += 1) {
      final RenderBox child = children[_viewType.daysCount + i];
      final Offset paintOffset =
          offset + (child.parentData as BoxParentData).offset;
      canvas.drawLine(
        Offset(0.0, paintOffset.dy),
        Offset(size.width, paintOffset.dy),
        dividerPaint,
      );
    }

    _drawRectFromDragSlots(canvas);
    _drawRectsFromEvents(canvas);
    _drawUnavailableRanges(canvas);
    _drawTimeIndicator(canvas);

    // Placeholder rect (top, left)
    canvas.drawRect(
      Rect.fromLTWH(0.0, 0.0, _biggestTimeHeaderWidth, _biggestDayHeaderHeight),
      Paint()..color = _calendarTheme.backgroundColor,
    );

    // Paint days headers (widgets)
    for (int i = 0; i < _viewType.daysCount; i += 1) {
      final RenderBox child = children[i];
      final Offset childOffset = (child.parentData as BoxParentData).offset;

      canvas.drawRect(
        Rect.fromLTWH(childOffset.dx, childOffset.dy, _dayColumnWidth,
            _biggestDayHeaderHeight),
        Paint()..color = _calendarTheme.backgroundColor,
      );

      context.paintChild(child, childOffset);
    }

    // Top horizontal divider, bellow days headers
    canvas.drawLine(
      Offset(0.0, _biggestDayHeaderHeight),
      Offset(size.width, _biggestDayHeaderHeight),
      dividerPaint,
    );

    // Vertical dividers
    for (int i = 0; i < _viewType.daysCount; i += 1) {
      canvas.drawLine(
        Offset(_biggestTimeHeaderWidth + _dayColumnWidth * i, 0.0),
        Offset(_biggestTimeHeaderWidth + _dayColumnWidth * i, size.height),
        dividerPaint,
      );
    }
  }

  void _drawRectFromDragSlots(Canvas canvas) {
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    final Paint paint = Paint()..color = _calendarTheme.inProgressSlotColor;

    if (_startDragSlot != _invalidSlot && _endDragSlot != _invalidSlot) {
      _TargetSlot start = _startDragSlot;
      _TargetSlot end = _endDragSlot;

      if (start.x != end.x) {
        end = (x: start.x, y: end.y);
      }
      if (end.y < start.y) {
        (start, end) = (end, start);
      }

      final Rect rect = Rect.fromLTWH(
        (end.x * _dayColumnWidth) + _biggestTimeHeaderWidth,
        (start.y * _subSlotHeight) + _biggestDayHeaderHeight + _drawOffset.dy,
        _dayColumnWidth,
        (end.y - start.y + 1) * _subSlotHeight,
      );

      final RRect rrect =
          RRect.fromRectAndRadius(rect, const Radius.circular(8.0));
      canvas.drawRRect(rrect, paint);

      if (start.y == start.y) {
        textPainter.text = TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: start.toFormattedTime(_subSlotsPerHour, _minutesPerSlot),
            ),
            const TextSpan(text: ' - '),
            TextSpan(
              text: end
                  ._increment(y: 1)
                  .toFormattedTime(_subSlotsPerHour, _minutesPerSlot),
            ),
          ],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.0,
          ),
        );

        textPainter
          ..layout(maxWidth: _dayColumnWidth)
          ..paint(
            canvas,
            rect.topLeft + const Offset(_padding / 4.0, _padding / 4.0),
          );
      }
    }
  }

  Rect _getRectForDateRange(
    DateRange range, {
    Size extraSize = Size.zero,
  }) {
    final double startDy = (range.start.hour * 60 + range.start.minute) ~/
            _minutesPerSlot *
            _subSlotHeight +
        _biggestDayHeaderHeight;
    final double endDy = (range.end.hour * 60 + range.end.minute) /
            _minutesPerSlot *
            _subSlotHeight +
        _biggestDayHeaderHeight;

    return Rect.fromLTWH(
      switch (_viewType) {
            EventCalendarType.week ||
            EventCalendarType.businessWeek =>
              ((range.start.weekday - 1) * _dayColumnWidth),
            EventCalendarType.day => 0.0,
          } +
          _biggestTimeHeaderWidth,
      startDy + extraSize.height + _drawOffset.dy,
      _dayColumnWidth + extraSize.width,
      endDy - startDy + extraSize.height,
    );
  }

  void _drawRectsFromEvents(Canvas canvas) {
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    final Paint rectPaint = Paint()..color = _calendarTheme.slotColor;

    _eventsDrawData.clear();
    for (final CalendarEvent event in _effectEventsForWeek) {
      final Rect rect = _getRectForDateRange(event.dateRange);
      _eventsDrawData.add(_EventDrawData(event: event, rect: rect));

      final bool isHovered = identical(event, _hoveredEventDrawData?.event);
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(8.0),
      );
      canvas.drawRRect(
        rrect,
        rectPaint
          ..color = (event.color ?? _calendarTheme.slotColor)
          ..colorFilter = isHovered
              ? const ColorFilter.matrix(<double>[
                  1.15, 0, 0, 0, 0, //
                  0, 1.15, 0, 0, 0,
                  0, 0, 1.15, 0, 0,
                  0, 0, 0, 1.15, 0,
                ])
              : null,
      );

      textPainter.text = TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text:
                '${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')}',
          ),
          if (!event.start.isAtSameMomentAs(event.end)) ...<InlineSpan>[
            const TextSpan(text: ' - '),
            TextSpan(
              text:
                  '${event.end.hour.toString().padLeft(2, '0')}:${event.end.minute.toString().padLeft(2, '0')}',
            ),
          ]
        ],
        style: TextStyle(
          color: switch (
              ThemeData.estimateBrightnessForColor(rectPaint.color)) {
            Brightness.dark => Colors.white,
            Brightness.light => Colors.black,
          },
          fontWeight: FontWeight.bold,
          fontSize: 12.0,
        ),
      );
      textPainter
        ..layout(maxWidth: rrect.width)
        ..paint(
          canvas,
          rect.topLeft + const Offset(_padding / 4.0, _padding / 4.0),
        );
    }
  }

  void _drawUnavailableRanges(Canvas canvas) {
    _unvailableRangesRects.clear();

    final Paint paint = Paint()
      ..color = _calendarTheme.unavailableSlotsColor
      ..isAntiAlias = false;

    final (DateTime startDate, DateTime endDate) = switch (_viewType) {
      EventCalendarType.day => (_date.startOfDay, _date.endOfDay),
      EventCalendarType.week || EventCalendarType.businessWeek => (
          _date.startOfWeek,
          _date.startOfWeek.addDays(_viewType.daysCount).endOfDay,
        ),
    };

    final List<DateRange> ranges = _unavailableRanges.where((DateRange range) {
      return range.start.isBetween(startDate, endDate) ||
          range.end.isBetween(startDate, endDate) ||
          (range.start.isBefore(startDate) && range.end.isAfter(startDate));
    }).toList(growable: false);

    for (final DateRange range in ranges) {
      for (DateRange brokenRange = (
        // if range is expanding over multiple days clamp the start to the current date
        // if the range start is before the start date
        start: range.start.isBefore(startDate) ? startDate : range.start,
        end: range.end,
      );
          // range start must be before the end of the range end -
          // and before the end date
          brokenRange.start.compareTo(brokenRange.end) <= 0 &&
              brokenRange.start.compareTo(endDate) <= 0;
          brokenRange = (
        // move range start date to next day to cover the case of multiple days expand
        start: brokenRange.start.nextDay.startOfDay,
        end: brokenRange.end
      )) {
        final Rect rect = _getRectForDateRange((
          start: brokenRange.start,
          end: brokenRange.start.day == brokenRange.end.day
              ? brokenRange.end
              : brokenRange.start.endOfDay,
        ));
        canvas.drawRect(rect, paint);
        _unvailableRangesRects.add(rect);
      }
    }
  }

  void _drawTimeIndicator(Canvas canvas) {
    final double x =
        _biggestTimeHeaderWidth + ((_now.weekday - 1) * _dayColumnWidth);
    final double y = _biggestDayHeaderHeight +
        (_now.hour * _biggestTimeHeaderHeight) +
        (_biggestTimeHeaderHeight * (_now.minute / 60)) +
        _drawOffset.dy;

    canvas.drawLine(
      Offset(8.0 + x, y),
      Offset(x + _dayColumnWidth, y),
      Paint()
        ..color = _calendarTheme.timeIndicatorColor
        ..strokeWidth = 2.0
        ..isAntiAlias = false,
    );

    canvas.drawCircle(
      Offset(8.0 + x, y),
      4.0,
      Paint()..color = _calendarTheme.timeIndicatorColor,
    );
  }

  @override
  bool hitTestSelf(Offset position) => true;

  static const _TargetSlot _invalidSlot = (x: -1, y: -1);

  _TargetSlot _startDragSlot = _invalidSlot;
  _TargetSlot _endDragSlot = _invalidSlot;

  Offset _transformPositionToTimeSlotRelativeOffset(Offset offset) {
    return offset.translate(-_biggestTimeHeaderWidth, -_biggestDayHeaderHeight);
  }

  void _handlePointerDownEvent(PointerDownEvent event) {
    _isTouchScrolling = false;

    final Offset cursorPosition = event.localPosition;

    for (final Rect rect in _unvailableRangesRects) {
      if (rect.contains(cursorPosition + _drawOffset)) {
        return;
      }
    }

    for (final _EventDrawData drawData in _eventsDrawData) {
      if (drawData.rect.contains(cursorPosition + _drawOffset)) {
        return;
      }
    }

    if (event.kind case PointerDeviceKind.touch || PointerDeviceKind.trackpad) {
      _handleIsAddingEventFromTouchOrTrackpadTimer =
          Timer(const Duration(milliseconds: 200), () {
        if (_lastPointerEvent != event) {
          _handleIsAddingEventFromTouchOrTrackpadTimer = null;
          unawaited(HapticFeedback.heavyImpact());
          return;
        }

        _isAddingEventFromTouchOrTrackpad = true;
        final Offset relativeOffset =
            _transformPositionToTimeSlotRelativeOffset(event.localPosition);

        _startDragSlot = (
          x: (relativeOffset.dx / _dayColumnWidth).floor(),
          y: (relativeOffset.dy / _subSlotHeight).floor()
        );
        _endDragSlot = _startDragSlot;
        _cursor = SystemMouseCursors.resizeRow;

        if (_startDragSlot.isInvalid) {
          _startDragSlot = _endDragSlot = _invalidSlot;
          _cursor = SystemMouseCursors.basic;
        }

        markNeedsPaint();
      });
      return;
    }

    final Offset relativeOffset =
        _transformPositionToTimeSlotRelativeOffset(cursorPosition);

    _startDragSlot = (
      x: (relativeOffset.dx / _dayColumnWidth).floor(),
      y: (relativeOffset.dy / _subSlotHeight).floor()
    );
    _endDragSlot = _startDragSlot;
    _cursor = SystemMouseCursors.resizeRow;

    if (_startDragSlot.isInvalid) {
      _startDragSlot = _endDragSlot = _invalidSlot;
      _cursor = SystemMouseCursors.basic;
    }

    markNeedsPaint();
  }

  bool get _isAtScrollEnd {
    return _scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent;
  }

  bool get _isAtScrollStart {
    return _scrollController.position.pixels == 0;
  }

  bool _isPointerAtViewportStartRegion(PointerEvent event) {
    return event.position.dy - _biggestDayHeaderHeight - _subSlotHeight <=
        _biggestDayHeaderHeight;
  }

  bool _isPointerAtViewportEndRegion(PointerEvent event) {
    return _scrollController.position.viewportDimension -
            event.position.dy +
            _biggestDayHeaderHeight <=
        2.0 * _subSlotHeight;
  }

  void _handlePointerMoveEvent(
    PointerEvent event, {
    required BoxHitTestEntry boxHitTestEntry,
    required bool isFromNatureScroll,
  }) {
    // transform global cursor position relative to slots positions
    final Offset offset = event.position.translate(
      -_biggestTimeHeaderWidth,
      globalToLocal(Offset.zero).dy - _biggestDayHeaderHeight,
    );

    if (_lastPointerEvent is! PointerScrollEvent &&
        _autoScrollTimer == null &&
        _cursor != SystemMouseCursors.forbidden) {
      if (_isPointerAtViewportEndRegion(event) && !_isAtScrollEnd) {
        _autoScrollTimer =
            Timer.periodic(const Duration(milliseconds: 3 * 16), (Timer timer) {
          if (_isAtScrollEnd) {
            _autoScrollTimer = null;
            timer.cancel();
            return;
          }

          if (!_isPointerAtViewportEndRegion(_lastPointerEvent)) {
            _autoScrollTimer = null;
            timer.cancel();
            return;
          }

          _updateScrollOffset(_subSlotHeight);
          _scrollController.jumpTo(_scrollOffset);
          handleEvent(_lastPointerEvent, boxHitTestEntry);
        });
        return;
      }

      if (_isPointerAtViewportStartRegion(event) && !_isAtScrollStart) {
        _autoScrollTimer =
            Timer.periodic(const Duration(milliseconds: 3 * 16), (Timer timer) {
          if (_isAtScrollStart) {
            _autoScrollTimer = null;
            timer.cancel();
            return;
          }

          if (!_isPointerAtViewportStartRegion(_lastPointerEvent)) {
            _autoScrollTimer = null;
            timer.cancel();
            return;
          }

          _updateScrollOffset(-_subSlotHeight);
          _scrollController.jumpTo(_scrollOffset);
          handleEvent(_lastPointerEvent, boxHitTestEntry);
        });
        return;
      }
    }

    final _TargetSlot slot = (
      x: (offset.dx / _dayColumnWidth).floor(),
      y: (offset.dy / _subSlotHeight)
          .floor()
          .clamp(-1, _subSlotsPerHour * 24 - 1),
    );

    if (slot.isInvalid) {
      return;
    }

    if (_endDragSlot != slot) {
      _TargetSlot start = _startDragSlot;
      _TargetSlot end = slot;

      if (start.x != end.x) {
        end = (x: start.x, y: end.y);
      }
      if (end.y < start.y) {
        (start, end) = (end, start);
      }

      final Rect rect = Rect.fromLTWH(
        (end.x * _dayColumnWidth) + _biggestTimeHeaderWidth,
        (start.y * _subSlotHeight) + _biggestDayHeaderHeight + _drawOffset.dy,
        _dayColumnWidth,
        (end.y - start.y + 1) * _subSlotHeight,
      );

      @pragma('vm:prefer-inline')
      bool rectOverlapsWithOther(Rect other) {
        return rect.left >= other.left &&
            rect.right <= other.right &&
            !(rect.top >= other.bottom || rect.bottom <= other.top);
      }

      for (final Rect unavailableRect in _unvailableRangesRects) {
        if (rectOverlapsWithOther(unavailableRect)) {
          _cursor = SystemMouseCursors.forbidden;
          markNeedsPaint();
          return;
        }
      }

      for (final _EventDrawData(rect: Rect testRect) in _eventsDrawData) {
        if (rectOverlapsWithOther(testRect)) {
          _cursor = SystemMouseCursors.forbidden;
          markNeedsPaint();
          return;
        }
      }

      _endDragSlot = slot;
      _cursor = SystemMouseCursors.resizeRow;
      markNeedsPaint();
    }
  }

  void _handlePointerUpEvent(PointerUpEvent event) async {
    bool checkForWinningEvent = !(_isAddingEventFromTouchOrTrackpad ||
        _isTouchScrolling ||
        _startDragSlot != _invalidSlot);

    _isAddingEventFromTouchOrTrackpad = false;
    _cursor = SystemMouseCursors.basic;
    markNeedsPaint();

    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;

    if (_startDragSlot != _invalidSlot && _endDragSlot == _invalidSlot) {
      _startDragSlot = _invalidSlot;
      checkForWinningEvent = false;
    }

    if (checkForWinningEvent) {
      _EventDrawData? winner;
      for (final _EventDrawData drawData in _eventsDrawData) {
        if (drawData.rect.contains(event.localPosition + _drawOffset)) {
          winner = drawData;
          break;
        }
      }

      if (winner != null) {
        _onEventTap(winner.event, winner.rect);
        return;
      }
    }

    if (_startDragSlot.isInvalid || _endDragSlot.isInvalid) {
      return;
    }

    if (_startDragSlot.x != _endDragSlot.x) {
      _endDragSlot = (x: _startDragSlot.x, y: _endDragSlot.y);
    }

    if (_startDragSlot.y > _endDragSlot.y) {
      final _TargetSlot temp = _startDragSlot;
      _startDragSlot = _endDragSlot;
      _endDragSlot = temp;
    }

    final DateTime startDate = _date.copyWith(
      day: _startDragSlot.x + _date.day,
      hour: _startDragSlot.y ~/ _slotsPerHour,
      minute: _startDragSlot.y % _subSlotsPerHour * _minutesPerSlot,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final DateTime endDate = _date.copyWith(
      day: _endDragSlot.x + _date.day,
      hour: _endDragSlot.y ~/ _slotsPerHour,
      minute: (1 + _endDragSlot.y % _subSlotsPerHour) * _minutesPerSlot,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final DateRange eventDateRange = (
      start: startDate,
      end: !endDate.isSameDate(startDate) ? startDate.endOfDay : endDate,
    );

    if (await _canAddEvent?.call(eventDateRange) ?? true) {
      _onEventCreated(eventDateRange);
    }

    _startDragSlot = _endDragSlot = _invalidSlot;
    markNeedsPaint();
  }

  _TargetSlot _hoveredSlot = _invalidSlot;
  _EventDrawData? _hoveredEventDrawData;

  void _handlePointerHoverEvent(PointerHoverEvent event) {
    final Offset cursorPosition = event.localPosition;

    for (final Rect rect in _unvailableRangesRects) {
      if (rect.contains(cursorPosition + _drawOffset)) {
        _cursor = SystemMouseCursors.forbidden;
        _hoveredSlot = _invalidSlot;
        markNeedsPaint();
        return;
      }
    }

    final Offset translatedOffset =
        _transformPositionToTimeSlotRelativeOffset(cursorPosition);
    final _TargetSlot slot = (
      x: (translatedOffset.dx / _dayColumnWidth).floor(),
      y: (translatedOffset.dy / _subSlotHeight).floor()
    );

    _EventDrawData? winner;
    for (final _EventDrawData drawData in _eventsDrawData) {
      if (drawData.rect.contains(cursorPosition + _drawOffset)) {
        winner = drawData;
        break;
      }
    }

    MouseCursor newCursor = _cursor;
    if (!identical(_hoveredEventDrawData, winner)) {
      _hoveredEventDrawData = winner;
      newCursor =
          winner != null ? SystemMouseCursors.click : SystemMouseCursors.basic;
    } else if (winner == null && _cursor != SystemMouseCursors.basic) {
      newCursor = SystemMouseCursors.basic;
    }

    _TargetSlot hoveredSlot = _invalidSlot;

    if (event.kind case PointerDeviceKind.mouse) {
      if (!(winner?.rect.contains(cursorPosition) ?? false)) {
        hoveredSlot = slot;
      }
    }

    if (newCursor != _cursor || hoveredSlot != _hoveredSlot) {
      _cursor = newCursor;
      _hoveredSlot = hoveredSlot;
      markNeedsPaint();
    }
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));

    _lastPointerEvent = event;
    _handleIsAddingEventFromTouchOrTrackpadTimer?.cancel();

    if (event is PointerDownEvent) {
      _handlePointerDownEvent(event);
      return;
    }

    if (event is PointerUpEvent) {
      _handlePointerUpEvent(event);
      return;
    }

    if (event is PointerMoveEvent) {
      if (event.kind == PointerDeviceKind.touch &&
          !_isAddingEventFromTouchOrTrackpad) {
        _isTouchScrolling = true;
        _updateScrollOffset(-event.delta.dy);
        if (_scrollController.hasClients &&
            _scrollController.offset != _scrollOffset) {
          _scrollController.jumpTo(_scrollOffset);
        }
        return;
      }
      _handlePointerMoveEvent(
        event,
        boxHitTestEntry: entry,
        isFromNatureScroll: false,
      );
      return;
    }

    if (event is PointerHoverEvent) {
      _handlePointerHoverEvent(event);
      return;
    }

    if (event is PointerScrollEvent) {
      _updateScrollOffset(event.scrollDelta.dy);
      if (_scrollController.hasClients &&
          _scrollController.offset != _scrollOffset) {
        _scrollController.jumpTo(_scrollOffset);
        _handlePointerMoveEvent(
          event,
          boxHitTestEntry: entry,
          isFromNatureScroll: true,
        );
      }
      return;
    }
  }

  @pragma('vm:prefer-inline')
  void _updateScrollOffset(double dy) {
    _scrollOffset = (_scrollOffset + dy)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
  }

  bool _handleKeyboardEvent(KeyEvent event) {
    if (event is KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _startDragSlot != _invalidSlot) {
      _hoveredSlot = _startDragSlot = _endDragSlot = _invalidSlot;
      _cursor = SystemMouseCursors.basic;
      markNeedsPaint();
      return true;
    }
    return false;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _validForMouseTracker = true;
    HardwareKeyboard.instance.addHandler(_handleKeyboardEvent);
    _nowUpdateTimer = Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      _now = DateTime.now();
      markNeedsPaint();
    });
  }

  @override
  void detach() {
    _validForMouseTracker = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyboardEvent);
    _autoScrollTimer?.cancel();
    _nowUpdateTimer.cancel();
    super.detach();
  }
}

typedef _TargetSlot = ({
  int x,
  int y,
});

extension on _TargetSlot {
  bool get isInvalid {
    return x <= -1 || y <= -1;
  }

  String toFormattedTime(int subSlotsPerHour, int minutesPerSlot) {
    return '${'${y ~/ subSlotsPerHour}'.padLeft(2, '0')}:${'${y % subSlotsPerHour * minutesPerSlot}'.padLeft(2, '0')}';
  }

  _TargetSlot _increment({int x = 0, int y = 0}) {
    return (x: x + this.x, y: y + this.y);
  }
}

class _EventDrawData {
  CalendarEvent event;
  Rect rect;

  _EventDrawData({
    required this.event,
    required this.rect,
  });
}
