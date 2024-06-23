import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:p_calendar/p_calendar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EventCalendar.disableContextMenu();
  runApp(const App());
}

final BorderSide borderSide = BorderSide(color: Colors.grey.shade300);

class App extends StatefulWidget {
  const App({super.key});

  static AppState of(BuildContext context) {
    return context.findRootAncestorStateOfType<AppState>()!;
  }

  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode mode) {
    if (mode != _themeMode) {
      setState(() {
        _themeMode = mode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Calendar',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          secondary: Colors.orange,
          secondaryContainer: Colors.purple,
        ),
        dividerColor: Colors.black12,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyan,
          secondary: Colors.deepPurpleAccent,
        ),
        dividerColor: Colors.white10,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const CalendarPage(),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final EventCalendarController _calendarController = EventCalendarController();
  final FocusNode _calendarFocusNode = FocusNode();

  final DateFormat _monthDateFormat = DateFormat.MMMM();

  List<CalendarEvent> _events = <CalendarEvent>[
    CalendarEvent(
      id: 'test',
      start: DateTime.now().startOfDay.add(const Duration(hours: 5)),
      end: DateTime.now().startOfDay.add(const Duration(hours: 5, minutes: 30)),
    )
  ];
  CalendarEvent? _event;
  Rect? _eventRect;

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (BuildContext context) {
        return Positioned.fill(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _overlayController.hide();
                    _eventRect = null;
                  },
                ),
              ),
              if (_eventRect case Rect rect)
                Positioned(
                  top: rect.topRight.dy + _calendarFocusNode.offset.dy,
                  left: rect.topRight.dx.clamp(
                      0.0, MediaQuery.sizeOf(context).width - rect.width),
                  child: Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              final CalendarEvent? event = _event;
                              setState(() {
                                _events = <CalendarEvent>[..._events]
                                  ..remove(event);
                              });
                              _overlayController.hide();
                              _event = null;
                              _eventRect = null;
                            },
                            icon: const Icon(Icons.delete),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SizedBox(height: 8.0),
                              Text('Start: ${_event!.start.toIso8601String()}'),
                              const SizedBox(height: 8.0),
                              Text('End: ${_event!.end.toIso8601String()}'),
                              const SizedBox(height: 8.0),
                              Text(
                                'Duration: ${_event!.end.difference(_event!.start)}',
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: Scaffold(
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  ListenableBuilder(
                    listenable: _calendarController,
                    builder: (BuildContext context, Widget? child) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                            color: Theme.of(context).colorScheme.secondary,
                          )),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.titleSmall,
                            children: <InlineSpan>[
                              TextSpan(
                                text: _monthDateFormat
                                    .format(_calendarController.firstDayOfView),
                              ),
                              if (_calendarController.viewType !=
                                  EventCalendarType.day)
                                if (_calendarController.firstDayOfView.endOfWeek
                                    case DateTime endOfWeek
                                    when endOfWeek.month !=
                                        _calendarController.firstDayOfView
                                            .month) ...<InlineSpan>[
                                  if (_calendarController.firstDayOfView.year !=
                                      endOfWeek.year)
                                    TextSpan(
                                      text:
                                          ' (${_calendarController.firstDayOfView.year}) ',
                                    ),
                                  TextSpan(
                                    text:
                                        ' / ${_monthDateFormat.format(endOfWeek)}',
                                  ),
                                  TextSpan(
                                    text: ' (${endOfWeek.year}) ',
                                  ),
                                ] else
                                  TextSpan(
                                    text:
                                        ' (${_calendarController.firstDayOfView.year}) ',
                                  )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Flexible(
                    child: ListenableBuilder(
                      listenable: _calendarController,
                      builder: (BuildContext context, Widget? child) {
                        final bool isDayView = _calendarController.viewType ==
                            EventCalendarType.day;
                        return Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 8.0,
                          children: <Widget>[
                            Builder(
                              builder: (BuildContext context) {
                                return SizedBox(
                                  width: 100.0,
                                  child: DropdownButtonFormField<ThemeMode>(
                                    decoration: const InputDecoration(
                                      label: Text('Theme'),
                                    ),
                                    onChanged: (ThemeMode? value) {
                                      if (value != null) {
                                        App.of(context).themeMode = value;
                                      }
                                    },
                                    value: App.of(context).themeMode,
                                    items: [
                                      for (final ThemeMode mode
                                          in ThemeMode.values)
                                        DropdownMenuItem(
                                          value: mode,
                                          child: Text(mode.name),
                                        )
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8.0),
                            SizedBox(
                              width: 150.0,
                              child: DropdownButtonFormField<EventCalendarType>(
                                decoration: const InputDecoration(
                                  label: Text('View type'),
                                ),
                                onChanged: (EventCalendarType? value) {
                                  if (value != null) {
                                    _calendarController.viewType = value;
                                  }
                                },
                                value: _calendarController.viewType,
                                items: [
                                  for (final EventCalendarType type
                                      in EventCalendarType.values)
                                    DropdownMenuItem(
                                      value: type,
                                      child: Text(type.name),
                                    )
                                ],
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: _calendarController.today,
                                  child: const Text('Today'),
                                ),
                                const SizedBox(width: 8.0),
                                IconButton(
                                  tooltip: isDayView
                                      ? 'Previous day'
                                      : 'Previous week',
                                  onPressed:
                                      _calendarController.jumpToPreviousPage,
                                  icon: const Icon(Icons.keyboard_arrow_left),
                                ),
                                const SizedBox(width: 8.0),
                                IconButton(
                                  tooltip: isDayView ? 'Next day' : 'Next week',
                                  onPressed: _calendarController.jumpToNextPage,
                                  icon: const Icon(Icons.keyboard_arrow_right),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1.0, height: 1.0),
            Flexible(
              child: Focus(
                focusNode: _calendarFocusNode,
                child: EventCalendar(
                  calendarTheme:
                      EventCalendarTheme.fromThemeData(Theme.of(context))
                          .copyWith(
                    unavailableSlotsColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                    dividerColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade700
                            : Colors.grey.shade500,
                  ),
                  controller: _calendarController,
                  minutesPerSlot: 15,
                  events: _events,
                  availableRanges: <DateRange>[
                    (
                      start: DateTime.now().startOfDay,
                      end: DateTime.now()
                          .startOfDay
                          .add(const Duration(hours: 1))
                    ),
                    (
                      start: DateTime.now()
                          .startOfDay
                          .add(const Duration(hours: 5)),
                      end: DateTime.now()
                          .startOfDay
                          .add(const Duration(hours: 8))
                    ),
                    (
                      start: DateTime.now()
                          .startOfDay
                          .add(const Duration(hours: 20)),
                      end: DateTime.now()
                          .startOfDay
                          .add(const Duration(hours: 23))
                    ),
                  ],
                  onEventCreated: (DateRange event) async {
                    setState(() {
                      _events = <CalendarEvent>[
                        ..._events,
                        CalendarEvent(
                          id: event.start.millisecondsSinceEpoch.toString(),
                          start: event.start,
                          end: event.end,
                          color: Color(0xff000000 |
                              (Random().nextDouble() * 0xffffff).toInt()),
                        )
                      ];
                    });
                  },
                  canAddEvent: (DateRange event) {
                    if (event.start.hour case 1 || 13) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Events at 1 AM/PM are prohibited',
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                        ),
                      );
                      return SynchronousFuture<bool>(false);
                    }
                    return SynchronousFuture<bool>(true);
                  },
                  onEventTap: (CalendarEvent event, Rect rect) async {
                    _event = event;
                    _eventRect = rect;

                    if (MediaQuery.sizeOf(context).width <= 600) {
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                IconButton(
                                  onPressed: () {
                                    final CalendarEvent? event = _event;
                                    setState(() {
                                      _events = <CalendarEvent>[..._events]
                                        ..remove(event);
                                    });
                                    _event = null;
                                    _eventRect = null;
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.delete),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const SizedBox(height: 8.0),
                                    Text(
                                        'Start: ${_event!.start.toIso8601String()}'),
                                    const SizedBox(height: 8.0),
                                    Text(
                                        'End: ${_event!.end.toIso8601String()}'),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      'Duration: ${_event!.end.difference(_event!.start)}',
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      );
                      return;
                    }

                    _overlayController.show();
                  },
                  dayHeaderBuilder: (DateTime date) {
                    final dayWidget = Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        DateFormat('dd').format(date),
                        textAlign: TextAlign.center,
                      ),
                    );
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEEE').format(date),
                              textAlign: TextAlign.center,
                            ),
                            if (date.isToday())
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.purple,
                                ),
                                child: dayWidget,
                              )
                            else
                              dayWidget
                          ],
                        ),
                      ),
                    );
                  },
                  timeHeaderBuilder: (DateTime date) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        DateFormat('HH:mm').format(date),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
