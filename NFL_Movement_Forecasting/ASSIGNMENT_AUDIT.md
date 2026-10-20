# Assignment requirement audit

Audited 2026-10-20 against all three pages of `Project 2026.pdf`, including the
overview, Tasks 1-7, required products, and academic-integrity guidance.
This is an evidence checklist and study aid, not a finished written report.

## Updated presentation: one main time series

The main investigation is now **Rome Odunze's one selected gauntlet attempt**.
Use `output/PRIMARY_RESULTS.txt` and `primary_time_series.csv` first. All main
time-series plots, ACFs, parameter estimates, residuals, test errors, and the final
forecast refer to that same attempt. The original class-wide analysis below is
retained as supporting context, not the main dataset.

The main split is 60 training frames, ten initial test frames, then ten more
frames for the updated forecast check. Each step is 0.1 seconds. The final fit
uses frames 1-70 and predicts 71-80; it does not incorporate those future values.

For Task 4, lead with this **single-attempt** comparison:

| Method | Initial-test MAE (yd/s) | Initial-test RMSE (yd/s) |
| --- | ---: | ---: |
| Holt | 0.153 | 0.192 |
| Damped Holt | 0.192 | 0.240 |
| Naive | 0.341 | 0.402 |
| SES | 0.341 | 0.402 |

Both error criteria favor Holt here, consistent with the method already chosen
on 2023. The residual weaknesses described below still apply. Final-window MAE
is 0.075 yd/s; that is a different window from the initial test, not the same
model error calculated twice. Use `plots/05_primary_model_comparison.png`.

Only after completing this main account, discuss the other-player check using
`SUPPLEMENTARY_RESULTS.txt`. It excludes every attempt by Rome, leaving 38 players
in 2023 and 30 in 2024. The original full-cohort figures below include Rome and
must not be relabeled as the other-player-only results. The supplement is a
retrospective robustness summary because these data have already been examined.

This organization directly demonstrates how separate player records become
separate time series: the primary series contains exactly one player/attempt;
the supplement averages forecast errors, never joins players' measurements.

## Overall status

The R analysis supplies the computations and figures for Tasks 1-5. The checklist
below supplies concrete evidence for the questions that require interpretation.
Tasks 6 and 7 are not complete: no student-authored word-processed report,
individual slides, presentation booking, or delivered oral presentation has been
verified. Do not describe the whole assignment as finished.

The remaining subject-matter issue is course suitability: a continuous 10 Hz
physical time series meets the literal time-series/split requirement, but lasts
seconds rather than the monthly/annual examples. Instructor acceptance is not
established. Siopsis should decide whether that scope is appropriate.

The PDF says Fall 2024 and October 21 despite its filename. Verify the applicable
deadline and course AI-code policy; the file does not explicitly authorize this
particular amount of AI-assisted code. Its examples exclude AI-written reports
and substantial AI-generated slides.

## Required products

| Product | Status | Evidence / action |
| --- | --- | --- |
| Group R code and output | Complete and rerun | `forecast_movement.R`, `output/results.txt`, CSVs, plots, `session_info.txt` |
| Group written report | Outstanding | Write a word-processed report with your interpretations and selected figures |
| Individual presentation slides | Outstanding | Each member prepares their own slides |
| Individual oral presentation | Outstanding | Each member books and delivers a 5-7 minute, one-on-one presentation |

## Task 1: choose an appropriate dataset

| Question / requirement | Evidence and assessment |
| --- | --- |
| Credible source? | NFL Big Data Bowl 2027 competition data on Kaggle; source link in README. The precise vendor speed definition should be checked against the data dictionary before submission. |
| What is the question? | Can recent tracked speed predict the next second of a WR's Combine gauntlet attempt? The target is speed, in yards/second, not separation or career success. |
| Is it a time series? | Timestamped player speed with checked 0.1-second spacing. Each attempt is a separate ordered series. No concatenation of unrelated players. |
| Enough observations for training and test? | Every eligible attempt has at least 80 frames: fit frames 1-60, test 61-70; for the final example, refit on 1-70 and forecast 71-80. |
| Scope and replication? | 2023: 69 attempts, 38 players. 2024: 58 attempts, 31 players. 2023 selects the method; 2024 evaluates it. Frames are correlated, so the sample size is not thousands of independent trials. |

## Task 2: import, prepare, and explore

| Question / requirement | Evidence and assessment |
| --- | --- |
| Complete and usable data? | `attempt_audit.csv` checks frame counts, unique timestamps, regular sampling, and finite nonnegative speeds. `cohort_summary.csv` gives retained counts. All 127 candidate attempts pass these checks. |
| Appropriate filtering? | WRs, PLAYER entities only, GAUNTLET_DRILL, 2023/2024. Ball rows and 2025 are excluded. Player IDs are unique in the lookup; classes do not share players. |
| Labeled time-series plot? | `plots/01_example_speed.png`: elapsed seconds and speed in yards/second, with forecasting boundaries. |
| Correlogram? | `plots/02_training_acf.png` and `example_training_acf.csv`, computed on the first 60 example frames. |
| Trend? | Rome Odunze's training speed starts at 0.160 yd/s, reaches 8.637 at 5.2 seconds, and ends at 8.437 at 5.9 seconds. This is acceleration followed by leveling/early slowing, not one constant linear trend. |
| Autocorrelation? | Lag-one training ACF is 0.966. Adjacent speeds are strongly related; smooth motion, changing level, and the vendor filter can all contribute. |
| Seasonal? | No repeating seasonal period is established by a single short drill. The models are nonseasonal. Do not set frequency to 10 and call it seasonality: 10 is the sampling rate, not a demonstrated cycle length. |
| Cyclical? | The curve changes direction, but one peak is not evidence of a recurring cycle. The records are too short to infer a stable long cycle. |

## Task 3: choose and evaluate at least two methods

| Method | Why it is included |
| --- | --- |
| SES / ETS(A,N,N) | Level-only reference: appropriate if recent speed is approximately steady. It can lag acceleration/deceleration. |
| Holt / ETS(A,A,N) | Recent speed has a changing slope; extrapolating the local trend may improve a one-second forecast. |
| Damped Holt / ETS(A,Ad,N) | A speed trend cannot continue indefinitely; damping reduces its future influence. |
| Naive | Constant-speed benchmark using the final observed frame. It checks whether smoothing/trend estimation adds value. |

At least two of these are from the assignment's suggested families. All methods
fit parameters only to each attempt's first 60 frames. 2024 is not used to choose
the winning method. Exploration of 2023 was used to develop this design, so it is
not an untouched validation set.

For **each** method, the following outputs exist:

- Residual time series, histogram, residual ACF, and extra normal Q-Q plot:
  `plots/03_residuals_<method>.png`.
- Test forecast alongside actual values: `plots/04_one_second_test_<method>.png`.
- MAE, RMSE, mean error, and interval coverage on the example:
  `example_test_accuracy.csv`.
- Class-wide errors: `model_comparison.csv`. Attempts are averaged within player
  before averaging players. These are distinct from one player's example.
- Fitted parameters: `example_training_parameters.csv`. The naive method has no
  smoothing parameters. Updated final-model parameters are in `final_model_parameters.csv`.

### Parameter interpretation evidence

For the initial Rome Odunze example:

| Method | Alpha | Beta | Phi |
| --- | ---: | ---: | ---: |
| SES | 0.9999 | Not used | Not used |
| Holt | 0.9999 | 0.8560 | Not used |
| Damped Holt | 0.9999 | 0.9999 | 0.9472 |

Alpha near one means the level responds strongly to the newest observation.
Beta controls trend updating; phi below one attenuates the trend at future
horizons. `l` and `b` in the output are fitted **initial** states, not the final
speed and slope. A slope is per frame; converting to a per-second rate requires
dividing by 0.1 seconds. Model trend is not a validated physical acceleration.

## Task 4: compare methods and justify a choice

### What do the residual plots tell us?

For the initial example, SES has mean residual +0.138 yd/s and lag-one residual
ACF 0.953: it underpredicts the rising training signal and leaves strong structure.
Holt reduces mean residual to +0.003 and lag-one ACF to 0.534. Damped Holt gives
+0.007 and 0.476, respectively. Trend models remove much of the systematic lag.

That does **not** mean all residual assumptions hold. Holt still has substantial
autocorrelation, early large residuals, and a right-skewed histogram/upper-tail
departure in the Q-Q plot. Its unadjusted Ljung-Box p-value is about 0.000246.
Damped Holt's is about 0.00683. These screening results support discussing
remaining model inadequacy, not claiming independent normal errors.

### How do the different errors compare?

| Class | Method | MAE (yd/s) | RMSE (yd/s) |
| --- | --- | ---: | ---: |
| 2023 development | Holt | 0.301 | 0.488 |
| 2023 development | Damped Holt | 0.316 | 0.512 |
| 2023 development | Naive | 0.477 | 0.694 |
| 2023 development | SES | 0.477 | 0.694 |
| 2024 evaluation | Damped Holt | 0.185 | 0.311 |
| 2024 evaluation | Holt | 0.187 | 0.324 |
| 2024 evaluation | Naive | 0.237 | 0.361 |
| 2024 evaluation | SES | 0.237 | 0.361 |

MAE and RMSE agree on the ordering within each class. Holt is best in development;
damped Holt is slightly better in the later class. Thus there is no universal
winner across classes. Mean error measures bias rather than total accuracy:
all four methods overpredict on average in the 2024 test windows. Interval
coverage measures something different again; a broad interval can have good
coverage while the point forecast is poor.

### Which method is selected, and why?

Holt stays selected because it had the lowest development MAE and RMSE, its
trend structure is plausible over this short horizon, and its example residuals
are less biased/structured than SES's. Selection is not changed after examining
2024. Residual dependence and the later-class ranking difference limit the claim.

Holt's 2024 MAE is about 21% below naive. The paired player bootstrap gives a
Holt-minus-naive MAE difference of -0.0494 yd/s, with a percentile 95% interval
of approximately [-0.1004, -0.0026]. This is conditional on this cohort and fixed
protocol, not proof of improvement for every player or drill.

## Task 5: final forecast

| Requirement | Evidence and assessment |
| --- | --- |
| Select a method using the comparison? | Holt, selected using 2023 as described above. |
| Approximately ten steps? | Exactly ten frames, 71-80, one second ahead from frame 70 (6.9 seconds). No fit uses these future frames. |
| Forecast along with observed data? | `plots/06_final_ten_frame_forecast.png` shows recent observed history, forecast, and subsequent actual values; plot 01 shows the full 80-frame example context. |
| Uncertainty intervals? | 80% and 95% prediction bands are plotted and exported. Prediction intervals are the appropriate bands for future observations; they are not parameter confidence intervals. |
| Labels and title? | Elapsed seconds, tracked speed in yards/second, athlete, selected model, legend, and forecast boundary are visible. |
| What happened? | The updated forecast declines from 7.683 to 7.053 yd/s. Actual speed declines from 7.663 to 7.000 yd/s. Example MAE is 0.0751 yd/s, RMSE 0.0794. |

This is a retrospective forecast from inside a recorded attempt. It is not a
prediction beyond the end of the record or from today's date.

## Task 6: questions the written report must address

The following are evidence and decision prompts to incorporate in your own work,
not a completed report.

| Report question | Evidence / points to address |
| --- | --- |
| Source of data? | Identify the NFL Big Data Bowl 2027 Kaggle source, local tables, years, position, drill, sampling, units, and cohort sizes. |
| Why interesting or important to forecast? | Tests whether recent motion trends improve a near-term movement baseline. Helps the larger project understand temporal predictability before building more elaborate braking features. |
| What do the data plots mean for forecasting? | Strong persistence and changing speed favor short-horizon trend methods; no established seasonal/cyclic repetition; discuss Task 2 evidence. |
| Why these methods? | Contrast level-only, local trend, damped trend, and constant-speed assumptions. Explain the parameter meanings above. |
| Residual plots and interpretations? | Include and interpret at least the two main methods; discuss reduced bias but remaining autocorrelation, early large errors, and skew. Do not claim a clean residual diagnostic. |
| What do accuracy measures teach us? | Explain MAE versus RMSE versus bias/coverage; use the class comparison and distinguish it from the one-athlete illustration. |
| What is the final forecast? | Include plot 06, the ten-step horizon, forecast origin, updated fit, and predicted slowing. |
| How confident, and why? | The example is accurate, but one attempt cannot establish reliability. Holt's 2024 95% bands cover about 99.2% of test points, versus 89.5% in 2023. Calibration differs by class. Bands widen rapidly, residuals are dependent, and the vendor filter is undocumented. |
| What decisions could this help make? | Whether a trend-based motion baseline is worth using instead of constant speed; whether to investigate deviations from baseline during later movement analysis. It does not support drafting, injury, or coaching decisions about an athlete by itself. |
| What additional data would improve it? | More athletes/classes and repeated attempts; raw timestamps/positions with filter documentation; consistent drill phase/onset labels; route/catch/braking event labels; later in-game movement for transfer testing. Use causal preprocessing if testing a live forecast. |

**Required format still outstanding:** an organized, word-processed document for
a reader familiar with forecasting methods, containing the chosen plots and
student-written explanations. An R script, README, or checklist alone does not
satisfy this product.

## Task 7: presentation

Each group member must independently prepare slides and a 5-7 minute presentation,
sign up for an appointment, and present one-on-one to the instructor. These
activities cannot be marked complete by running the analysis. Be ready to explain
the target, time step, split, methods, errors, residual shortcomings, and final
forecast without reading the script aloud.

## Verification and remaining actions

- Revised path resolution works with the relocated nested dataset layout.
- End-to-end R execution regenerates the outputs and passes the assertions.
- Added numerical ACF, exploration, example-specific errors, final-model
  parameters, and final-example error/coverage tables.
- Original model choices, split, example-selection rule, and reported class
  results are unchanged by this audit.
- Still required: instructor's scope clarification if needed, student-authored
  report, each member's slides, presentation booking and delivery, and verification
  of the current deadline and permitted code assistance.
