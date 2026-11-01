# Sons of Hellas - Campaign Map Architecture

**Genre:** Turn-Based Grand Strategy Campaign Map (Classical Greek Setting)  
**Target Engine:** Godot 4.x (GDScript, strict typing)

---

## 1. Directory Structure

```text
SonsOfHellas/
├── project.godot                     # Godot 4 engine config with Autoloads & display settings
├── scenes/
│   ├── MainCampaign.tscn             # Primary campaign map scene
│   ├── ProvinceNode.tscn             # Visual & interactive settlement node
│   ├── ArmyNode.tscn                 # Visual & interactive army piece
│   └── UI/
│       └── CampaignHUD.tscn          # Campaign HUD (Top bar, Selection cards, Battle modal)
├── resources/
│   ├── units/                        # UnitData presets (.tres)
│   │   ├── spartan_hoplites.tres
│   │   ├── athenian_hoplites.tres
│   │   ├── thessalian_cavalry.tres
│   │   ├── cretan_archers.tres
│   │   └── thracian_peltasts.tres
│   ├── buildings/                    # BuildingData presets (.tres)
│   │   ├── agora.tres
│   │   ├── hoplite_barracks.tres
│   │   └── temple_of_athena.tres
│   ├── factions/                     # FactionData presets (.tres)
│   │   ├── sparta.tres
│   │   ├── athens.tres
│   │   └── thebes.tres
│   ├── provinces/                    # ProvinceData presets (.tres)
│   │   ├── sparta.tres
│   │   ├── corinth.tres
│   │   ├── athens.tres
│   │   └── thebes.tres
│   └── armies/                       # ArmyData presets (.tres)
│       ├── spartan_army.tres
│       └── athenian_army.tres
└── scripts/
    ├── core/                         # Core orchestration singletons & logic
    │   ├── TurnManager.gd            # Central turn cycle & economy pipeline
    │   ├── CampaignManager.gd        # Selection, AP movement validation & triggers
    │   ├── AutoResolveCalculator.gd  # Pure combat math & casualty simulation
    │   ├── BattleResult.gd           # Structured combat output data class
    │   └── MainCampaign.gd           # Campaign map entrypoint & world spawner
    ├── data/                         # Custom Resource definitions
    │   ├── UnitData.gd               # Unit stats, role enum & combat values
    │   ├── BuildingData.gd           # Province upgrades & recruitment unlocks
    │   ├── FactionData.gd            # Faction treasury & identity
    │   ├── ProvinceData.gd           # Settlement tier, tax, order, garrison
    │   └── ArmyData.gd               # Roster, leadership, AP & stances
    ├── world/                        # 2D world nodes & viewport controls
    │   ├── ProvinceNode.gd           # Map settlement visualization & clicks
    │   ├── ArmyNode.gd               # Map army banner, AP bar & movement tween
    │   └── CampaignCamera.gd         # Pan (WASD/Drag) & smooth wheel zoom
    └── ui/
        └── CampaignHUD.gd            # HUD controller & event subscriber
```

---

## 2. Core Custom Resources (`scripts/data/`)

### `UnitData.gd` (`extends Resource`)
- **Properties:**
  - `unit_id: String`: Unique technical identifier.
  - `display_name: String`: Human-readable name.
  - `tier: int` (1–5): Unit quality and veterancy bracket.
  - `role: Role` (Enum: `HOPLITE`, `CAVALRY`, `RANGED`, `SKIRMISHER`): Tactical role used in rock-paper-scissors counter calculations.
  - `base_strength: float`: Raw health and manpower fighting power.
  - `armor: float`: Damage mitigation percentage.
  - `recruitment_cost: int` / `turn_upkeep: int`: Gold costs.
- **Formula:**
  $$\text{Combat Value} = \text{base\_strength} \times \left(1.0 + \frac{\text{armor}}{100}\right) \times \left(1.0 + (\text{tier} - 1) \times 0.15\right)$$

### `ProvinceData.gd` (`extends Resource`)
- **Properties:**
  - `province_id: String`, `province_name: String`, `owner_faction_id: String`.
  - `settlement_tier: int` (1–5): Settlement size and building capacity.
  - `public_order: float` (-100.0 to 100.0): Civil stability.
  - `base_tax: float`: Baseline gold production.
  - `growth_rate: float`: Population growth per turn.
  - `building_slots: Array[BuildingData]`: Upgrades constructed in the province.
  - `garrison_units: Array[UnitData]`: Default settlement defenders.
  - `adjacent_province_ids: Array[String]`: Graph adjacency connections for army routing.
  - `map_position: Vector2`: 2D campaign map coordinates.

### `ArmyData.gd` (`extends Resource`)
- **Properties:**
  - `army_id: String`, `army_name: String`, `owner_faction_id: String`, `current_province_id: String`.
  - `units: Array[UnitData]`: Active roster.
  - `general_leadership_rating: float` (0.5 to 3.0): General commanding skill.
  - `current_action_points: float` / `max_action_points: float`: Movement pool (default 100).
  - `stance: Stance` (Enum: `DEFAULT`, `FORCED_MARCH`, `ENCAMP`, `SIEGE`).

---

## 3. Core Singletons & Controllers (`scripts/core/`)

### `TurnManager.gd` (Autoload `TurnManager`)
- **State:** Central turn counter (`current_turn`), faction registry (`registered_factions`), and active faction index (`active_faction_index`).
- **Signal Pipeline:**
  - `turn_started(turn_number: int, active_faction: FactionData)`
  - `turn_ended(turn_number: int, ended_faction: FactionData)`
  - `faction_turn_changed(active_faction: FactionData)`
  - `player_gold_changed(new_gold: int, delta: int)`
  - `round_completed(new_turn_number: int)`
- **Behavior:** Increments turn count when round completes, processes faction treasury additions/deductions, resets AP for the acting faction.

### `AutoResolveCalculator.gd` (`extends RefCounted`)
Pure functional logic calculating automated combat:
1. **Effective Power:**
   - Multiplies unit combat value by tactical counter bonuses:
     - Hoplites receive +15% against Cavalry.
     - Cavalry receives +20% against Ranged.
     - Ranged receives +15% against unscreened Hoplites.
     - Skirmishers receive +10% against Hoplites.
   - General leadership multiplier: $0.7 + (\text{leadership} \times 0.3)$.
   - Stance modifiers:
     - Forced March: -25% power (exhaustion).
     - Encamp: +30% power when defending (palisade fortifications).
2. **Win Probability:**
   $$P_{\text{attacker}} = \text{clamp}\left(\frac{\text{Power}_{\text{att}}^{1.5}}{\text{Power}_{\text{att}}^{1.5} + \text{Power}_{\text{def}}^{1.5}}, 0.02, 0.98\right)$$
3. **Casualty Allocation:**
   - Evaluates unit survivability based on tier and armor rating.
   - Distributes losses into `survivors` and `destroyed_units`.

### `CampaignManager.gd` (Autoload `CampaignManager`)
- Orchestrates campaign map selection state (`selected_province`, `selected_army`).
- Validates army movement:
  - Adjacency check via `current_province.is_adjacent_to(target_province_id)`.
  - AP check (default 40 AP, reduced to 32 AP in Forced March).
- Triggers field battles and settlement sieges when moving into hostile provinces.
- Transfers province ownership when garrisons are routed.

---

## 4. Camera & World Controls

- **Pan:** `W, A, S, D` or `Arrow Keys`, or hold **Middle Mouse / Right Mouse** and drag.
- **Zoom:** **Mouse Scroll Wheel** (smooth interpolation between 0.4x and 2.2x).
- **Selection:**
  - Left-click a province to inspect settlement stats, public order, and garrison.
  - Left-click an army to inspect general rating, AP, tactical stance, and roster.
  - With an army selected, left-click an adjacent province to order movement or attack.
