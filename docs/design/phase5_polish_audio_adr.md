# ADR-0003: Mobile Polish, Sound/VFX Architecture & Save/Resume Lifecycle

* **Status**: Accepted
* **Date**: 2026-11-01
* **Context**: Sons of Hellas — Phase 5 Mobile Polish, Audio & Export Optimization

---

## 1. Context & Problem Statement

Phase 1 through Phase 4 established pure data models, mathematical engines, deterministic turn sequencing, and the presentation layer with touch ergonomics. Phase 5 prepares the project for production mobile deployment under real-world constraints:
1. **Rendering Performance & GLES3 Batching**: In Godot 4's `gl_compatibility` renderer, draw call proliferation, unbatched canvas items, and driver-unfriendly GPU particle systems degrade battery life and drop frames on mid-range mobile GPUs (Mali-G52/G57, Adreno 610/619).
2. **Audio Architecture & Resource Pooling**: Spawning dynamic audio nodes causes memory churn and audio dropouts. Android audio requires low-latency 48 kHz bus routing, priority stealing, and proper OS pause silencing.
3. **Save/Resume Lifecycle & OS Interruption Safety**: Background suspension by incoming phone calls or Android's Low Memory Killer (LMK) must never cause progress loss, even if interrupted mid-turn turnover.

---

## 2. Decision & Architectural Specifications

### 2.1 Rendering Performance & Canvas Batching (`gl_compatibility`)

* **Canvas Item Batching Rules**:
  * Untextured vector geometry with varying vertex colors does not break 2D batching in Godot 4. Batching breaks when texture, material, blend mode, clip, light, or z-order changes between consecutive draws.
  * Passive map entities (`ProvinceNode`, `ArmyNode`, road drawers, badges) must use **zero custom ShaderMaterials** and **no CanvasItemMaterial overrides**. Color variations must use `modulate` and `self_modulate` only.
  * An automated material lint test verifies that all passive presentation scenes reference zero materials.
* **Texture Atlas Packaging**:
  * Textures are grouped into targeted atlases ($\le 2048 \times 2048$):
    * `map_atlas.png`: Settlement tier badges, faction banners, tactical stance markers, road textures, and particle sprites.
    * `ui_atlas.png`: HUD buttons, icons, card frames, and dialog decorations.
  * Slices are referenced via `AtlasTexture`.
  * Z-indices are assigned so that all `map_atlas` draws are contiguous within a layer; map and UI textures are never interleaved.
* **Entity Drawing & Lifecycle**:
  * Custom `_draw()` routines are cached by Godot and re-rendered only when invalidation signals call `queue_redraw()`.
  * No `_process` loops on passive map entities.
  * Because `CampaignInputRouter` performs centralized distance and box hit-testing, redundant `Area2D` and `CollisionShape2D` nodes are removed from `ProvinceNode` and `ArmyNode`.
  * Frustum culling relies on Godot's built-in canvas culling. No `VisibleOnScreenNotifier2D` on individual nodes.
* **VFX Particle Pool (`CPUParticles2D`)**:
  * `GPUParticles2D` is strictly banned on the campaign map due to GLES3 driver inconsistencies and shader compilation stalls.
  * All VFX utilize `CPUParticles2D` with an unshaded texture from `map_atlas.png`.
  * Hard Budgets:
    * March Dust: $\le 12$ particles.
    * Siege Smoke: $\le 16$ particles.
    * Battle Sparks: $\le 12$ particles (one-shot).
    * Maximum 4 active emitters visible simultaneously; global live particle limit of 64.
  * `VFXPool`: Pre-allocates a fixed pool of 6 `CPUParticles2D` emitters attached to `CampaignMapView`. Emitters are re-triggered via `restart()`. Zero runtime node allocations or frees.
  * When the pool is exhausted, new effects are dropped (VFX are purely cosmetic). Effects are skipped at camera zoom $< 0.6$ or when the "Reduce Effects" setting is enabled.
  * Emitters check the camera visible rectangle before starting so off-screen effects never spawn.

---

### 2.2 Mobile Audio Management & Bus Topology

* **Bus Topology & Native Mix Rate**:
  * Standardized project setting: `audio/driver/mix_rate = 48000` (matching standard Android hardware audio pipelines to eliminate runtime software resampling).
  * Audio Buses: `Master` $\rightarrow$ `Music`, `Ambience`, `SFX`, `UI`.
* **Dynamic Audio Ducking**:
  * `AudioManager.duck(bus_names, db = -6.0, attack = 0.15, hold = 0.5, release = 0.6)` smoothly tweens bus volumes.
  * Only one active tween per bus; existing tweens are killed before new ones start to prevent volume compounding.
* **Stream Formats & Looping**:
  * Ogg Vorbis (`.ogg`): Background music and long-form ambience (streamed from disk). Seamless looping configured via import loop flags.
  * Uncompressed WAV (16-bit mono, 48 kHz): Short SFX (button clicks, coins, march footsteps, battle clashes) and short ambience loops ($< 10\text{ s}$).
  * Dual-player cross-fading is reserved strictly for theme transitions (e.g., Campaign Map to Battle Theme).
* **`AudioManager` Autoload & Fixed Pool**:
  * Singleton autoload holding pre-allocated, non-positional `AudioStreamPlayer` nodes:
    * 8 SFX Players
    * 2 Music / Ambience Players (for cross-fades)
    * 2 UI Players
  * Priority & Stealing Policy:
    * Priorities: UI/Critical = 3, Battle = 2, Ambient One-Shots = 1.
    * When all players are active, steal the oldest player at the lowest priority if `new_sound_priority >= candidate_priority`. Otherwise, drop the new sound.
    * Rate Limiting: Minimum 60 ms retrigger delay for identical sound IDs; maximum 2 simultaneous instances of any single sound.
* **OS Lifecycle Silence**:
  * `NOTIFICATION_APPLICATION_PAUSED` & `NOTIFICATION_APPLICATION_FOCUS_OUT`: Mute `Master` bus and pause all active players.
  * `NOTIFICATION_APPLICATION_RESUMED` & `NOTIFICATION_APPLICATION_FOCUS_IN`: Unmute with a 0.3s fade-in, resuming music playback seamlessly from its paused position.

---

### 2.3 Save/Resume Lifecycle & Two-Phase Autosave Protection

* **Two-Phase Autosaves**:
  1. **Turn-Start Autosave**: Automatically triggered in `TurnManager._finalize_turn_completion()` when the campaign enters `IDLE` state at the beginning of the player's turn.
  2. **Turn-Commit Autosave**: Triggered upon pressing "End Turn", immediately before transitioning to `PROCESSING_TURN`.
     * Writes player orders to disk with `turn_committed = true`.
     * If the app is killed by Android LMK mid-AI execution, loading this save causes the deterministic turn pipeline to replay using context seeds `hash(campaign_seed, turn, stage, faction_id)`, reconstructing the exact post-turn outcome.
  * Serialization occurs synchronously on the main thread; file I/O is dispatched via `WorkerThreadPool` tasks behind UI turnover banners.
* **Pause-Time Emergency Autosave**:
  * On `NOTIFICATION_APPLICATION_PAUSED`, autosave triggers synchronously only if campaign state is `IDLE`.
  * Skips JSON read-back verification on pause to stay within critical mobile suspension time budgets ($< 30\text{ ms}$).
* **Three-Tier Save Recovery Order**:
  * Load order:
    1. `slot.json` (Main save)
    2. `slot.json.tmp` (Promoted if valid JSON and matching checksum)
    3. `slot.json.bak` (Previous turn backup)
  * Fallbacks are non-blocking: logs the fallback and displays a transient recovery notification toast without crashing or displaying error dialogs.
  * Stale `.tmp` files are pruned after successful load.
* **Cold Start vs. Warm Resume**:
  * Warm Resume: Process kept alive in background. Viewport safe-areas re-evaluate, audio unpauses, state remains untouched.
  * Cold Start: Process launched after termination. Displays Main Menu / Title Screen featuring a prominent "Continue" button populated with autosave metadata (faction name, turn number, timestamp).

---

## 3. Implementation Plan

1. **Task 5.1: Material Lint & Scene Optimization**
   - Remove `Area2D` from `ProvinceNode` and `ArmyNode`.
   - Implement unit test `test_material_lint.gd` verifying passive nodes have zero materials and no `_process`.
2. **Task 5.2: VFX Particle Pool (`VFXPool.gd`)**
   - Implement fixed 6-emitter `CPUParticles2D` pool in `CampaignMapView`.
   - Add unit tests `test_vfx_pool.gd` validating pool exhaustion, dropping, and zoom culling.
3. **Task 5.3: Centralized `AudioManager` & Channel Stealing**
   - Implement `AudioManager.gd` autoload with 12 fixed players, priority stealing, ducking, and pause silencing.
   - Add unit tests `test_audio_manager.gd` validating rate limits, priority stealing, and bus volume tweens.
4. **Task 5.4: Two-Phase Turn Autosave & Fallback Resilience**
   - Update `TurnManager.gd` and `SaveManager.gd` for turn-start and turn-commit autosaves.
   - Implement fallback order (`main` $\rightarrow$ `tmp` $\rightarrow$ `bak`) and deterministic replay on `turn_committed`.
   - Add unit tests `test_save_resilience.gd` validating corrupt main, corrupt tmp, missing main, and pipeline replay.
5. **Task 5.5: Title Screen & Cold-Start Bootstrap**
   - Create `TitleScreen.tscn` / `TitleScreen.gd` reading autosave metadata for one-tap resume.