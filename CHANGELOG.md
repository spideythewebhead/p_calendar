### 0.0.1-dev.5

- Add support for rendering events expanding in multiple days

### 0.0.1-dev.4

- Replace `unavailableRanges` with `availableRanges` so the API is easier to use (**Breaking change**)
- Rename `nextWeek` and `previousWeek` on `EventCalendarController` to `jumpToNextPage` and `jumpToPreviousPage` (**Breaking change**)
- Remove `final` from `_nowUpdateTimer` variable to fix an issue when the widget is re attached

### 0.0.1-dev.3

- Add method on EventCalendarController to be able to jump on a specific date
- Fix slot rendering when end time is on different date

### 0.0.1-dev.2

- Disable anti alias on dividers drawing (Improves the rendering of the lines)
- Apply ceiling to the calculated width and heights of rendered boxes
- Draw event slots on top of unavailable slots
- Improve example app on smaller screensq

### 0.0.1-dev.1

Initial version
