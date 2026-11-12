# Fuel economy and reminders: ways they can be wrong

Written before the code. I = isolated scenario in test/engine_scenarios_test.dart,
E = end-to-end test through the app.

| # | Failure | Prevention | Check |
|---|---------|------------|-------|
| 1 | Economy taken from a partial fill-up, giving nonsense like 3 L/100 km | Economy only between two full fill-ups; partials in between add their fuel to the next full | I-A, E |
| 2 | A forgotten fill-up makes the next one look far too efficient | "Missed the previous fill-up" flag breaks the chain; that stretch gets no economy | I-A, E |
| 3 | First fill-up shows an economy with nothing to compare to | No economy until there is an earlier full fill-up | I-A |
| 4 | A back-filled entry (typed later, dated earlier) is chained in typing order | Always order by odometer, then date | I-B, E |
| 5 | Odometer lower than an earlier reading (typo) gives negative distance | Validator: must be above every earlier day's reading and below every later day's | I-C, E |
| 6 | Average economy is the mean of each stretch's economy (biased) | Average = total distance / total fuel over the stretches that have economy | I-A, E |
| 7 | Wrong gallon (US 3.785 L vs UK 4.546 L) or mile constant | Canonical storage in metres and millilitres; exact conversion constants; checked against hand values | I-D, E |
| 8 | Switching units changes stored history | Stored values never change; only display converts | E |
| 9 | Display rounding differs between screen and export (half-even vs half-up) | One rounding helper, half-up, used everywhere | I-D |
| 10 | Two vehicles' fill-ups chained together | Computed per vehicle | E |
| 11 | Reminder "due" counted from the old due date, so it drifts | Next due = last done + interval | I-E, E |
| 12 | Distance reminder with no odometer readings crashes or says overdue | Distance part unknown until there is a reading; date part still works | I-E |
| 13 | Reminder due by date or distance: shows OK when one of them is overdue | State is the worse of the two | I-E, E |
| 14 | Cost per km divides by zero with one reading | Shown only when distance > 0 | I-F |
| 15 | Odometer replaced or rolled over | Not supported in v1 (start a new vehicle) | - |
