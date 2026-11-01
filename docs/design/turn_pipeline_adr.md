# ADR-0001: Turn Pipeline, Campaign State Machine & Offline Serialization

* **Status**: Accepted
* **Date**: 2026-11-01
* **Context**: Sons of Hellas — Phase 3 Campaign Architecture

---

## 1. Context & Problem Statement

The turn-based grand strategy campaign engine requires:
1. Executing a deterministic 7-step turn progression pipeline across human and computer-controlled factions without freezing the mobile UI thread (preventing Android Application Not Responding — ANR).
2. Handling state machine edge cases including rebellion generation, prevention of alternating tax exploits, deterministic multi-party conflict resolution, and deterministic bankruptcy attrition.
3. Upgrading `SaveManager` to perform complete, atomic, offline JSON serialization across all Phase 1 and Phase 2 custom Resource models (`UnitData`, `BuildingData`, `ProvinceData`, `FactionData`, `ArmyData`) without circular reference traps, partial writes, or memory corruption.

---

## 2. Decision & Architectural Specifications

### 2.1 ANR Prevention vs. Deterministic Turn Sequencing

* **Execution Threading**:
  * No secondary OS thread pool for simulation logic. Godot Resources are not thread-safe and the synchronization overhead on mobile creates race conditions. All simulation runs on the main engine thread.
* **Coroutine Frame-Slicing**:
  * Slicing uses a hybrid approach driven by an active microsecond time budget (`Time.get_ticks_usec()`).
  * The pipeline yields at every faction boundary during Stage 2 (AI Turn Processing) and Stage 4 (AI Strategic Movement) via `await Engine.get_main_loop().process_frame`.
  * Within a faction, after evaluating each army, if the elapsed time exceeds the per-frame calculation budget ($\sim 6000\text{--}8000\ \mu\text{s}$), the engine yields to the next frame.
  * Slicing is never permitted mid-army: each individual army's evaluate-then-commit phase is strictly atomic.
* **Input Gating**:
  * `CampaignManager` maintains a `CampaignState` enum (`IDLE`, `PROCESSING_TURN`, `AWAITING_PLAYER_BATTLE`, `PAUSED`).
  * Mutating campaign APIs (`execute_move`, `recruit_unit`, `construct_building`, `set_tax_level`, `end_turn`) pass through a single command gate that rejects execution whenever state is not `IDLE`.
  * UI layers observe `turn_processing_started` and `turn_processing_finished` purely to toggle visual overlay banners and disable interactive touch targets.
  * Hardware back buttons (`NOTIFICATION_WM_GO_BACK_REQUEST`) are ignored while `state != IDLE`.
  * On `NOTIFICATION_APPLICATION_PAUSED`, autosaving is only permitted if the state is `IDLE`. If paused during turn processing, the engine relies on the previous turn-boundary autosave.
* **Determinism & Event Buffering**:
  * Domain events occurring mid-pipeline are buffered in a `TurnEventLog` structure and dispatched at stage or turn conclusion. Signal handlers may notify presentation layers but must never mutate domain models during pipeline execution.
  * Processing loops iterate over factions, provinces, and armies sorted strictly by their unique string identifiers (`faction_id`, `province_id`, `army_id`).
  * Simulation RNG is contextualized and deterministic: seeds are computed per context via `hash(campaign_seed, turn, stage, faction_id)`.

---

### 2.2 Turn Progression State Machine & Edge Cases

* **The 7-Step Sequence**:
  1. *Step 1: Revenue Collection & Financial Update* (Base purse, tax yield, trade/raiding, wealth delta $WG = PWG + NWG$).
  2. *Step 2: Sequential AI Turn Execution* (Infrastructure budgeting, unit recruitment queues, rebel action).
  3. *Step 3: Construction & Recruitment Timers* (Decrement build/recruit timers, instantiate completed assets).
  4. *Step 4: AI Strategic Movement & Action Phase* (Army pathing, stance transitions, target scoring).
  5. *Step 5: Conflict Checks & Interception* (Field battles, siege declarations, pairwise combat resolution).
  6. *Step 6: Upkeep Deductions, Bankruptcy & Attrition* (Upkeep payments, deterministic bankruptcy desertion).
  7. *Step 7: Public Order & Seasonal Turn Reset* (Unrest pressure calculation, rebel army generation, AP restoration, date advance).

* **Rebellion Generation (Step 7)**:
  * Rebels spawn outside the settlement within the province borders and initiate a siege (`stance = ArmyData.Stance.SIEGE`). The settlement garrison remains intact inside the defenses.
  * Rebel forces are owned by `"faction_rebels"`, a non-strategic faction hostile to all entities with no diplomacy or treasury.
  * In Step 2 of subsequent turns, rebels execute a lightweight `RebelBehavior`: launch direct assault if power ratio $R_{\text{power}} \ge 1.0$, otherwise maintain the siege. They do not perform strategic map movement.
  * Rebel stack strength is budgeted based on `settlement_level` and unrest severity, drawing unit prototypes from `DataRegistry`. Spawned units receive unique runtime IDs.
  * Upon spawning rebels, regional unrest counters reset and enter a 2-turn cooldown.

* **Alternating Tax Exploit Fix**:
  * Prevent the alternating tax exploit ($PO < 0 \to PO \ge 0 \to PO < 0$) by implementing an asymmetric `unrest_pressure` accumulator:
    * Turns with $PO < 0$ add $+1$ to `unrest_pressure`.
    * Turns with $PO \ge \text{calm\_margin}$ (default $+10.0$) decrement `unrest_pressure` by $-1$.
    * Turns in the intermediate range ($0 \le PO < 10.0$) leave `unrest_pressure` unchanged.
  * Armed rebellion triggers when `unrest_pressure >= 2`.
  * Setting `calm_margin = 0` with instant reset preserves legacy behavior when toggled via configuration.

* **Deterministic Conflict Resolution (Step 5)**:
  * Army arrivals are grouped by destination `province_id` and sorted alphabetically.
  * Contenders within a province are ordered deterministically: `[already_present, movement_order_index, faction_id]`.
  * Friendly factions merge into defensive alliances; hostile factions resolve combat pairwise via `AutoResolveEngine`.
  * In pairwise battles, the victor carries forward remaining unit strength into subsequent engagements. Multi-way battles do not exist.
  * AI-vs-AI battles resolve automatically. Any engagement involving the human player transitions `CampaignState` to `AWAITING_PLAYER_BATTLE` and suspends the pipeline.

* **Retreat Chains & Zone Control**:
  * Tactical retreats are deferred until the province combat pass concludes.
  * Legal retreat destinations exclude provinces containing hostile forces or provinces that experienced hostile arrivals during the current turn.
  * Defeated forces with no legal retreat destination are routed and wiped out.
  * Retreat resolution runs at most two passes per province. If a retreated army is legitimately engaged a second time, `AutoResolveEngine`'s consecutive retreat rule triggers instant wipeout (`has_retreated_this_turn == true`).

* **Deterministic Bankruptcy Desertion (Step 6)**:
  * When a faction's treasury balance falls below zero and fails upkeep payment, desertion applies exclusively to field armies (garrisons and zero-upkeep units are immune).
  * Candidate units are ordered deterministically: `veterancy_rank` ascending $\to$ `tier` ascending $\to$ `unit_id` ascending.
  * Desertions cease immediately once the upkeep deficit is eliminated.
  * Desertion casualties are capped at a maximum of $25\%$ of any single army stack per turn.

---

### 2.3 SaveManager JSON Serialization & State Integrity

* **Full Domain Delegation**:
  * Discard legacy shallow dictionary serialization. `SaveManager` delegates serialization and deserialization completely to `ProvinceData.to_dict()`/`from_dict()`, `FactionData.to_dict()`/`from_dict()`, and `ArmyData.to_dict()`/`from_dict()`.
  * All object relationships use foreign-key String identifiers (`province_id`, `faction_id`, `army_id`, `unit_id`), preventing cyclic graph recursion and memory leakage.
  * `DataRegistry` prototypes remain immutable. A runtime unit represents a prototype baseline plus runtime deltas (unit count, veterancy chevrons, experience, remaining AP, active stance).
* **Two-Phase Deserialization & Link Validation**:
  * Phase 1: Construct and index all entities into isolated staging dictionaries.
  * Phase 2: Validate referential integrity (adjacent provinces exist, army owner factions exist, prototype references exist).
  * State swap into active `CampaignManager` occurs if and only if all entities validate successfully.
* **Atomic Disk Persistence**:
  * Saves are written to `user://saves/<slot>.json.tmp`.
  * After `store_string()`, the file is explicitly flushed (`file.flush()`) and closed.
  * The temporary file is verified by re-parsing.
  * Existing `<slot>.json` is rotated to `<slot>.json.bak`.
  * `DirAccess.rename_absolute()` performs the atomic promotion of the `.tmp` file to `<slot>.json`.
  * On load, the system attempts `<slot>.json`; if corrupted or missing, it recovers from `<slot>.json.bak`.
* **Versioning & Schema Migrations**:
  * Saves are encapsulated in a version envelope:
    ```json
    {
      "save_version": 2,
      "game_version": "1.0.0",
      "checksum": "...",
      "payload": { ... }
    }
    ```
  * Migrations are executed via pure dictionary transformer pipelines (`v1_to_v2`, `v2_to_v3`) prior to domain hydration.
  * Saves newer than the active game engine version fail safely with clear telemetry. Corrupted saves emit `load_failed(slot, error_code)` without mutating or destroying active campaign state.

---

## 3. Implementation Plan

1. **Task 3.1: Turn Execution Pipeline Controller (`res://scripts/core/TurnPipeline.gd`)**
   - Implement the 7-step turn progression engine, `TurnEventLog`, asymmetric unrest pressure, and deterministic conflict resolution.
   - Comprehensive unit tests in `tests/test_turn_pipeline.gd`.
2. **Task 3.2: AI Budgeting, Target Selection & Scoring Engine (`res://scripts/core/CampaignAIDecisionEngine.gd`)**
   - Implement dynamic phase weights ($\omega_{\text{infra}}, \omega_{\text{recruit}}, \omega_{\text{reserve}}$), target scoring $S_{\text{target}}$, tactical power ratio thresholds, and `RebelBehavior`.
   - Comprehensive unit tests in `tests/test_campaign_ai.gd`.
3. **Task 3.3: Mobile-Optimized TurnManager Autoload (`res://scripts/core/TurnManager.gd`)**
   - Refactor `TurnManager` with microsecond-budgeted frame slicing, input gating via `CampaignState`, and event emission.
   - Comprehensive unit tests in `tests/test_turn_manager.gd`.
4. **Task 3.4: Complete Schema Serialization & Atomic SaveManager (`res://scripts/core/SaveManager.gd`)**
   - Refactor `SaveManager` for atomic write/rename, `.bak` fallback, two-phase staging validation, envelope versioning, and full Phase 1/Phase 2 model integration.
   - Comprehensive unit tests in `tests/test_save_manager.gd`.
