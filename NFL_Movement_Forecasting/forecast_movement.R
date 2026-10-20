# MTH305: Can we forecast receiver speed one second ahead?
# Forecast vendor-reported speed in the Combine gauntlet, not future NFL success.
# 2023 chooses the method. 2024 evaluates that choice. 2025 is excluded.

required <- c("data.table", "forecast")
for (pkg in required) if (!requireNamespace(pkg, quietly = TRUE)) {
  stop("Run install.packages(c('data.table', 'forecast')) first.")
}
suppressPackageStartupMessages(library(data.table))
DATA_DIR <- "C:/Users/Kelvin/Downloads/nfl-big-data-bowl-2027/nfl-big-data-bowl-2027"
OUT <- "C:/Users/Kelvin/Downloads/NFL_Movement_Forecasting/output"
dir.create(file.path(OUT, "plots"), recursive = TRUE, showWarnings = FALSE)
N_TRAIN <- 60L
H <- 10L
METHODS <- c("SES", "Holt", "Damped_Holt", "Naive")
COLORS <- c(SES = "#7c3aed", Holt = "#2563eb", Damped_Holt = "#0f766e", Naive = "#b45309")
save_csv <- function(d, name) fwrite(d, file.path(OUT, paste0(name, ".csv")))
figure <- function(name, draw, height = 1000L) {
  png(file.path(OUT, "plots", paste0(name, ".png")), width = 1600, height = height, res = 150)
  on.exit(dev.off())
  par(mar = c(5, 5, 4, 1), las = 1, family = "sans", col.main = "#172554")
  draw()
}

# ---- Import and QA: only the 84 MB Combine tracking table and player lookup. ----
players <- fread(file.path(DATA_DIR, "players.csv"),
                 select = c("nfl_id", "display_name", "nfl_position"))
stopifnot(!anyDuplicated(players$nfl_id))
tracking <- fread(file.path(DATA_DIR, "combine_tracking.csv"), select = c(
  "draft_year", "event_id", "nfl_id", "entity_type", "time", "drill_name", "attempt", "s"))
tracking <- tracking[draft_year %in% c(2023L, 2024L) & entity_type == "PLAYER" &
  drill_name == "GAUNTLET_DRILL" & nfl_id %in% players[nfl_position == "WR", nfl_id]]
tracking <- merge(tracking, players[, .(nfl_id, display_name)], by = "nfl_id")
if (!inherits(tracking$time, "POSIXct")) {
  tracking[, time := as.POSIXct(time, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")]
}
setorder(tracking, draft_year, nfl_id, event_id, attempt, time)
tracking[, rep_id := .GRP, by = .(draft_year, nfl_id, event_id, attempt)]
tracking[, frame := seq_len(.N), by = rep_id]
tracking[, elapsed := as.numeric(difftime(time, time[1], units = "secs")), by = rep_id]

# Require 80 frames for the 60->70 test and the subsequent 70->80 forecast.
# Only metadata/timestamp completeness is used to choose attempts; no selection
# of an athlete or attempt based on forecast error or a visually appealing curve.
qa <- tracking[, .(draft_year = draft_year[1], nfl_id = nfl_id[1],
  display_name = display_name[1], event_id = event_id[1], attempt = attempt[1],
  n_frames = .N, unique_timestamps = !anyDuplicated(time),
  regular_10hz = !anyNA(time) && all(abs(diff(as.numeric(time)) - 0.1) < 0.001),
  valid_speed = all(is.finite(s) & s >= 0)), by = rep_id]
qa[, eligible := n_frames >= N_TRAIN + 2L * H & unique_timestamps & regular_10hz & valid_speed]
save_csv(qa, "attempt_audit")
tracking <- tracking[rep_id %in% qa[eligible == TRUE, rep_id]]
cohort <- qa[eligible == TRUE, .(attempts = .N, players = uniqueN(nfl_id),
  min_frames = min(n_frames), max_frames = max(n_frames)), by = draft_year]
save_csv(cohort, "cohort_summary")
stopifnot(all(c(2023L, 2024L) %in% tracking$draft_year))
stopifnot(length(intersect(unique(tracking[draft_year == 2023, nfl_id]),
                          unique(tracking[draft_year == 2024, nfl_id]))) == 0)

# Nonseasonal models. frequency=1 here means one MODEL step per frame.
# All figures convert frame index to elapsed seconds explicitly.
# No centered smoothing or full-trajectory feature extraction is performed.
fit_one <- function(y, method) {
  y <- ts(y, frequency = 1)
  switch(method,
    SES = forecast::ets(y, model = "ANN", damped = FALSE),
    Holt = forecast::ets(y, model = "AAN", damped = FALSE),
    Damped_Holt = forecast::ets(y, model = "AAN", damped = TRUE),
    Naive = forecast::naive(y, h = H, level = c(80, 95)))
}
predict_one <- function(fit) {
  if (inherits(fit, "forecast")) fit else forecast::forecast(fit, h = H, level = c(80, 95))
}
score <- function(actual, pred) c(MAE = mean(abs(actual - pred)),
  MSE = mean((actual - pred)^2), ME = mean(actual - pred))

# Each attempt is an independent model fit: do not concatenate different drills.
# Equal-player summaries average attempts within a player before averaging players.
all_predictions <- list()
all_scores <- list()
for (id in unique(tracking$rep_id)) {
  d <- tracking[rep_id == id]
  for (method in METHODS) {
    fit <- fit_one(d$s[seq_len(N_TRAIN)], method)
    fc <- predict_one(fit)
    actual <- d$s[N_TRAIN + seq_len(H)]
    errors <- score(actual, as.numeric(fc$mean))
    all_scores[[length(all_scores) + 1L]] <- data.table(
      rep_id = id, draft_year = d$draft_year[1], nfl_id = d$nfl_id[1], method = method,
      MAE = errors["MAE"], MSE = errors["MSE"], ME = errors["ME"],
      coverage_80 = mean(actual >= fc$lower[, 1] & actual <= fc$upper[, 1]),
      coverage_95 = mean(actual >= fc$lower[, 2] & actual <= fc$upper[, 2]))
    all_predictions[[length(all_predictions) + 1L]] <- data.table(
      rep_id = id, draft_year = d$draft_year[1], nfl_id = d$nfl_id[1], method = method,
      horizon = seq_len(H), elapsed = d$elapsed[N_TRAIN + seq_len(H)], actual = actual,
      predicted = as.numeric(fc$mean), lower_80 = as.numeric(fc$lower[, 1]),
      upper_80 = as.numeric(fc$upper[, 1]), lower_95 = as.numeric(fc$lower[, 2]),
      upper_95 = as.numeric(fc$upper[, 2]))
  }
}
scores <- rbindlist(all_scores)
predictions <- rbindlist(all_predictions)
player_scores <- scores[, lapply(.SD, mean), by = .(draft_year, nfl_id, method),
  .SDcols = c("MAE", "MSE", "ME", "coverage_80", "coverage_95")]
summary <- player_scores[, .(players = .N, MAE = mean(MAE), RMSE = sqrt(mean(MSE)),
  ME = mean(ME), coverage_80 = mean(coverage_80), coverage_95 = mean(coverage_95)),
  by = .(draft_year, method)]
setorder(summary, draft_year, MAE)
# Selection uses 2023 ONLY, even though the loop also computes the fixed 2024 tests.
chosen <- summary[draft_year == 2023][order(MAE, RMSE), method[1]]
save_csv(scores, "attempt_accuracy")
save_csv(player_scores, "player_accuracy")
save_csv(summary, "model_comparison")
save_csv(predictions, "predictions_60_to_70")

# Paired player bootstrap: uncertainty in chosen-vs-naive difference on 2024.
# Resample players, not correlated frames or repeated attempts.
paired <- dcast(player_scores[draft_year == 2024 & method %in% c(chosen, "Naive")],
                nfl_id ~ method, value.var = "MAE")
if (chosen != "Naive") {
  delta <- paired[[chosen]] - paired[["Naive"]]
  set.seed(305)
  boot <- replicate(2000L, mean(sample(delta, length(delta), replace = TRUE)))
  comparison <- data.table(comparison = paste(chosen, "minus Naive; negative is better"),
    difference_MAE = mean(delta), lower_95 = unname(quantile(boot, .025)),
    upper_95 = unname(quantile(boot, .975)), players = length(delta))
  save_csv(comparison, "heldout_player_bootstrap")
}

# Predefined example: smallest eligible 2024 nfl_id, then earliest timestamp.
# This rule does not select the prettiest or most accurate forecast.
example_id <- tracking[draft_year == 2024][order(nfl_id, time), rep_id[1]]
d <- tracking[rep_id == example_id]
save_csv(d[, .(frame, elapsed, s, display_name, draft_year, event_id, attempt)], "example_trajectory")
example_name <- paste(d$display_name[1], "- gauntlet attempt", d$attempt[1])
train <- d$s[seq_len(N_TRAIN)]
future_idx <- N_TRAIN + seq_len(H)
fits <- setNames(lapply(METHODS, function(m) fit_one(train, m)), METHODS)
params <- rbindlist(lapply(METHODS, function(m) {
  p <- fits[[m]]$par
  if (is.null(p)) return(NULL)
  data.table(method = m, parameter = names(p), estimate = as.numeric(p))
}))
save_csv(params, "example_training_parameters")

figure("01_example_speed", function() {
  plot(d$elapsed[1:80], d$s[1:80], type = "l", lwd = 2, col = "#172554",
       xlab = "Seconds since first recorded frame", ylab = "Tracked speed (yards/second)",
       main = paste("Forecasting the next second:", example_name))
  abline(v = c(5.9, 6.9), lty = 2, col = c("#2563eb", "#0f766e"))
  legend("topleft", c("Observed speed", "Initial forecast origin: 5.9 s", "Updated origin: 6.9 s"),
         col = c("#172554", "#2563eb", "#0f766e"), lty = c(1, 2, 2), bty = "n", cex = .8)
})
figure("02_training_acf", function() {
  acf(train, lag.max = 20L, main = paste("Training speed ACF:", d$display_name[1]),
      xlab = "Lag in frames (10 frames = 1 second)", col = "#2563eb", lwd = 2)
  mtext("Smooth motion and acceleration can cause persistent ACF; this is not evidence of seasonality.",
        side = 1, line = 3.6, cex = .75)
})

diagnostics <- list()
for (m in METHODS) {
  res <- as.numeric(residuals(fits[[m]]))
  good <- res[is.finite(res)]
  lb <- Box.test(good, lag = 10L, type = "Ljung-Box", fitdf = 0)
  diagnostics[[m]] <- data.table(method = m, mean_residual = mean(good),
    lag = 10L, unadjusted_ljung_box_p = unname(lb$p.value))
  figure(paste0("03_residuals_", m), function() {
    par(mfrow = c(2, 2), mar = c(4.5, 4.5, 3, 1))
    plot(d$elapsed[seq_along(res)], res, type = "l", col = COLORS[m], lwd = 2,
         xlab = "Elapsed seconds", ylab = "Residual (yards/second)", main = paste(m, "training residuals"))
    abline(h = 0, lty = 2)
    hist(good, breaks = "Sturges", col = "#bfdbfe", border = "white",
         xlab = "Residual (yards/second)", main = "Residual histogram")
    acf(good, lag.max = 20L, main = "Residual ACF", xlab = "Lag in frames", col = COLORS[m])
    qqnorm(good, col = COLORS[m], pch = 16, main = "Normal Q-Q: interval assumption check")
    qqline(good, col = "#b45309", lwd = 2)
  }, height = 1200L)
}
save_csv(rbindlist(diagnostics), "example_residual_diagnostics")

draw_prediction <- function(fc, origin, heading) {
  xx <- d$elapsed[origin + seq_len(H)]
  shown <- seq.int(max(1L, origin - 29L), origin + H)
  plot(d$elapsed[shown], d$s[shown], type = "n", ylim = range(c(d$s[shown], fc$lower, fc$upper)),
       xlab = "Seconds since first recorded frame", ylab = "Tracked speed (yards/second)", main = heading)
  polygon(c(xx, rev(xx)), c(fc$lower[, 2], rev(fc$upper[, 2])), col = "#dbeafe", border = NA)
  polygon(c(xx, rev(xx)), c(fc$lower[, 1], rev(fc$upper[, 1])), col = "#93c5fd", border = NA)
  past <- shown[shown <= origin]
  lines(d$elapsed[past], d$s[past], lwd = 2, col = "#172554")
  lines(xx, fc$mean, lwd = 2.5, col = "#2563eb")
  lines(xx, d$s[origin + seq_len(H)], type = "o", pch = 16, lwd = 2, col = "#b45309")
  abline(v = d$elapsed[origin], lty = 2, col = "#64748b")
  legend("bottomleft", c("Observed history", "Forecast", "Held-out actual", "80% / 95% model bands"),
         col = c("#172554", "#2563eb", "#b45309", "#93c5fd"),
         lty = c(1, 1, 1, NA), pch = c(NA, NA, 16, 15), bty = "n", cex = .8)
}
for (m in METHODS) figure(paste0("04_one_second_test_", m), function() {
  draw_prediction(predict_one(fits[[m]]), N_TRAIN, paste(d$display_name[1], "-", m, "- next second"))
})
figure("05_class_comparison", function() {
  par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
  for (yr in c(2023L, 2024L)) {
    z <- summary[draft_year == yr][match(METHODS, method)]
    bp <- barplot(z$MAE, names.arg = gsub("_", " ", z$method), col = COLORS[z$method],
       ylim = c(0, max(summary$MAE) * 1.25), cex.names = .75,
       ylab = "Equal-player MAE (yards/second)",
       main = if (yr == 2023) "2023: choose the method" else "2024: independent class test")
    text(bp, z$MAE, sprintf("%.3f", z$MAE), pos = 3)
  }
})

# ---- Assignment's final 10-step forecast: update with ten new observations. ----
# The chosen method is locked using 2023. Refit parameters using frames 1:70.
# Forecast 71:80, all still inside the recorded attempt; do not extrapolate
# beyond the drill's end. Actual 71:80 are used only for this retrospective check.
final_fit <- fit_one(d$s[1:70], chosen)
final_fc <- predict_one(final_fit)
final <- data.table(frame = 71:80, elapsed = d$elapsed[71:80], actual = d$s[71:80],
  forecast = as.numeric(final_fc$mean), lower_80 = as.numeric(final_fc$lower[, 1]),
  upper_80 = as.numeric(final_fc$upper[, 1]), lower_95 = as.numeric(final_fc$lower[, 2]),
  upper_95 = as.numeric(final_fc$upper[, 2]))
save_csv(final, "final_ten_frame_forecast")
figure("06_final_ten_frame_forecast", function() {
  draw_prediction(final_fc, 70L, paste(d$display_name[1], "- updated one-second forecast -", chosen))
})

# Horizon error curve aggregates attempts within player before averaging players.
hp <- predictions[, .(absolute_error = mean(abs(actual - predicted))),
                   by = .(draft_year, nfl_id, method, horizon)]
hc <- hp[, .(MAE = mean(absolute_error)), by = .(draft_year, method, horizon)]
save_csv(hc, "error_by_horizon")
figure("07_error_by_horizon", function() {
  z <- hc[draft_year == 2024]
  plot(c(.1, 1), range(c(0, z$MAE)), type = "n", xlab = "Seconds ahead",
       ylab = "Equal-player MAE (yards/second)", main = "2024: how forecast error changes with horizon")
  for (m in METHODS) { v <- z[method == m][order(horizon)]; lines(v$horizon / 10, v$MAE, col = COLORS[m], lwd = 2) }
  legend("topleft", gsub("_", " ", METHODS), col = COLORS, lty = 1, lwd = 2, bty = "n")
})

capture.output({
  cat("Question: predict tracked WR speed for the next second of a gauntlet attempt.\n")
  cat("No game tracking loaded; no 2025 outcomes used.\n\nCOHORT\n"); print(cohort)
  cat("\nMETHOD COMPARISON: equal player weighting\n"); print(summary)
  cat("\nSelected using 2023 MAE only:", chosen, "\n")
  if (exists("comparison")) { cat("\n2024 PAIRED PLAYER BOOTSTRAP\n"); print(comparison) }
  cat("\nEXAMPLE:", example_name, "\nRule: smallest 2024 player ID, then earliest attempt.\n")
  cat("\nEXAMPLE TRAINING PARAMETERS\n"); print(params)
  cat("\nEXAMPLE RESIDUAL DIAGNOSTICS (unadjusted screening p-values)\n"); print(rbindlist(diagnostics))
  cat("\nFINAL UPDATED MODEL\n"); print(final_fit)
  cat("\nFINAL TEN FRAME FORECAST\n"); print(final)
  cat("\nFinal example MAE:", mean(abs(final$actual - final$forecast)), "yards/second\n")
  cat("\nInterpretation limits:\n",
      "Vendor speed is already smoothed; its unknown filter may use future positions.\n",
      "This is retrospective forecasting of the supplied signal, not a validated live system.\n",
      "Models can miss abrupt motion changes. Check empirical interval coverage.\n",
      "Fixed frame 60 is time from clip start, not an aligned football action.\n",
      "An 8-second drill is not a calendar-season time series; no seasonal model is justified.\n",
      "Repeated attempts belong to the same player; summaries and bootstrap respect that.\n",
      "This does not show a relationship between Combine traits and NFL game performance.\n")
}, file = file.path(OUT, "results.txt"))
capture.output(sessionInfo(), file = file.path(OUT, "session_info.txt"))
stopifnot(nrow(final) == H, all(is.finite(final$forecast)),
  all(final$lower_95 <= final$lower_80), all(final$lower_80 <= final$forecast),
  all(final$forecast <= final$upper_80), all(final$upper_80 <= final$upper_95),
  nrow(predictions) == nrow(qa[eligible == TRUE]) * length(METHODS) * H)
cat("Selected on 2023:", chosen, "\n")
print(summary)
cat("Saved outputs to", OUT, "\n")
