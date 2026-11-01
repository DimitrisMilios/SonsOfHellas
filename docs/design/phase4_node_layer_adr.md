# ADR-0002: Mobile Touch Ergonomics, Safe Area Adaptation & Map Integration

* **Status**: Accepted
* **Date**: 2026-11-01
* **Context**: Sons of Hellas — Phase 4 Presentation Layer Architecture

---

## 1. Context & Problem Statement

Phase 1 through Phase 3 established pure data models, mathematical engines, and a deterministic turn progression pipeline with zero Node dependencies. Phase 4 connects this engine to visual scene nodes under mobile constraints:
1. Touch targets must reliably measure $\ge 48\text{ px}$ in screen space across all camera zoom levels ($0.4\times$ to $2.2\times$), and tapping in ambiguous overlap areas between armies and settlements must resolve deterministically.
2. Modern mobile devices feature notches, camera cutouts, dynamic islands, and home gesture pills that occlude UI elements if anchored to raw screen edges.
3. Node2D visual entities (`ProvinceNode`, `ArmyNode`) must remain purely passive views of the simulation state, driven by unidirectional data flow, domain events, and view-models without circular object references or lifecycle leaks.

---

## 2. Decision & Architectural Specifications

### 2.1 Touch Ergonomics & Centralized Input Routing

* **Screen-Space Clamped Touch Targets**:
  * Instead of arbitrary linear inverse scaling, touch hitboxes enforce a minimum screen-space pixel diameter ($48\text{ px}$):
    $$\text{effective\_radius\_world} = \max\left(\text{base\_radius}, \frac{\text{MIN\_TOUCH\_PX}}{2 \cdot \text{zoom}.x}\right)$$
    With $\text{MIN\_TOUCH\_PX} = 48.0$.
  * Base dimensions:
    * `ProvinceNode`: radius $\ge 56\text{ px}$ (diameter $112\text{ px}$).
    * `ArmyNode`: hit box $\ge 52 \times 52\text{ px}$.
    * All HUD interactive buttons (`EndTurnButton`, tax steppers): $\ge 48\text{ px}$ height.
  * `CampaignCamera` emits `zoom_changed(new_zoom: Vector2)`; touch boundaries are updated only on this signal, avoiding per-frame layout recalculation.
* **Centralized `CampaignInputRouter`**:
  * Individual `Area2D` nodes do not handle selection or movement logic directly.
  * Touch input is captured centrally at the viewport level, converting screen positions to world coordinates.
  * **Gesture Discrimination**:
    * Tap gesture requires touch press and release within $10\text{ px}$ total displacement and $< 250\text{ ms}$ elapsed time.
    * Touch events exceeding these bounds are classified as camera pan/pinch gestures and never trigger entity selection.
    * Selection triggers strictly on touch release.
  * **Hit Arbitration Priority**:
    1. If touch coordinates fall inside an army's bounding box, the army is selected.
    2. Otherwise, select the nearest candidate (province or army) within its effective touch radius.
    3. **Tap-Again Cycling**: If tapping an occupied province where the army is already selected, the selection switches to the settlement.
  * **Command Gating**: The router rejects all selection and command events when `CampaignState != IDLE`.

---

### 2.2 Reusable Dynamic Safe Area Container

* **`SafeAreaContainer.gd`**:
  * Extends `MarginContainer`. Wraps all HUD root subpanels (TopBar, SelectionPanel, notifications, modals).
  * Queries `DisplayServer.get_display_safe_area()` against `DisplayServer.window_get_size()`, transforming physical display insets into viewport margin units via the viewport stretch factor.
  * Insets are applied on all four borders (`margin_top`, `margin_bottom`, `margin_left`, `margin_right`) plus an extra $8\text{ px}$ buffer on the bottom margin to clear the mobile gesture pill.
* **Robust Fallback & Dynamic Orientation Handling**:
  * Listens to `get_viewport().size_changed` and `NOTIFICATION_WM_SIZE_CHANGED`, debouncing updates by one frame to allow foldable device unfold and screen rotation animations to settle.
  * Zero / Invalid Safe Area: If `safe_area.size == Vector2i.ZERO` or lies outside window bounds (desktop editor, unit tests), falls back to safe zero-insets without collapsing layout.
  * Insets are clamped to a maximum threshold of $20\%$ of screen dimensions to prevent layout destruction on anomalous devices.
  * Includes a configurable `debug_safe_area_insets: Rect2i` flag for simulating notches and punch-holes during desktop development.

---

### 2.3 Unidirectional View Architecture & Node Lifecycle

* **Passive Views & View Models**:
  * Domain resources (`ProvinceData`, `ArmyData`, `FactionData`) and calculation engines are completely unaware of scene nodes.
  * `ProvinceNode` and `ArmyNode` are passive renderers. They store only entity identifiers (`province_id`, `army_id`) and read view-model snapshots (`ProvinceViewModel`, `ArmyViewModel`) emitted by `CampaignManager`.
  * `ProvinceViewModel`: encapsulates display name, owner faction color, settlement tier, public order score, unrest pressure badge, gross tax yield, and building slot cards.
  * `ArmyViewModel`: encapsulates army name, faction color, stance, current/max action points, unit cards with model count bars, veterancy chevrons, and role tags.
* **`CampaignMapView` & Destruction Safety**:
  * `CampaignMapView` manages scene node registries (`province_nodes: Dictionary[String, ProvinceNode]`, `army_nodes: Dictionary[String, ArmyNode]`).
  * Army visual destruction follows a strict sequence:
    1. Cancel all active tweens on the node.
    2. Clear active selection if the destroyed army was currently selected.
    3. Erase node entry from `army_nodes`.
    4. Call `node.queue_free()`.
    5. In any deferred callback, verify `is_instance_valid(node)`.
* **State Reconciliation & Event Playback**:
  * `CampaignMapView.rebuild_from_state(provinces, armies)` completely reconciles all scene nodes against current data models after save-game loading or playback fast-forwarding.
  * `MapEventPlayer` consumes the `TurnEventLog` emitted at turn turnover, playing cosmetic animations (building completion pulses, rebel siege appearances, conquest color shifts).
  * Animation playback is skippable and fast-forwardable; presentation animations never hold locks on domain state or turn progression.

---

### 2.4 Mobile Compact HUD Hierarchy

* **Summary-First Inspection Drawers**:
  * *Settlement Drawer*:
    * Tab 1 (Overview): Tier badge, owner banner, Public Order progress bar, unrest pressure badge ($0\text{--}2$), and clan food surplus/deficit.
    * Tab 2 (Economy): Single net wealth growth metric ($WG = PWG + NWG$) expandable on tap, accompanied by upper-class and lower-class $48\text{ px}$ tax stepper buttons ($[1..5]$).
    * Tab 3 (Buildings): Grid of slot cards displaying building tier, name, and "N turns remaining" badge for active construction.
  * *Army Drawer*:
    * Horizontal scrolling strip of unit cards ($\ge 48\text{ px}$ touch targets).
    * Unit cards render icon, remaining models / HP bar, veterancy chevrons ($1\text{--}5$), and role tag counter icons.
    * Fixed bottom footer for tactical stance picker (`NORMAL`, `FORCED_MARCH`, `RAIDING`, `ENCAMPMENT`, `AMBUSH`, `SIEGE`).
* Camera automatically applies an offset when a drawer opens to ensure the selected province or army remains unobstructed on compact screens.

---

## 3. Implementation Order

1. **Task 4.1: Input Routing & Touch Ergonomics (`res://scripts/world/CampaignInputRouter.gd`)**
   - Implement clamped hit-testing, gesture discrimination (tap vs pan), touch overlap arbitration, and unit tests in `tests/test_campaign_input_router.gd`.
2. **Task 4.2: Safe Area Container (`res://scripts/ui/SafeAreaContainer.gd`)**
   - Implement dynamic safe area margins, desktop fallback, notch simulation, and unit tests in `tests/test_safe_area_container.gd`.
3. **Task 4.3: View-Models & Passive Scene Nodes (`res://scripts/world/ProvinceNode.gd`, `res://scripts/world/ArmyNode.gd`, `res://scripts/world/CampaignMapView.gd`)**
   - Implement `ProvinceViewModel`, `ArmyViewModel`, passive rendering, zoom-reactive collision boundaries, view reconciliation, and unit tests in `tests/test_campaign_map_view.gd`.
4. **Task 4.4: Mobile Touch Camera (`res://scripts/world/CampaignCamera.gd`)**
   - Implement pinch-to-zoom, inertia damping, `zoom_changed` signal, and boundary clamping.
5. **Task 4.5: Compact Mobile Safe-Area HUD (`res://scripts/ui/CampaignHUD.gd`, `res://scenes/UI/CampaignHUD.tscn`)**
   - Implement $\ge 48\text{ px}$ touch targets, summary-first drawers, tax steppers, unit card scrollers, and view-model binding.
6. **Task 4.6: Campaign Orchestrator Integration & Bootstrap (`res://scripts/core/CampaignManager.gd`, `res://scenes/MainCampaign.tscn`)**
   - Wire input router, map view, HUD, and turn turnover into the main campaign loop with full headless validation.
