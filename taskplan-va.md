# Phase-1 PoC Plan and Modular Jira Backlog

## Collision / Near-Collision Review Intelligence System

---

# 1. Objective

Build a **Phase-1 offline PoC** for a **collision / near-collision review intelligence system** that supports the following input modes:

* video only
* video + audio
* video + telemetry
* video + audio + telemetry

The PoC should generate a structured **Review Assist Package** for one event and later scale to batch execution.

The PoC is **human-in-the-loop** and is not a full automation system.

---

# 2. Agreed Scope for This Build

## In scope now

* Module A — Ingest & media validation
* Module B — Canonical time synchronization
* Module C — Advanced preprocessing & quality gating
* Module D1 — Exterior video scene evidence
* Module D2 — Audio evidence
* Module D4 — Temporal window aggregation
* Module F — Event state abstraction layer
* Module G — Trigger reasoning engine
* Module H — Contradiction detection + confidence propagation
* Module I — Outcome reasoning + KB adjudication
* Minimal local artifact writing (`ReviewAssistPackage.json` and intermediate tables)

## Deferred to later

* Module E — Privacy-safe media generation
* Module D3 — Interior video / DMS branch
* KG projection
* Similar-event retrieval
* Reviewer disagreement analytics
* Hard-negative mining
* Advanced MLOps integration (MLflow / DVC / Ray scale-out)
* LLM-based summary enhancement

---

# 3. Design Principles

## 3.1 Modality strategy

* Exterior video is mandatory
* Audio is optional
* Telemetry is optional
* Interior video is optional and later
* The pipeline must degrade gracefully if audio or telemetry is missing

## 3.2 Reasoning strategy

* Structured multimodal reasoning is the main decision path
* KB-governed adjudication is the final policy layer
* LLM is not in the primary adjudication path for this PoC

## 3.3 Output strategy

For each event, generate:

* likely outcome
* likely trigger
* confidence decomposition
* event-state abstraction
* key evidence timestamps
* contradiction / reviewer-attention flags
* structured reviewer-facing summary
* local review artifact JSON

---

# 4. Architecture Flow for This PoC

## Runtime-critical flow

Module A -> Module B -> Module C -> Module D1/D2/D4 -> Module F -> Module G -> Module H -> Module I -> Local JSON output

## Input modes supported

### Mode 1

Video only

### Mode 2

Video + audio

### Mode 3

Video + telemetry

### Mode 4

Video + audio + telemetry

---

# 5. Technical Scope by Module

## Module A — Ingest & media validation

### Purpose

Validate media and metadata before any heavy processing.

### Build now

* ffprobe wrapper
* video metadata extraction
* frame timestamp integrity checks
* telemetry CSV validation
* audio probe and duration validation

### Outputs

* media manifest
* timestamp integrity report
* telemetry probe report
* audio probe report

### Tech stack

* ffprobe / ffmpeg-python
* OpenCV
* Pandas
* librosa

---

## Module B — Canonical time synchronization

### Purpose

Align all available modalities to the exterior video timeline.

### Build now

* canonical timeline creation
* telemetry unit normalization
* spike filtering
* visual motion proxy from optical flow
* cross-correlation based sync offset estimation
* telemetry interpolation to canonical timeline
* sync quality score

### Outputs

* aligned telemetry timeline
* sync report
* sync quality score
* downweight flags

### Tech stack

* NumPy
* SciPy
* OpenCV

---

## Module C — Advanced preprocessing & quality gating

### Purpose

Normalize lightly and tag uncertainty aggressively.

### Build now

#### Video

* resize
* blur detection
* glare detection
* luminance flicker detection
* compression artifact heuristic

#### Audio

* SNR estimation
* cabin noise / mic occlusion heuristic
* optional rough acoustic context tagging

#### Telemetry

* smoothing
* event-shape descriptors

  * peak braking duration
  * braking rise time
  * recovery time
  * speed delta

### Outputs

* frame-level quality table
* audio quality report
* telemetry shape features
* quality flags

### Tech stack

* OpenCV
* SciPy
* librosa

---

## Module D1 — Exterior video scene evidence

### Purpose

Produce actor tracks and scene-structure features.

### Build now

* YOLO11x detection
* ByteTrack tracking
* actor track table
* basic motion features

### Extend in this phase if time allows

* lane / drivable reasoning using SegFormer
* depth using DepthAnythingV2
* TTC proxy
* in-path flag
* reaction delay estimate

### Outputs

* actor_track_table
* scene feature matrix
* key visual evidence timestamps

### Tech stack

* Ultralytics YOLO11x
* ByteTrack
* MMSegmentation / SegFormer
* DepthAnythingV2
* OpenCV

---

## Module D2 — Audio evidence

### Purpose

Extract supporting audio event cues.

### Build now

* onset detection
* peak picking
* RMS energy analysis
* merging nearby acoustic peaks

### Outputs

* audio event markers
* acoustic feature summary

### Tech stack

* librosa

### Rule

Audio is support evidence only and not the sole determinant of trigger/outcome.

---

## Module D4 — Temporal window aggregation

### Purpose

Aggregate all continuous features into multi-resolution windows.

### Build now

* 250 ms windows
* 500 ms windows
* 1 second windows

### Outputs

* window_level_feature_table

### Tech stack

* Pandas
* NumPy

---

## Module F — Event state abstraction layer

### Purpose

Convert continuous multimodal features into interpretable event states.

### Build now

* brake_event_state
* lead_hazard_state
* evasive_maneuver_state
* lane_departure_state if video evidence supports it

### Outputs

* event_state_abstraction_table
* event_state_summary

### Implementation style

* deterministic discretization rules over window-level features

---

## Module G — Trigger reasoning engine

### Purpose

Infer likely trigger from structured features.

### Build now

* rules-first trigger ranking
* feature vector flattening from event states + video/audio/telemetry summaries
* ranked trigger candidates

### Keep ready

* XGBoost hook for later model-based trigger prediction

### Outputs

* likely_trigger
* ranked_triggers
* trigger_confidence

---

## Module H — Contradiction detection + confidence propagation

### Purpose

Detect inconsistent evidence and adjust output confidence.

### Build now

* contradiction rules
* confidence caps / downweighting rules
* reviewer attention flag logic

### Example rules

* severe braking but no lead hazard
* impact-like audio but no speed drop
* weak sync so telemetry weight reduced
* glare so perception confidence capped

### Outputs

* contradiction_flag
* needs_reviewer_attention
* confidence decomposition

---

## Module I — Outcome reasoning + KB adjudication

### Purpose

Infer final outcome using structured reasoning plus policy logic.

### Target outcomes

* No Collision
* Possible Collision
* Near Collision
* Near Collision - Unavoidable
* Collision

### Build now

* rule-assisted baseline ranking
* KB adjudication layer
* final outcome selection

### Keep ready

* LightGBM hook for later model-based outcome prediction

### Outputs

* likely_outcome
* ranked_outcomes
* outcome_confidence
* KB-adjusted final outcome

---

# 6. PoC Success Criteria

The PoC is successful when one event can run end-to-end and produce:

* media validation outputs
* sync report with sync quality
* frame-level quality outputs
* actor track outputs
* audio markers if audio exists
* window-level features
* event-state abstraction
* likely trigger
* likely outcome
* contradiction / reviewer attention status
* final `ReviewAssistPackage.json`

---

# 7. Milestones

## Milestone 0 — Repo and contract readiness

Deliverables:

* repo scaffold
* payload schema
* output schema
* config structure
* sample payloads

## Milestone 1 — Clean ingest + sync baseline

Deliverables:

* Module A
* Module B
* working sync report for one event

## Milestone 2 — Quality + feature extraction baseline

Deliverables:

* Module C
* Module D1
* Module D2
* Module D4
* intermediate feature tables

## Milestone 3 — Reasoning baseline

Deliverables:

* Module F
* Module G
* Module H
* Module I
* one-event ReviewAssistPackage

## Milestone 4 — Multi-input mode validation

Validate:

* video only
* video + audio
* video + telemetry
* video + audio + telemetry

---

# 8. Modular Jira Backlog

## Epic POC-00 — Foundation and Contracts

### Story POC-00-01 — Create repo scaffold

**Tasks**

* create `src/`, `configs/`, `tests/`, `sample_payloads/`
* create module folders for ingest, sync, preprocess, perception, features, reasoning, persist, pipeline
* add base README

### Story POC-00-02 — Define input payload schema

**Tasks**

* create schema for event input payload
* support optional audio / telemetry / interior video
* add validation rules

### Story POC-00-03 — Define output ReviewAssistPackage schema

**Tasks**

* define output JSON structure
* define predictions block
* define confidence block
* define event_state_abstraction block
* define operations block

### Story POC-00-04 — Create base config and threshold file

**Tasks**

* define sync thresholds
* define blur / glare thresholds
* define contradiction rules thresholds
* define outcome KB config path

---

## Epic POC-01 — Module A: Ingest & Media Validation

### Story POC-01-01 — Build ffprobe wrapper

**Tasks**

* execute ffprobe
* parse FPS, duration, resolution, frame count
* write video manifest

### Story POC-01-02 — Implement frame timestamp integrity checker

**Tasks**

* read frame PTS
* detect missing frames
* detect duplicate frames
* detect variable FPS
* write timestamp integrity report

### Story POC-01-03 — Implement telemetry probe

**Tasks**

* load CSV
* validate required columns
* sort by timestamp
* remove invalid rows

### Story POC-01-04 — Implement audio probe

**Tasks**

* load audio
* validate duration and sample rate
* write audio probe report

---

## Epic POC-02 — Module B: Canonical Time Synchronization

### Story POC-02-01 — Create canonical video timeline

**Tasks**

* compute timeline from duration and FPS
* store canonical timeline format

### Story POC-02-02 — Normalize and clean telemetry

**Tasks**

* convert units
* filter spikes
* standardize signals

### Story POC-02-03 — Implement offset estimation

**Tasks**

* compute visual motion proxy
* compute telemetry acceleration series
* cross-correlate signals
* estimate sync offset

### Story POC-02-04 — Implement telemetry interpolation and sync quality score

**Tasks**

* resample telemetry to canonical timeline
* compute sync confidence
* emit downweight flag when sync is weak

---

## Epic POC-03 — Module C: Advanced Preprocessing & Quality Gating

### Story POC-03-01 — Implement video quality checks

**Tasks**

* resize frames
* blur score
* glare score
* luminance flicker score
* compression artifact heuristic

### Story POC-03-02 — Implement audio quality checks

**Tasks**

* compute audio SNR
* detect cabin-noise / mic-occlusion heuristics
* tag quality flags

### Story POC-03-03 — Implement telemetry smoothing and event-shape features

**Tasks**

* smooth speed / accel curves
* compute braking rise time
* compute peak braking duration
* compute recovery time
* compute speed delta

---

## Epic POC-04 — Module D1: Exterior Video Scene Evidence

### Story POC-04-01 — Integrate YOLO11x detection

**Tasks**

* load model
* run inference on frames
* export detections

### Story POC-04-02 — Integrate ByteTrack tracking

**Tasks**

* associate detections to tracks
* maintain actor track table
* compute basic track continuity stats

### Story POC-04-03 — Add scene semantics extension

**Tasks**

* integrate lane / drivable model
* integrate depth model
* compute in-path flags and TTC proxy

---

## Epic POC-05 — Module D2: Audio Evidence

### Story POC-05-01 — Implement acoustic event extraction

**Tasks**

* onset detection
* peak picking
* RMS computation
* merge nearby peaks
* write audio markers

---

## Epic POC-06 — Module D4: Temporal Window Aggregation

### Story POC-06-01 — Build multi-resolution windows

**Tasks**

* aggregate to 250 ms windows
* aggregate to 500 ms windows
* aggregate to 1 s windows
* write window_level_feature_table

---

## Epic POC-07 — Module F: Event State Abstraction

### Story POC-07-01 — Define event state rules

**Tasks**

* define brake state rules
* define lead hazard state rules
* define evasive maneuver state rules
* define lane departure state rules

### Story POC-07-02 — Build event-state abstraction pipeline

**Tasks**

* map window features to state labels
* write event_state_abstraction_table
* emit event-level state summary

---

## Epic POC-08 — Module G: Trigger Reasoning Engine

### Story POC-08-01 — Implement rules-first trigger ranking

**Tasks**

* flatten features into vector X
* define initial trigger heuristics
* rank trigger candidates
* emit confidence

### Story POC-08-02 — Add model hook for trigger engine

**Tasks**

* create XGBoost interface stub
* load model path from config
* keep disabled until trained model exists

---

## Epic POC-09 — Module H: Contradiction Detection + Confidence Propagation

### Story POC-09-01 — Implement contradiction rules

**Tasks**

* define contradiction rules
* emit contradiction flag
* emit reviewer attention flag

### Story POC-09-02 — Implement confidence propagation

**Tasks**

* apply sync-based confidence downweighting
* apply glare-based confidence cap
* apply low-audio-SNR weight reduction
* compute evidence consistency score

---

## Epic POC-10 — Module I: Outcome Reasoning + KB Adjudication

### Story POC-10-01 — Implement baseline outcome ranking

**Tasks**

* flatten feature vector X
* define initial rule-assisted outcome ranking
* output ranked outcomes

### Story POC-10-02 — Implement KB adjudication layer

**Tasks**

* parse KB policy config
* apply KB logic on ranked outcomes
* select final outcome

### Story POC-10-03 — Add model hook for outcome engine

**Tasks**

* create LightGBM interface stub
* keep disabled until trained model exists

---

## Epic POC-11 — Minimal Artifact Output

### Story POC-11-01 — Build final ReviewAssistPackage writer

**Tasks**

* combine outputs from Modules A–I
* build final JSON artifact
* write local JSON file
* write run manifest

---

# 9. Dependency Plan

## Dependency chain

* POC-00 must complete before all others
* POC-01 before POC-02
* POC-02 before POC-09 and POC-10
* POC-03 before POC-04, POC-05, POC-09
* POC-04, POC-05, POC-06 before POC-07
* POC-07 before POC-08 and POC-10
* POC-08 and POC-10 before POC-11
* POC-09 should feed POC-10 and POC-11

---

# 10. Suggested Execution Order

## Week 1

* POC-00 Foundation and Contracts
* POC-01 Module A
* POC-02 Module B

## Week 2

* POC-03 Module C
* POC-04 Module D1
* POC-05 Module D2
* POC-06 Module D4

## Week 3

* POC-07 Module F
* POC-08 Module G
* POC-09 Module H
* POC-10 Module I
* POC-11 Final artifact writer

---

# 11. Fastest Delivery Strategy

## Recommended approach

* Build rules-first, models-later
* Keep XGBoost / LightGBM interfaces ready, but do not block on training
* Use local JSON / CSV / Parquet outputs first
* Defer DB, UI, KG, retrieval, and MLOps wiring until the one-event pipeline works

---

# 12. Final Recommendation

This plan is the agreed **Phase-1 PoC mainline**. It preserves the right architecture direction:

* multimodal but flexible inputs
* structured reasoning first
* telemetry as first-class when available
* KB-governed adjudication
* contradiction and confidence safeguards
* human-in-the-loop review intelligence

This is the backlog that should be executed first before expanding to later modules and asynchronous enrichments.




Timeline by module
Week 1
Module A — Ingest & media validation

2–3 days

ffprobe wrapper
video metadata
frame timestamp integrity checks
audio probe
telemetry CSV validation
Module B — Canonical time synchronization

2–3 days

canonical timeline
telemetry normalization
visual motion proxy
cross-correlation
interpolation
sync score

These two should come first because your own docs emphasize media/sync interfaces as one of the earliest things to lock.

Week 2
Module C — Advanced preprocessing & quality gating

2 days

blur
glare
luminance flicker
audio SNR
telemetry smoothing
event-shape descriptors
Module D1 — Exterior video scene evidence

3–4 days

YOLO11x
ByteTrack
basic track table
optionally SegFormer and DepthAnythingV2 if time permits
Module D2 — Audio evidence

1 day

onset detection
peak picking
RMS peaks
event merging
Module D4 — Temporal window aggregation

1 day

250 ms / 500 ms / 1 s windows
window-level feature table
Week 3
Module F — Event state abstraction

1–2 days

discretization rules
state table generation
Module G — Trigger reasoning engine

1–2 days

rules-first trigger ranking
XGBoost hook stub
Module H — Contradiction detection + confidence propagation

1 day

contradiction rules
confidence caps / downweight rules
Module I — Outcome reasoning + KB adjudication

2 days

rules-first outcome baseline
KB adjudication
LightGBM hook stub
Final packaging

1 day

local ReviewAssistPackage.json
run manifest
test one-event end-to-end
