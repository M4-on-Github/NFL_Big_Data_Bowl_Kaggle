# One second ahead: a time-series study of Rome Odunze

**Main question:** After observing the first six seconds of Rome Odunze's first
recorded 2024 gauntlet attempt, how accurately can we forecast his speed for the
next second?

## Main investigation: one continuous series

The main dataset is **one player and one attempt**, with speed measured every
0.1 seconds. We never concatenate different players or attempts. Use
`output/primary_time_series.csv` to see the exact 80 observations and their roles.

| Part | Frames | Elapsed time | Purpose |
| --- | --- | --- | --- |
| Training | 1-60 | 0.0-5.9 seconds | Fit SES, Holt, damped Holt, and naive |
| Initial test | 61-70 | 6.0-6.9 seconds | Compare the methods on the same next ten observations |
| Updated fit | 1-70 | 0.0-6.9 seconds | Incorporate the newly observed test block |
| Final forecast/check | 71-80 | 7.0-7.9 seconds | Forecast another ten observations with intervals |

This attempt contains additional frames after frame 80; they are outside the
predefined main analysis window. No rows from another attempt enter these fits.
Rome was selected by the earlier deterministic ID/time rule, not by searching
for a low error. We are changing the emphasis after examining results, not
claiming this single-case study was newly preregistered.

Start with `output/PRIMARY_RESULTS.txt`. The main story follows these outputs:

1. `plots/01_example_speed.png`: the time series and forecast boundaries.
2. `plots/02_training_acf.png`: its training correlogram.
3. `plots/03_residuals_<method>.png`: residual diagnostics for each method.
4. `plots/04_one_second_test_<method>.png`: initial test forecasts versus actuals.
5. `plots/05_primary_model_comparison.png` and `example_test_accuracy.csv`:
   compare errors for this same attempt, not class averages.
6. `plots/06_final_ten_frame_forecast.png`: the updated final forecast.

Holt has the lowest initial test MAE (0.153 yd/s) and RMSE (0.192 yd/s) in this
attempt. It is also the method already selected using 2023, so no method change
is made. Its final updated forecast has MAE 0.075 yd/s. These are two distinct
forecast windows; do not confuse either with a class-wide average.

## Supplement: does the result hold for other players?

Use `output/SUPPLEMENTARY_RESULTS.txt` and `supplementary_other_players.csv` only
after explaining the main time series. These exclude **both of Rome's attempts**:
2023 contributes 38 other players/69 attempts; 2024 contributes 30 other players/
56 attempts. Every attempt still receives its own fitted model. Errors, not raw
time-series measurements, are summarized across players.

The original full-cohort tables and plot 05_class_comparison are preserved for
reproducibility and include Rome. Do not label those older full-cohort outputs as
the new other-player-only check. The supplementary data were already examined;
they are not a new untouched test set.

This replaces the weekly separation idea with a movement forecasting question.
The target is speed in yards/second, sampled every 0.1 seconds. Ten forecast steps
are one second. Each attempt is its own continuous series; different athletes or
attempts are never joined end-to-end.

## Run in RStudio

From a terminal in this folder: `Rscript forecast_movement.R`.

Open `forecast_movement.R` and click **Source**. Packages `data.table` and
`forecast` are required and already installed on Kelvin's machine. The script
locates itself and resolves the data folder relative to the repository, so it
works after moving the repository and does not require `setwd()`.
It checks `nfl-big-data-bowl-2027/nfl-big-data-bowl-2027` first, followed by the
single-level data folder, `data/raw`, and the repository root.

For a nonstandard layout, set `NFL_DATA_DIR` before sourcing, for example
`Sys.setenv(NFL_DATA_DIR = "D:/my_data")`. `NFL_FORECAST_OUTPUT` can override the
output directory. Otherwise outputs are always saved beside this script.

**Read `ASSIGNMENT_AUDIT.md` for the question-by-question audit and verified
interpretation evidence.** Code and figures are complete; the written report,
individual slides, and oral presentation are separate outstanding deliverables.

Outputs appear in `output/`; plots are in `output/plots/`. The script loads the
84 MB Combine tracking file and a player lookup, not the large NFL game files.
It preserves the previous forecasting project in its own folder.

## Why this is a more concrete question

Receivers accelerate, hold speed, and slow down during a drill. A short-horizon
forecast asks whether the recent movement trend continues. A flat-speed forecast
is a natural benchmark. Forecast errors can motivate later work on movement
transitions and braking, but error alone is not a validated braking measure or
an athlete quality score.

This contributes an evaluated movement baseline and clean attempt extraction to
the larger project. It does not yet link Combine movement with NFL performance.

## Original development and evaluation protocol (preserved)

1. Keep WR player rows from `GAUNTLET_DRILL` in 2023 and 2024.
2. Require at least 80 frames, unique and regular 0.1-second timestamps, and finite
   nonnegative speeds. No extra smoothing is applied. Save an audit of every attempt.
3. Within each attempt, fit to frames 1-60 (0.0-5.9 seconds), then forecast frames
   61-70 (6.0-6.9 seconds). The horizon is 0.1-1.0 seconds from the forecast origin.
4. Compare SES, Holt, damped Holt, and a naive constant-speed forecast. All are
   nonseasonal and fit parameters separately to each attempt's first 60 frames.
5. Select the method with lowest equal-player MAE in **2023**. This class was used
   for exploratory pilot work and is development data, not an untouched test set.
6. Evaluate the fixed methods on **2024**, a different class with no player overlap.
   Do not switch the selected method because another one wins in 2024. Average
   errors within player before averaging players, so repeated attempts do not give
   an athlete extra weight. A paired player bootstrap compares the chosen method
   with the naive benchmark on 2024; it resamples players, not individual frames.
7. Display a preselected example: the smallest eligible 2024 player ID, earliest
   attempt. This is Rome Odunze; he was not chosen because of forecast accuracy.
8. For the final ten-step forecast, refit the selected method to example frames
   1-70 and forecast 71-80. Show the held-out actual values for a retrospective
   check. The forecast stays inside the recorded drill, rather than predicting
   continued movement after the drill ends.

All models can produce implausible values in some circumstances; intervals are
left unmodified rather than clipped to make them look better. Inspect coverage
and residuals before trusting them.

## What the methods mean

- **SES:** a smoothed estimate of the current speed, with no trend extrapolation.
- **Holt:** updates speed level and its recent slope, then extrapolates that slope.
- **Damped Holt:** reduces the influence of the slope farther into the future.
- **Naive:** keeps speed at its last observed value for all ten future frames.

Holt's slope is in yards/second per frame, not directly yards/second squared.
Divide a per-frame slope by 0.1 seconds to express a rate per second. The estimated
trend is a model state, not necessarily a physical acceleration measurement.

MAE is the average absolute error in yards/second; RMSE emphasizes larger errors.
ME is actual minus forecast, so positive means underprediction. The class-level
RMSE is the square root of the mean player-level mean squared error.

The bands are 80% and 95% model-based prediction intervals. They are not confidence
intervals for athlete ability. Empirical test coverage in `model_comparison.csv`
shows whether the model's nominal uncertainty is credible in these data.

## Mapping to Siopsis's assignment

| Requirement | Output | Your interpretation task |
| --- | --- | --- |
| Credible source, a time series, training/test split | Protocol above; `attempt_audit.csv`, `cohort_summary.csv` | Explain speed, units, sampling, selection, and why one second matters |
| Time-series plot and correlogram | Plots 01 and 02 | Describe acceleration, persistence, and the lack of evidence for seasonality |
| At least two forecasting methods and fitted parameters | Four methods; `example_training_parameters.csv` | Explain level, slope, smoothing, damping, and initial states |
| Residual time plots, histograms, and residual ACFs | Four plot-03 panels | Look for bias, dependence, changing variance, and outliers |
| Forecast-versus-test plots and multiple accuracy measures | Four plot-04 figures; `example_test_accuracy.csv` | Compare errors and uncertainty for the one primary attempt |
| Model comparison and selection | Plot `05_primary_model_comparison`; earlier 2023 choice retained | Explain why Holt is supported in this attempt; discuss other-player evidence separately |
| Ten-step forecast with intervals | Plot 06; `final_ten_frame_forecast.csv` | Explain the updated forecast, actual outcome, interval width, and any miss |
| Written report and individual presentation | Numerical results and figures are supplied | Write your own interpretation and prepare your own presentation |

There is a legitimate course-fit caveat: this is a high-frequency physical time
series lasting seconds, not years of monthly data. The PDF gives monthly/annual
examples but does not explicitly require those frequencies. It is worth confirming
that the instructor accepts this interpretation. More frames do not mean many
independent observations, so repeated-attempt evaluation is essential.

## Limitations to discuss honestly

- The vendor's `s` is smoothed with an undocumented filter. Even though this code
  uses only earlier frames for fitting, the supplied signal may itself include
  information from later positions. This is a retrospective benchmark, not proof
  of deployable real-time performance.
- A fixed six-second origin is relative to the first recorded frame, not a common
  acceleration, catch, or braking event. Different clips can be in different phases.
- Strong speed ACF can arise from smooth, nonstationary motion and vendor filtering.
  It does not establish seasonality or validate independent forecast errors.
- Simple models can understate uncertainty or miss sudden motion changes. Report
  actual interval coverage even if it looks poor. Ljung-Box p-values in the example
  are unadjusted screening diagnostics and should not be treated as definitive.
- The gauntlet is one drill. Results do not automatically generalize to routes,
  in-game movement, prospects' ability, or future NFL performance.
- 2023 was exploratory development data; 2024 is a single class evaluation. 2025
  is excluded. Avoid repeatedly tuning methods against 2024 after seeing results.

## Sources

- Local data (relative to repository): `nfl-big-data-bowl-2027/nfl-big-data-bowl-2027`
- Competition: https://www.kaggle.com/competitions/nfl-big-data-bowl-2027
- Project plan: https://github.com/M4-on-Github/NFL_Big_Data_Bowl_Kaggle/blob/claude/dreamy-brahmagupta-yuzl00/plan.md
- Assignment: `Project 2026.pdf` (course handout, obtained separately)

Use the class's AI-use rules for code assistance and attribution. This package
contains code and analysis aids, not a submission-ready written report or slides.
All outputs stay local; no data or submission is published.
