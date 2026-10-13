# NFL Big Data Bowl 2027 — Project Plan

Status: draft v1, 2026-10-13. Deadline: **2027-01-06 23:59 UTC** (12 weeks from today).

Source labelling used throughout:

- **VERIFIED** — stated on the Kaggle competition pages or by the host, as transcribed by multiple participant repositories / search snippets (kaggle.com was not directly reachable when this plan was written).
- **INFERRED** — derived from participant audits, prior Big Data Bowls, or our own reasoning. Treat as a hypothesis until checked against the data.
- Section 12 lists everything that must be re-checked on Kaggle once logged in.

---

## 1. What the competition actually is

**VERIFIED**

- BDB 2027 is a **judged analytics hackathon only**. There is no prediction track, no leaderboard, no metric, no `submission.csv` (host Tom Bliss, discussion 746521).
- The task: build an analytical framework that finds **non-obvious, actionable links between 10 Hz NFL Scouting Combine tracking data and future regular-season NFL game performance**. First BDB to pair Combine tracking with in-game tracking.
- Deliverable: a **Kaggle Writeup** with an attached **public notebook** and a **Media Gallery cover image**.
  - Body: **≤ 2,000 words** and **fewer than 10 tables + figures combined**. Appendix and notebook are excluded from the limits.
  - One submission per team; teams up to 5; team-merge deadline = final deadline.
  - Drafts, private notebooks and forum posts do not count as submissions.
  - External data allowed if public and free/low-cost. Winners must release under an OSI licence. Data is CC BY-NC 4.0 — do not redistribute.
- Timeline: launched 2026-10-06; final deadline 2027-01-06 23:59 UTC; judging Jan 7–25; results ~Jan 26; finalists present in person at the 2027 Combine (Indianapolis).
- Prizes ($100k): Open Track $45k (3 × $10k finalists, 3 × $5k); University Track $45k, same split; Grand Prize $10k chosen among the 6 finalists (requires in-person presentation).
- Host guidance: **go narrow** — one aspect of movement, one position group, or one drill. Host example directions: route-running COD/deceleration vs separation; trench first step/burst vs pass rush/blocking; "drill translation" (where tracking adds value beyond the stopwatch); position mechanics (body control, pursuit angles).

**INFERRED / UNCLEAR**

- University Track eligibility: Kaggle snippet says undergraduate only; one repo says undergrad or grad. Verify before deciding which track we enter.

### Judging rubric (VERIFIED)

Two pass/fail gates, then a weighted 0–10 score per component.

| Gate | Requirement |
|---|---|
| 1 | Writeup links Combine tracking to NFL performance |
| 2 | Writeup is complete: markdown, embedded visuals, public notebook |

| Component | Weight | Judges ask |
|---|---|---|
| Football | 30% | Usable by teams week to week? Handles football complexity? Unique? |
| Data Science | 30% | Correct? Claims backed by data? Appropriate models? Innovative? |
| Writeup | 20% | Clear? Motivation defined? |
| Data Viz | 20% | Accessible, accurate, innovative? |

Judges are NFL club analytics staff and tracking vendors. Implication: **football usability and statistical honesty are 60% of the score**; a correct, boring result beats a flashy, unvalidated one, but a *null* result with no actionable payload will score poorly on Football.

---

## 2. Data inventory

**VERIFIED (schema), INFERRED (quirks, from participant audits)**

9 CSVs, ~2.31 GB raw (~394 MB zstd parquet), ~23.4M rows. Keys are snake_case; `nfl_id` is the spine; game side keyed by `(game_id, play_id, nfl_id)`, frames keyed by `time`.

| File | Rows | Grain | Key columns |
|---|---|---|---|
| `players.csv` | 510 | player | nfl_id, display_name, draft_year (2023–25), nfl_position (WR/TE/DB/OL/DL only), birth_date, college, conference, draft_round, draft_pick_within_round, draft_overall_pick (null = UDFA) |
| `combine_results.csv` | 510 | player | height, weight, hand, arm, wingspan, ten_yd_split, forty, vertical, broad, three_cone, short_shuttle, bench, ngs_athleticism, ngs_college_production, ngs_final |
| `combine_tracking.csv` | 463k | 0.1 s frame | draft_year, event_id, nfl_id, entity_type (PLAYER/BALL), time (ISO), drill_type, drill_name, attempt, x, y, s, a, dis, dir — **no `o`, no frame_id** |
| `player_career_successes.csv` | 510 | player | career off/def/ST snaps, games active/started, All-Pro 1st/2nd, Pro Bowl |
| `player_play.csv` | 314k | player × play | down/distance, formation, coverage (man/zone/type), route_ran, target, rec_yards, YAC/xYAC, EPA, WPA, play_direction, plus precomputed NGS: separation_at_pass_forward, cushion, pressure_allowed, peak_pressure_probability_allowed, sack_allowed, time_to_pressure(_allowed), player_get_off, quick_pressure, unblocked_pressure, blitzing, tackle/assist/TFL, coverage_assignment(_at_snap) |
| `games.csv` | 1,002 | game | season_type PRE/REG/POST |
| `game_tracking_{2023,2024,2025}.csv` | ~22.7M | 0.1 s frame | game_id, play_id, nfl_id, time, x, y, s, a, dis, o, dir, event |

Coordinates: x 0–120, y 0–53.3, dir 0° = +y, clockwise, 10 Hz.

Critical structural facts:

- Game tracking contains **only the 510 cohort players — no teammates, no opponents, no ball**. Pairwise quantities (separation, distance-to-defender, closing speed) **cannot** be computed from tracking; use the NGS columns in `player_play` as the in-game outcome layer.
- Combine tracking covers the 40, 3-cone, shuttle and ~55 position drills (6,310 attempts). BALL rows exist in only 551 events (WR/TE route drills).
- No QBs or RBs. Position-group sizes ~25–120.

### Data traps (INFERRED, from host notes and participant audits — each must be re-confirmed in our own QA notebook)

Kinematics
- Combine `dis` sums to ~91.5% of the x/y path length → recompute displacement from x/y.
- Tracked 40 is ~0.35 s slower than official (r ≈ 0.91); clips start in motion. Do not use the tracked 40 as "the 40".
- Vendor `s`/`a` are smoothed with an unknown filter. Re-derive from (t, x, y) with Butterworth 1.5–2.5 Hz or Savitzky–Golay (window 7, order 2). `filtfilt` needs ≥ 16 frames.
- Combine `a` is an unsigned magnitude → no sign for braking; derive signed tangential acceleration ourselves.
- Combine field orientation is undocumented → use rotation-invariant features only (speed, tangential/normal acceleration, curvature, path length), never raw x/y or dir.

Drills
- Drill-name variants to canonicalise: LINE/LINE_DRILL, PASS_PRO-MIRROR/PASS_PRO_MIRROR, OVER_(THE_)SHOULDER_ADJUST, SPEED_OUT_LEFT/SPEED_OUT_ROUTE_LEFT.
- 2024 back-pedal reps are truncated (no braking phase). Pooling years fakes retest r = 0.80 vs ~0 within year → **always compute reliability within draft_year**.
- 2025 Combine export is unquantized and ~0.12 yd/s slower → standardise within (drill, draft_year), fitting scalers on training classes only.
- Opt-outs are heavy and non-random: 3-cone missing 65%, shuttle 61%; only ~40 players have 2 reps of those. The 40 has 375 players with ≥ 2 reps.
- BALL rows carry the athlete's nfl_id → filter `entity_type == "PLAYER"`.
- Missing attempt numbers are intentional.

Parsing
- Literal string `"NA"` is a real value in `lined_up_position` (1,383 plays killed pre-snap). pandas converts it to NaN silently; polars needs per-column `null_values`; DuckDB needs `sample_size=-1`.
- `quick_pressure`: FALSE = pressure but not quick; NA on a blitz = no pressure.

Game data
- Tracking speed > 12.5 yd/s is a glitch.
- 2023 tracking reads ~0.66 yd/s² higher for WR burst (season drift) → season fixed effects or within-season standardisation for every in-game trait.
- 13 players have no NFL snaps. ~2.5k tracking keys lack a player_play row; ~1.75k player_play rows lack tracking.
- Data-tab row counts are stale.

Confounds
- Exposure differs by class (2023 → 3 seasons, 2025 → 1).
- Draft pick is both confounder and mediator. Career snaps reflect opportunity, not just ability.
- Multiple testing across ~55 drills × many traits × many outcomes.

---

## 3. Competitive landscape — what is already public (as of 2026-10-10)

| Source | What it already does |
|---|---|
| bansal1600 (`kaggle-NFL-big-data-2027`, notebook *Measure the Athlete, Not the Drill*) | Polars pipeline; Savitzky–Golay traits applied to Combine and in-game tracking; season fixed effects; permutation tests |
| ShiyaoBian6639/nfl | Best documentation (brief, data dictionary, quirks); Butterworth kinematics; ICC; leave-one-class-out CV |
| tejrai07, ksankstemp-dotcom | Pre-registered null audits |
| Codingbysid | WR cut-exit residual protocol with frozen 2025 holdout |
| Yumeko (Kaggle) | DB drill reliability; 2024 data trap |
| Forum "Hidden Movers" | WR Gauntlet → in-game peak speed |
| angelojun2k dataset | CFBD/RAS college features |

Public drafts are converging on **"top speed transfers; position drills are unreliable; shuttle → DL burst"** plus bounded null results. Judges will see that story a dozen times. We need (a) a *different* mechanism, (b) *validated* with the same rigour the audit repos set as the bar, and (c) a concrete *week-to-week* use for a club.

---

## 4. Recommended angles

Principle: pick a **single kinematic mechanism** that (1) is physically specific (not "athleticism"), (2) can be measured **identically** in a Combine rep and in a game snap, (3) maps to an **NGS outcome column that already exists** in `player_play`, and (4) has enough players with ≥ 2 Combine reps to estimate reliability.

### Angle A (primary): Braking — deceleration signatures and route-break separation (WR/TE)

- **Mechanism.** Separation on break routes (out, curl, comeback, dig, speed-out) is produced in the ~0.5 s before the break: how hard a receiver brakes while keeping speed into the exit. Combine reps contain this moment in every route drill (the 551 events with a ball, the speed-outs, over-the-shoulder adjusts) and, with care, in the 3-cone and shuttle.
- **Combine trait.** From re-derived signed tangential acceleration: peak braking (yd/s²), braking duration, speed retained at the turn (v_min / v_approach), re-acceleration slope. Rotation-invariant, drill-standardised within (drill, draft_year).
- **In-game trait (same definition).** From the receiver's own tracking on break routes (`route_ran` ∈ breaks), window = snap → pass_forward event: peak braking and retained speed. Season fixed effects.
- **Outcome.** `separation_at_pass_forward` on break routes, residualised on cushion, coverage type (man/zone), down/distance, and target status, via a mixed model with player random intercept. Secondary: target rate, rec_yards/xYAC.
- **Why it differs.** Public work measures speed transfer or a single cut-exit residual on one drill. We measure a *braking profile* across all braking-containing drills, show it transfers to the *same* in-game trait (trait-to-trait, not drill-to-outcome), then to separation. The headline chart is a braking curve overlay (Combine rep vs game snap) per player.
- **Club use.** A "brake score" per prospect with CI and reliability; a drill-ledger saying which drill rep gives the signal at the Combine (so a club knows what to film at pro days).
- **Risks.** Braking phase truncated in some 2024 reps; WR+TE n ≈ 120–150; separation is noisy per play (need hundreds of routes per player).

### Angle B (hedge): Trench get-off — first-step burst vs pass-pro / pass-rush outcomes (OL primary, DL secondary)

- **Mechanism.** The first 0.5–1.0 s after movement onset: time to 2 yd/s, peak acceleration in the first 5 yd, and lateral mirror speed in PASS_PRO_MIRROR.
- **Outcomes.** OL: `pressure_allowed`, `time_to_pressure_allowed`, `peak_pressure_probability_allowed` (residualised on down/distance, formation, blitz). DL: `player_get_off`, `time_to_pressure`, `quick_pressure`.
- **Why it differs.** Public work targets DL via the shuttle. The OL side (mirror drill → pressure allowed) is almost untouched, and OL is the largest position group. "Drill translation" framing: does tracked first step beat the official 10-yd split?
- **Risks.** `player_get_off` is already an NGS product (less novel for DL); OL outcomes are matchup-confounded and we cannot see the rusher.

### Decision gate (end of Week 3)

Run both pipelines through reliability + a single pre-registered transfer test. Choose by: (1) within-year test–retest ICC of the Combine trait ≥ 0.5, (2) trait-to-trait Spearman (Combine → in-game same trait) with bootstrap CI excluding 0 on 2023–24 and replicating on 2025, (3) incremental value over baseline. If both pass, A is primary and B becomes a one-paragraph "generalises to the trenches" section; if A fails, B is primary. If both fail, fall back to the **drill-ledger** framing (reliability × transfer per drill, which drills a club should trust) — less unique but still scores on Data Science.

---

## 5. Analysis and validation protocol

Pre-register the primary hypothesis in `docs/prereg.md` before touching 2025 outcomes.

1. **Unit of analysis = player.** No frame-level or play-level inference without a player random effect. Report n per position everywhere.
2. **Kinematic extraction (shared code for Combine and game).** Sort by (event/game, play, nfl_id, time); parse time once; recompute displacement from x/y; signed tangential acceleration from a Savitzky–Golay (w=7, o=2) derivative, Butterworth 2 Hz as a sensitivity check; drop frames with s > 12.5 yd/s; require ≥ 16 frames.
3. **Standardisation.** Combine traits z-scored within (drill, draft_year) with scalers fit on training classes; in-game traits with season fixed effects.
4. **Reliability.** Within-year ICC(2,1) / split-half for every Combine trait with ≥ 2 reps; season-to-season ICC for in-game traits; report the √(rel_x · rel_y) ceiling next to every correlation.
5. **Transfer.** Partial Spearman within position controlling for weight, draft overall pick (with and without — show both, since pick is a mediator), draft year. Player-level bootstrap CIs (2,000 resamples).
6. **Out-of-class validation.** Fit on 2023–24, test on 2025 (frozen; touched once in Week 10). Also leave-one-draft-class-out for CIs.
7. **Incremental value.** Ridge / LightGBM with LOGO-by-class CV: baseline = draft pick + stopwatch drills + NGS scores; add our trait; report ΔR² / ΔSpearman with SE.
8. **Multiple testing.** One primary test (pre-registered). Everything else BH-corrected at q = 0.10, family-wise permutation for the drill ledger.
9. **Confounds reported, not hidden.** Exposure by class, opportunity vs ability, opt-out selection (compare opt-outs vs participants on baseline).
10. **Sanity checks.** Tracked 40 vs official 40 (expect r ≈ 0.9, +0.35 s); our re-derived s vs vendor s; row-count reconciliation across files.

---

## 6. Repository layout

```
NFL_Big_Data_Bowl_Kaggle/
  plan.md                      # this file
  README.md                    # how to reproduce; licence (MIT)
  LICENSE
  pyproject.toml / requirements.txt
  data/
    raw/                       # gitignored; Kaggle CSVs
    parquet/                   # gitignored; zstd parquet cache
  src/bdb27/
    io.py                      # polars scan_csv w/ null_values, sink_parquet, canonical drill names
    kinematics.py              # re-derived s, signed a_t, a_n, curvature; filters; QA flags
    traits_combine.py          # per-rep trait extraction (braking, burst, ...)
    traits_game.py             # same trait definitions on in-game windows
    outcomes.py                # residualised NGS outcomes from player_play
    reliability.py             # ICC, split-half, ceilings
    transfer.py                # partial Spearman, bootstrap, LOGO ridge/LightGBM
    plots.py                   # writeup figure functions (matplotlib, fixed style)
  notebooks/
    00_qa_audit.ipynb          # every data trap re-checked, with numbers
    01_combine_traits.ipynb
    02_game_traits.ipynb
    03_reliability.ipynb
    04_transfer.ipynb
    05_figures.ipynb
    kaggle_submission.ipynb    # public notebook: thin, imports src, regenerates all figures
  tests/                       # unit tests for kinematics + trait extraction on synthetic paths
  docs/
    prereg.md                  # pre-registered hypothesis and analysis plan
    data_dictionary.md
    writeup.md                 # the 2,000-word body, versioned
    appendix.md
  figures/                     # final PNG/SVG, numbered as in writeup
```

Kaggle: cache parquet to `/tmp` (not output) so no data is redistributed; the public notebook must run end-to-end on 4 cores / 30 GB in well under 12 h (target < 30 min).

Libraries: polars, pyarrow, scipy, numpy, statsmodels, pingouin, scikit-learn, lightgbm, matplotlib, seaborn (plotly for exploration only). No deep learning at n ≈ 500.

---

## 7. Week-by-week schedule

| Week | Dates | Goals | Exit criterion |
|---|---|---|---|
| 1 | Oct 13–19 | Verify Kaggle facts (Section 12); download data; parquet cache; `00_qa_audit` reproduces every trap in Section 2; canonical drill names; `kinematics.py` + tests | QA notebook with numbers; re-derived s matches vendor s to within filter noise |
| 2 | Oct 20–26 | Combine trait extraction for Angle A and B; within-year reliability for all traits; `docs/prereg.md` written and frozen | Reliability table; primary hypothesis pre-registered |
| 3 | Oct 27–Nov 2 | In-game trait extraction (same code); residualised outcomes; first transfer test on 2023–24 only | **Decision gate**: pick A or B (or ledger fallback) |
| 4 | Nov 3–9 | Deepen chosen angle: route-type / drill breakdown; confound sensitivity (pick in/out, weight, exposure) | Stable effect under all controls, or honest documentation of where it breaks |
| 5 | Nov 10–16 | Incremental-value models (LOGO ridge/LightGBM vs baseline); bootstrap CIs; BH on secondary tests | Δ over baseline with SE |
| 6 | Nov 17–23 | "Club use" layer: prospect brake/burst score cards, drill ledger, per-player Combine-vs-game overlay; writeup outline v0 | Outline reviewed; figure list fixed |
| 7 | Nov 24–30 | Figures v1 (all < 10); writeup draft v1 (full 2,000 words); cover image concept | Full draft exists |
| 8 | Dec 1–7 | Internal review against rubric; cut words; red-team the statistics (someone tries to break the result) | Draft v2; issue list closed |
| 9 | Dec 8–14 | Kaggle public notebook assembled and run end-to-end from raw CSVs; README; licence | Notebook runs clean on Kaggle |
| 10 | Dec 15–21 | **Unfreeze 2025 holdout once**; run pre-registered test; update numbers/figures; writeup v3 | Holdout result reported as-is |
| 11 | Dec 22–28 | Polish: figure accessibility (colour-blind safe, font sizes at Kaggle width), proofread, terminology check, appendix | Writeup v4 |
| 12 | Dec 29–Jan 4 | Post the writeup as a **submitted** entry (not a draft); verify notebook is public and attached; cover image uploaded | Submission confirmed on Kaggle |
| — | Jan 5–6 | Buffer only. No new analysis. | — |

Hard rule: analysis stops at the end of Week 10. Weeks 11–12 are writing and verification. The Patton warning ("200 h on tech, 30 min on the writeup") is the single most common failure mode.

---

## 8. Writeup and figure budget

Body ≤ 2,000 words; < 10 figures+tables. Plan **7 visuals** to leave margin for one addition in review.

| # | Type | Content | ~Words around it |
|---|---|---|---|
| Cover | Media Gallery image | One player's braking curve, Combine rep vs game snap, overlaid on a field strip | — |
| Intro | — | Question in one sentence, why a club cares, what's new (no "what is football") | 180 |
| Fig 1 | Diagram | Trait definition: speed/accel trace with braking window annotated, same on both data sources | 150 |
| Fig 2 | Chart | Within-year reliability by drill (ICC with CI); shows which reps carry signal | 200 |
| Fig 3 | Scatter | Combine trait vs in-game same trait, by position, with ceiling line and CI | 220 |
| Fig 4 | Chart | Trait → residualised outcome (separation / pressure allowed), with and without draft-pick control | 220 |
| Fig 5 | Chart | Incremental value over baseline (ΔR² or ΔSpearman with SE, LOGO by class) and 2025 holdout | 200 |
| Table 1 | Table | Drill ledger: reliability × transfer × n, "trust / don't trust" per drill | 150 |
| Fig 6 | Card | Prospect score card mock-up: how a scout reads it week to week | 180 |
| Limits / Conclusion | — | Honest limits (n, opt-outs, no opponents, exposure), what we'd do with ball/opponent data, one-line takeaway | 300 |
| Methods | — | Short; details to appendix | 200 |

Style rules: memorable title; one idea per figure; consistent palette; axis labels in football units (yd/s, yd/s², yards of separation); every claim has a number and an interval; limitations stated, not buried. Appendix carries filter settings, model specs, full tables, robustness checks.

---

## 9. Team and roles (fill in)

- Kinematics / data engineering
- Statistics / validation (owns prereg and red-team)
- Football framing / writeup
- Visualisation / cover image

Team ≤ 5; merges must complete by 2027-01-06 23:59 UTC. Decide Open vs University Track by Week 1 (Section 12).

---

## 10. Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Primary effect is null or tiny after controls | Medium | Decision gate at Week 3; Angle B hedge; drill-ledger fallback framed as actionable ("what to film") |
| Braking phase missing in many reps (2024 truncation, clips start in motion) | Medium | Reliability computed per drill per year; drop drills that lack the phase; report coverage |
| Opt-out selection bias | High | Compare opt-outs vs participants on baseline; state as limitation; never impute 3-cone/shuttle |
| Duplicating public work | Medium | Monitor forum/repos monthly; trait-to-trait transfer and club layer are the differentiators |
| Over-controlling on draft pick (mediator) | Medium | Report both with/without; explain in one sentence |
| Multiple testing creep | High | Prereg; one primary test; BH for the rest |
| Season drift / filter artefacts mistaken for signal | Medium | Season fixed effects; two filters as sensitivity; QA notebook |
| Kaggle notebook fails to run / not public / draft not submitted | Low but fatal | Week 9 end-to-end run; Week 12 submission check with screenshots |
| Writeup over word/figure limit | Medium | Budget in Section 8; count words at every draft |
| Time overrun on engineering | High | Hard analysis freeze end of Week 10 |

---

## 11. Key sources

- Competition: https://www.kaggle.com/competitions/nfl-big-data-bowl-2027
- Docs / quirks / kinematics: https://github.com/ShiyaoBian6639/nfl
- Public pipeline + writeup: https://github.com/bansal1600/kaggle-NFL-big-data-2027
- Cut-exit residual protocol: https://github.com/Codingbysid/NFL-big-data-bowl
- Null audit: https://github.com/tejrai07/kaggle-NFL-BIG-data-bowl-2027
- DB drill reliability / 2024 trap: https://www.kaggle.com/code/yumekohata/db-drills-decoded-cb-s-tracking-2024-data-trap
- College features dataset: https://www.kaggle.com/datasets/angelojun2k/nfl-bdb2027-predraft-college-features
- Launch announcement: https://x.com/kaggle/status/2107854497795936436
- Past finalists: https://edge-operations.nfl.com/gameday/analytics/big-data-bowl/2025-big-data-bowl-finalists
- Evaluation of tracking-based metrics: https://arxiv.org/pdf/2403.14769

Past-winner pattern to emulate: one crisp football-native metric, validated, one clean animation/heatmap, actionable, honest limitations (2023 pocket-pressure heatmaps / STRAIN; 2024 missed-tackle opportunities; 2025 pre-snap coverage tells; 2026 ghost defenders).

---

## 12. Verify on Kaggle once logged in

All of the following came from secondary sources. Check each against the live pages and tick it off; update this file.

- [ ] Final deadline is 2027-01-06 23:59 UTC and it is also the team-merge deadline.
- [ ] Word limit 2,000 and "fewer than 10" figures+tables apply to the body only; appendix excluded. Confirm whether tables in the appendix count and whether a cover image counts.
- [ ] Exact submission mechanism: Writeup object, public notebook attached, Media Gallery image required; what "submitted" looks like in the UI.
- [ ] University Track eligibility (undergrad only vs undergrad+grad), proof required, and whether a mixed team is Open-only.
- [ ] Rubric weights 30/30/20/20 and the two gates, verbatim.
- [ ] External data policy wording ("public and free or low cost") and whether nflverse/CFBD/PFF-free tiers qualify.
- [ ] Data licence (CC BY-NC 4.0) and OSI-licence requirement for winners.
- [ ] Data tab: file list, actual row counts (reported stale), and any errata or re-uploads since 2026-10-06.
- [ ] Whether `game_tracking_*` is play-direction normalised or raw; presence/values of the `event` column (ball_snap, pass_forward, etc.).
- [ ] Which `player_play` NGS columns are present and their exact names/definitions (separation_at_pass_forward, cushion, pressure_allowed, player_get_off, time_to_pressure(_allowed), quick_pressure semantics).
- [ ] Combine tracking: confirm no `o`/frame_id, ball rows only in 551 events, drill-name variants, attempt numbering.
- [ ] Host discussion threads 746521 (no prediction track) and 747086 (AI tools allowed) and any pinned FAQ / clarification posted since.
- [ ] Regional events and any deadlines they impose (London Oct 9, Paris Oct 21, NYC Nov 10, Mexico City Nov 18–20).
- [ ] Prize structure and in-person presentation requirement for the Grand Prize.
- [ ] Kaggle notebook environment: CPU/RAM/runtime limits and internet access for this competition.
