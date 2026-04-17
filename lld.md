# Low Level Design (LLD) – Detailed Execution Workflow

## Phase-1 Collision / Near-Collision Review Intelligence System

**Version:** 1.8 (Final Feature-Store & Async Architecture Edition)

---

## 1. Document Purpose & Scope

This document provides the developer-level execution trace and technical specifications for the **Phase-1 Review Intelligence System**. It defines the exact transformations, array operations, function calls, intermediate abstraction layers, and **Knowledge Graph (KG)** constructions required to process a multimodal event clip.

- **Execution Paradigm:** Offline, Directed Acyclic Graph (DAG) orchestration (e.g., Prefect / Airflow)
- **Note on Model Selection:** Specific machine learning models (e.g., YOLO, XGBoost) and algorithms mentioned are **default baseline implementation choices** subject to validation against actual customer data

---

## 2. Global Data Contracts (I/O)

### 2.1 Trigger Payload (Input)

```json
{
  "event_id": "EVT-98765-2026",
  "media": {
    "exterior_video_uri": "s3://bucket/events/EVT-98765/front_cam.mp4",
    "interior_video_uri": "s3://bucket/events/EVT-98765/cabin_cam.mp4",
    "audio_uri": "s3://bucket/events/EVT-98765/cabin_audio.wav"
  },
  "telemetry_uri": "s3://bucket/events/EVT-98765/telemetry.csv",
  "metadata": {
    "trigger_type_raw": "hard_brake",
    "hardware_version": "hw_v2"
  }
}
```

> **Note:** `interior_video_uri` is optional.

### 2.2 Review Assist Package (Output)

```json
{
  "event_id": "EVT-98765-2026",
  "predictions": {
    "outcome_class": "Near Collision",
    "trigger_class": "Braking",
    "confidence_decomposition": {
      "perception_confidence": 0.94,
      "sync_confidence": 0.95,
      "trigger_confidence": 0.92,
      "outcome_confidence": 0.88,
      "evidence_consistency_score": 0.90
    }
  },
  "event_state_abstraction": {
    "brake_event_state": "severe_sustained",
    "lead_hazard_state": "closing_rapidly",
    "evasive_maneuver_state": "moderate_steering"
  },
  "evidence": {
    "canonical_timestamps_ms": {
      "pre_trigger_window": [0, 4000],
      "visual_trigger": 4250,
      "post_trigger_consequence": [4250, 12000]
    },
    "feature_attribution": {
      "max_decel": 0.45,
      "min_ttc": 0.32,
      "lane_conflict": 0.10
    }
  },
  "reviewer_support": {
    "generated_comment": "Event triggered by severe braking (-0.8g). Video confirms pedestrian entered lane at t=4.25s. Near collision avoided.",
    "masked_clip_uri": "s3://bucket/reviews/EVT-98765_masked.mp4",
    "similar_prior_events": ["EVT-11223", "EVT-44556"]
  },
  "operations": {
    "review_status": "review_ready",
    "needs_reviewer_attention": false,
    "contradiction_flag": false,
    "quality_flags": {
      "weather": "clear",
      "windshield": "clean",
      "audio_snr": "high"
    },
    "pii_mask_status": "fully_masked"
  }
}
```

---

## 3. End-to-End Granular Execution Workflow

### STEP 1: Ingest & Media Validation

#### 1.1 Asset Retrieval
Download all URIs to the worker's local ephemeral `/tmp/` directory.

#### 1.2 Video Container & Integrity Probe
Execute:

```bash
ffprobe -v quiet -print_format json -show_format -show_streams <video_path>
```

Extract:
- `fps`
- `width`
- `height`
- `duration`
- `nb_frames`

#### 1.3 Frame Timestamp Integrity Check

```python
cap = cv2.VideoCapture(video_path)
```

Read raw Presentation Timestamps (PTS) for all frames via:

```python
cap.get(cv2.CAP_PROP_POS_MSEC)
```

Compute:

```python
np.diff(pts_array)
```

Flag:
- `missing_frame` if `Δt > 1.5 × (1 / fps)`
- `duplicate_frame` if `Δt < 0.1 × (1 / fps)`
- `variable_fps` if standard deviation of `Δt` exceeds threshold

#### 1.4 Telemetry & Audio Probe
- Load CSV via `pandas.read_csv()`
- Drop rows where `speed` or `timestamp` are `NaN`
- Load audio via `librosa.load(audio_path, sr=16000)`

If duration mismatch with video is greater than `5%`, log sync warning.

#### Tools, Libraries & Algorithms (Step 1)

- **Primary Libraries:** `ffmpeg-python`, `OpenCV`, `Pandas`, `librosa`
- **Exploratory / Alternatives:** `PyAV`, `Decord`, `NVIDIA DALI`

---

### STEP 2: Canonical Time Synchronization

#### 2.1 Baseline Time Array

```python
t_video = np.arange(0, duration, 1 / fps)
```

#### 2.2 Telemetry Unit Normalization & Cleaning
- Convert speed to `m/s`
- Convert acceleration to `g`
- Apply spike filtering using `scipy.signal.medfilt` to remove physically impossible acceleration changes (`> 3g/s`)

#### 2.3 Offset & Cross-Correlation
Calculate dense optical flow using:

```python
cv2.calcOpticalFlowFarneback()
```

- Evaluate every 5th frame using bottom 50% crop
- Compute mean frame-to-frame `L2` magnitude to form a 1D visual motion array

Run correlation:

```python
corr = scipy.signal.correlate(visual_motion_array, telemetry_accel_array, mode="full")
lag_index = np.argmax(corr)
```

Use `lag_index` to compute `sync_offset_ms`.

#### 2.4 Resampling
Apply offset and resample telemetry strictly to the `t_video` timeline using:

```python
scipy.interpolate.interp1d
```

#### 2.5 Sync Confidence
Calculate Pearson correlation between shifted telemetry and visual arrays. Set `sync_quality_score`.

If `< T1` (e.g., `0.6`), flag:

- `DOWNWEIGHT_TELEMETRY`

#### Tools, Libraries & Algorithms (Step 2)

- **Primary Libraries:** `NumPy`, `SciPy`, `OpenCV`
- **Algorithms:** Anchor-event alignment, piecewise linear drift correction

---

### STEP 3: Advanced Preprocessing & Quality Gating

#### 3.1 Video Quality & Normalization

- **Resize:**

```python
cv2.resize(..., interpolation=cv2.INTER_AREA)
```

- **Exposure & Flicker:** Calculate frame-to-frame luminance `ΔL`, tag `exposure_flicker`
- **Compression Artifacts:** Compute edge-gradient variance, tag `low_bitrate_artifacts`
- **Blur Detection:**

```python
cv2.Laplacian(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY), cv2.CV_64F).var()
```

If `< 50`, flag `blur`

- **Glare Detection:**

```python
cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
cv2.calcHist()
```

If more than `15%` of pixels fall in top `5%` luminance bins, flag `glare`

#### 3.2 Audio Quality & Context
- Compute Signal-to-Noise Ratio (SNR)
- Flag `persistent_cabin_noise` or `mic_occlusion`
- Run heuristic detectors for:
  - `speech_presence`
  - `horn_candidate`
  - `rough_road_bump`

#### 3.3 Telemetry Smoothing & Event Shapes
- Apply `scipy.signal.savgol_filter` (Savitzky-Golay) to derive smooth:
  - `a = dv/dt`
  - `jerk = da/dt`
- Use Kalman smoothing for noisy GPS heading / yaw
- Extract:
  - `peak_braking_duration`
  - `braking_rise_time`
  - `recovery_time`
  - `speed_delta_1s`

#### Tools, Libraries & Algorithms (Step 3)

- **Primary Libraries:** `OpenCV`, `Librosa`, `SciPy`
- **Exploratory / Alternatives:** `Kornia`, `pykalman`, `filterpy`

---

### STEP 4: Parallel Feature Extraction & Segmentation

#### Branch 4A: Video Scene Evidence (GPU)

##### 4A.1 Detection & Tracking
- Batch frames (size `16`)
- Run `YOLO11x.pt`
- Apply NMS with:
  - `conf = 0.35`
  - `iou = 0.45`
- Filter classes:
  - `car`
  - `truck`
  - `bus`
  - `motorcycle`
  - `bicycle`
  - `pedestrian`

Pass bounding boxes to **ByteTrack**.

Maintain dictionary:

```text
[t_ms, track_id, cls, x1, y1, x2, y2, v_x, v_y]
```

##### 4A.2 Drivable Area & Lane Semantics
- Run **SegFormer** (MMSegmentation) every 5th frame
- Extract:
  - `ego_lane_mask`
  - `drivable_area_mask`

##### 4A.3 Depth Estimation
- Run **DepthAnythingV2**
- For each `track_id`, compute median depth within bounding box

##### 4A.4 Advanced Actor & Conflict Metrics
- Track:
  - `visibility_duration`
  - `first_appearance_time`
  - `occlusion_reappearance_pattern`
- Compute:
  - bounding box expansion rate `dA/dt`
  - `TTC_proxy = Depth_Metric / d(Depth)/dt`
- Intersect bottom-center of bounding box with `ego_lane_mask`
- Compute:
  - `path_intersection_confidence`
  - `pre_event_reaction_delay_estimate`

##### Tools, Libraries & Algorithms (Branch 4A)

- **Detection:** Ultralytics (`YOLO11x`)
  - Alternatives: `RT-DETR`, `Detectron2`
- **Tracking:** `ByteTrack`
  - Alternatives: `BoT-SORT`, `DeepSORT`
- **Segmentation:** `MMSegmentation` (`SegFormer`)
  - Alternatives: `YOLOP`
- **Depth:** PyTorch / HuggingFace (`DepthAnythingV2`)
  - Alternatives: `ZoeDepth`, `MiDaS`
- **Ego-Motion Proxy:** OpenCV Farneback flow
  - Future roadmap: `ORB-SLAM3`

---

#### Branch 4B: Audio Evidence (CPU)

##### 4B.1 Onset Detection & Peak Picking
Compute spectral novelty:

```python
librosa.onset.onset_strength
```

Peak picking:

```python
librosa.util.peak_pick(pre_max=3, post_max=3, delta=0.5)
```

##### 4B.2 Temporal Smoothing
- Merge nearby peak detections within `200 ms`
- Distinguish:
  - `short_peak_bursts`
  - `sustained_harsh_audio`

using:

```python
librosa.feature.rms()
```

##### Tools, Libraries & Algorithms (Branch 4B)

- **Primary Libraries:** `Librosa`
- **Exploratory / Alternatives:** `Torchaudio`

---

#### Branch 4C: Interior Video Signal (DMS Stack – CONDITIONAL)

##### 4C.1 Conditional Gate
If `interior_video_uri` is `null`, bypass and return zero-padded DMS vectors.

##### 4C.2 Inference
- Run **MediaPipe Pose** for seatbelt presence
- Run YOLO `cell_phone` class near facial landmarks

> **Architectural Guardrail:** Interior video is strictly optional in the payload. DMS-derived cues remain support signals only in Phase 1. They must never silently grow into the core adjudication scope or block the pipeline if interior video is missing.

##### Tools, Libraries & Algorithms (Branch 4C)

- **Primary Libraries:** `MediaPipe`, `InsightFace / RetinaFace`, `Ultralytics`

---

#### Branch 4D: Temporal Window Aggregation

##### 4D.1 Windowing
Use `pandas.DataFrame.rolling` to aggregate continuous features into temporal bins:
- `250ms_window`
- `500ms_window`
- `1s_aggregated`

##### Tools, Libraries & Algorithms (Branch 4D)

- **Primary Libraries:** `Pandas`, `NumPy`

---

### STEP 5: Privacy-Safe Media Generation

#### 5.1 PII Detection
Run:
- `YOLO11n-license-plate.pt`
- `RetinaFace` / `SCRFD`

on full-resolution exterior frames.

#### 5.2 Mask Application

```python
frame[y1:y2, x1:x2] = cv2.GaussianBlur(frame[y1:y2, x1:x2], (51, 51), 0)
```

#### 5.3 Render & Encode
Use `cv2.VideoWriter` to encode blurred frames to H.264 MP4.

#### Tools, Libraries & Algorithms (Step 5)

- **Primary Libraries:** `Ultralytics`, `InsightFace / SCRFD`, `OpenCV`

---

### STEP 6: Layered AI Reasoning Engines

#### 6.1 Event State Abstraction Layer
Evaluate `250ms_windows` to assign discrete states:

- `brake_event_state ∈ [none, mild, severe_sudden, severe_sustained]`
- `lead_hazard_state ∈ [none, static, closing_slowly, closing_rapidly]`
- `evasive_maneuver_state ∈ [none, slight_drift, hard_steering]`
- `lane_departure_state ∈ [none, intentional_lane_change, unintended_drift]`

#### 6.2 Trigger Reasoning Engine
- Flatten abstract states, event-shape descriptors, and conflict metrics into vector `X`
- Run:

```python
xgb_model.predict_proba(xgboost.DMatrix(X))
```

- Assign `likely_trigger` using `argmax`

#### 6.3 Contradiction Detection Layer
Example logic:

- If `brake_state == severe_sustained` and `lead_hazard_state == none` → contradiction
- If `audio_impact == True` and `speed_drop == False` → contradiction

If contradiction is true:
- set `contradiction_flag = true`
- set `needs_reviewer_attention = true`
- heavily discount `evidence_consistency_score`

#### 6.4 Explicit Confidence Propagation Rules
Before final adjudication:

- If `sync_quality_score < T1` → down-weight telemetry evidence
- If `quality_flags.glare == True` → cap `perception_confidence` at `0.6`
- If `audio_snr == low` → reduce weight of audio evidence to `0`
- If `contradiction_flag == True` → force reviewer attention

#### 6.5 Outcome Reasoning & KB Adjudication
Run:

```python
lgb_model.predict_proba(X)
```

for:
- `No_Collision`
- `Possible_Collision`
- `Near_Collision`
- `Near_Collision_Unavoidable`
- `Collision`

Apply **Customer Knowledge Base** rules against Event State Abstractions, e.g.:

- If `speed > 60 mph` and `pre_event_reaction_delay < 1.0s` → append `- Unavoidable`

#### Tools, Libraries & Algorithms (Step 6)

- **Primary Libraries:** `XGBoost`, `LightGBM`, core Python logic
- **Exploratory / Alternatives:** `PyTorch`, `Scikit-Learn`

---

### STEP 7: Explainability & Review Support

#### 7.1 Feature Attribution
Run:

```python
shap.TreeExplainer(xgb_model).shap_values(X)
```

Extract top-3 contributing structured features.

#### 7.2 Structured Explanation
Use:

```python
jinja2.Template.render()
```

Populate pre-approved text templates with:
- abstraction states
- trigger
- outcome
- top SHAP attributes

> No generative LLM is used.

#### Tools, Libraries & Algorithms (Step 7)

- **Primary Libraries:** `SHAP`, `Jinja2`

---

### STEP 8: Artifact Persistence & Output

#### 8.1 Final Package Construction
Compile the `ReviewAssistPackage` JSON and populate:
- metadata
- predictions
- operations
- SHAP attributions

#### 8.2 Persistence
Commit JSON and masked video to:
- PostgreSQL JSONB
- MongoDB
- S3

---

## 4. Runtime-Critical vs Asynchronous Execution

To prevent operational bottlenecks, the DAG explicitly splits execution into the **Blocking Main Flow** and **Asynchronous Post-Processing**.

### 4.1 Blocking Main DAG (Runtime-Critical)
`Ingestion -> Sync -> Perception -> Reasoning -> JSON Persistence`  
(steps 1 through 8)

**SLA Constraint:** This flow must execute deterministically and write the `ReviewAssistPackage` to the database before the event is released to the Analyst UI queue.

### 4.2 Asynchronous Post-Processing
These processes trigger after `ReviewAssistPackage` is committed. They do not block reviewer workflow.

- **Event Knowledge Graph (KG) Projection**
  - Insert parsed entities (`ActorTrack`, `TriggerHypothesis`, `KBRule`) into graph DB (`Neo4j` / `NetworkX`)
- **Similar-Event Retrieval**
  - Query vector DB using Event State Abstraction vector to retrieve `similar_prior_events`
- **Reviewer Disagreement Analytics & Hard-Negative Mining**
  - Trigger after human reviewer submits final adjudication

---

## 5. Feature-Store Schema Summary (Intermediate Artifacts)

To ensure reproducibility, MLOps lineage, and asynchronous graph generation, the pipeline writes discrete intermediate artifacts to the feature store.

| Artifact Table | Primary Schema / Columns | Purpose |
|---|---|---|
| `frame_level_quality_table` | `event_id, t_ms, blur_var, glare_ratio, luminance_delta, compression_var, quality_flags` | Granular visibility debugging |
| `actor_track_table` | `event_id, track_id, t_ms, class, bbox_x1y1x2y2, velocity_x, velocity_y, depth_median, in_path_flag` | Kinematic and conflict reconstruction |
| `window_level_feature_table` | `event_id, window_id, t_start_ms, t_end_ms, max_decel, max_jerk, audio_peak_count, max_ttc_proxy, lane_conflict_score` | Baseline continuous inputs for AI reasoning |
| `event_state_abstraction_table` | `event_id, window_id, brake_event_state, lead_hazard_state, evasive_maneuver_state, lane_departure_state` | Discrete states governing KB adjudication |
| `feature_attribution_table` | `event_id, target_model, feature_name, shap_value, baseline_value` | Reviewer explainability and ML transparency |

---

## 6. Master Algorithm & Model Matrix (Phase-1 Defaults)

| Layer | Component | Baseline Default / Method | Role / Constraint |
|---|---|---|---|
| Ingest | Media & Timeline Integrity | `ffprobe`, `cv2.VideoCapture`, `np.diff(PTS)` | Detect dropped/duplicate frames |
| Sync | Time Alignment | `scipy.signal.correlate`, Savitzky-Golay | Outputs `sync_confidence` |
| Perception | Object & Track | `YOLO11x + ByteTrack` | Tracks `visibility_duration`, drift |
| Perception | Lane & Drivable | `SegFormer (MMSegmentation)` | Fallback to drivable area if weak |
| Perception | Depth & Motion | `DepthAnythingV2`, `cv2.calcOpticalFlowFarneback` | Supports reaction/conflict metrics |
| Audio | Acoustic Context | `librosa.onset.onset_strength`, `peak_pick` | Temporal peak merging; SNR checks |
| Reasoning | Abstraction Layer | Rule-based discretization / Pandas rolling | Creates interpretable states for KB |
| Reasoning | Trigger & Outcome | `XGBoost + LightGBM + KB Logic` | Uses `shap.TreeExplainer` for attribution |
| Reasoning | Contradiction & Confidence | Deterministic IF/THEN Boolean logic | Enforces overrides; sets `needs_reviewer_attention` |
| Graph | Event Knowledge Graph | Document DB + `NetworkX / Neo4j` | Secondary analytical graph layer (async) |
| Ops | Explanations | `jinja2.Template` | No Generative LLM in Phase 1 |

---

## 7. Additional Enterprise Review & MLOps Processes

Beyond the runtime DAG, this system architecture explicitly supports the following MLOps workflows:

### 7.1 Event Segmentation Refinement
Clip timelines are segmented dynamically into:
- `pre_trigger_window`
- `trigger_moment`
- `post_trigger_consequence_window`

This optimizes playback and review navigation in the UI.

### 7.2 Reviewer Disagreement Analytics
The database tracks delta between `model_prediction` and `final_reviewer_decision`.

This identifies:
- `trigger_ambiguity_clusters`
- reviewer-vs-reviewer discrepancies

These patterns help highlight areas where Customer KB rules need clarification.

### 7.3 Hard-Negative Mining Loop
The system automatically flags high-value false positives for retraining, specifically isolating:
- strong brake events with no visual hazard
- lane departure false positives
- pedestrian false alarms
- rough-surface visual confusions

#### Tools, Libraries & Algorithms (MLOps & Review)

- **Orchestration:** `Prefect`, `Airflow`, `Ray Data / Core`
- **Annotation & QA:** `CVAT`, `FiftyOne`
- **Tracking & Lineage:** `MLflow`, `DVC`
