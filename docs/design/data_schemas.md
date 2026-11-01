### 1\. `UnitCard` Schema

Represents a military unit template, containing base combat attributes, economic maintenance costs, and class counter tags.

```
interface UnitCard {
  /** Unique unit identifier string */
  id: string; // e.g., "unit_katana_samurai"

  /** Display name of the military unit */
  name: string; // e.g., "Katana Samurai"

  /** Initial purchase cost to recruit the unit [200 - 2500 koku/gold] */
  recruitment_cost: number; // uint [1] [2, 3]

  /** Per-turn recurring maintenance expense [50 - 400 koku/gold per turn] */
  upkeep_cost: number; // uint [4] (e.g., Line Infantry = 230, Militia = 170) [3, 5]

  /** Number of campaign turns required to finish training [1 - 3 turns] */
  recruitment_turn_time: number; // uint [6, 7] [8]

  /** Unit quality tier level [1: Ashigaru/Militia, 2: Samurai/Line, 3: Elite, 4: Hero] */
  tier: number; // uint [6, 9] [2, 10, 11]

  /** Numerical combat attributes */
  stats: {
    /** Total soldier models per regiment [40 - 160 models] */
    unit_count: number; // uint [12, 13] [14, 15]

    /** Melee attack score; increases hit probability roll */
    melee_attack: number; // uint [6, 16] [15]

    /** Melee defense score; decreases incoming hit probability roll */
    melee_defense: number; // uint [16] [15]

    /** Armor rating; secondary block check post-defense &amp; increases physical mass */
    armor: number; // uint [17] [15]

    /** Temporary bonus added to melee attack &amp; initiative upon charging */
    charge_bonus: number; // uint [12] (decays rapidly post-impact) [15]

    /** Precision rating of ranged shots at release point [4-7, 9, 10, 12, 16-108] */
    missile_accuracy: number; // uint [108] [15]

    /** Reload animation speed multiplier [4-7, 9, 10, 12, 16-108] */
    reload_speed: number; // uint [108] [15]

    /** Maximum effective firing distance [0 - 200 meters] */
    missile_range: number; // uint [1] (reduced by night/weather) [11, 15, 109]

    /** Ballistic payload classification */
    ammo_type: "STANDARD_ARROW" | "FIRE_ARROW" | "MATCHLOCK_BULLET" | "CANNON_BALL" | "SHRAPNEL"; // [15, 110]
    // Note: MATCHLOCK_BULLET completely ignores enemy armor rating [15]

    /** Total missile ammunition capacity per battle [0 - 40 rounds] */
    ammo_capacity: number; // uint [12] [15]

    /** Base bravery score determining routing threshold [6, 7, 9, 16-42] */
    morale: number; // uint [6, 16] (modified by general aura, casualties, rear charges) [15, 111]

    /** Maximum stamina capacity [4-7, 9, 10, 12, 16-108]; running/fighting drains stamina and impacts morale */
    fatigue_max: number; // uint [108] [11, 15]

    /** Physical model mass modifier for charge calculations &amp; anti-cavalry bracing [1.0 - 5.0] */
    mass: number; // float [1.0, 5.0] [15]

    /** Accumulated unit rank chevrons [6, 7, 9, 18-23]; boosts attack, defense, accuracy, and morale */
    veterancy_rank: number; // uint [23] [45, 74, 112]
  };

  /** Tactical matchup classification tags for rock-paper-scissors combat logic */
  role_tags: Array&lt;
    | "INFANTRY_SPEAR"      // Countered by Katana; Counters Cavalry [113]
    | "INFANTRY_KATANA"     // Counters Spear Infantry; Countered by Cavalry Charge [113]
    | "CAVALRY_LIGHT"       // Counters Ranged/Flankers; Countered by Spears [113, 114]
    | "CAVALRY_HEAVY"       // High charge bonus; Countered by Spears [15, 113]
    | "MISSILE_BOW"         // High rate of fire; Weak in melee [15, 114]
    | "MISSILE_MATCHLOCK"   // Armor-penetrating; Slow reload &amp; weak in melee [15, 114]
    | "ARTILLERY"           // Long range defense/wall destruction; Low melee [110, 114]
    | "HERO_UNIT"           // High stats &amp; small model count [11]
  &gt;;
}
```



### 2\. `BuildingNode` Schema

Defines province and castle structures, including economic output, food balance, unlock constraints, and auto-garrison capabilities.

```
interface BuildingNode {
  /** Unique building structure ID */
  id: string; // e.g., "bld_rice_exchange_tier2"

  /** Functional classification of the building line */
  branch_type:
    | "GOVERNMENT_PALACE" // Provides tax efficiency % &amp; public order repression [39, 81]
    | "MILITARY_BARRACKS"  // Enables higher tier unit recruitment [81, 115]
    | "INDUSTRY_WEAVING"   // Static wealth generation &amp; cloth exports [43, 63, 64]
    | "INDUSTRY_METALWORK" // Static wealth generation &amp; mine output [43, 63, 64]
    | "FARMING"            // Provides food production &amp; population growth [65, 95, 116]
    | "COMMERCIAL_PORT"    // Sea trade lanes &amp; regional wealth generation [43, 49, 82]
    | "FISHING_PORT"       // Population growth &amp; static fish income [61, 82]
    | "ACADEMY_SCHOOL"     // Research speed bonus; generates clamor for reform [68, 86]
    | "FORTIFICATION";     // Expands castle slots, garrison, and food consumption [87, 116, 117]

  /** Upgrade tier within the building branch [6, 7, 9, 18, 19] */
  upgrade_level: number; // uint [6, 19] [4, 39, 49, 81, 117]

  /** Construction treasury cost [300 - 4000 koku/gold] */
  construction_cost: number; // uint  (e.g., Market = 850, Ring Forts = 4000) [10, 87]

  /** Construction duration in turns [1 - 5 turns] */
  turns_to_build: number; // uint [6, 19] (e.g., Market = 3 turns) [10]

  /** Economic &amp; resource outputs generated per turn */
  income_output: {
    /** Fixed wealth added directly to regional asset base [0 - 1500 koku] */
    base_wealth: number; // uint  (e.g., Market = 200, Cloth Mill = 1312–1500) [10, 64]

    /** Per-turn local positive wealth growth delta (PWG) [0.0 - 50.0] */
    positive_wealth_generation: number; // float [0.0, 50.0] (e.g., Rice Exchange = +5) [43, 95]

    /** Empire-wide negative growth penalty applied to all clan provinces [-1.0 to 0.0] */
    negative_wealth_generation_penalty: number; // float [-1.0, 0.0] (e.g., Rice Exchange = -1 global/province) [95]

    /** Tax efficiency percentage bonus added to provincial rate [0.03 - 0.15] */
    tax_modifier_bonus: number; // float [0.03, 0.15] (+3%, +6%, +9%, +12%, +15%) [39, 81]

    /** Food balance contribution [-5 to +10]; Farms provide +, Castles/Markets consume - */
    food_production_delta: number; // int [-5, 10] [3, 93, 95, 116]
  };

  /** Free garrison units spawned automatically during defense */
  garrison_units_granted: Array&lt;{
    unit_card_id: string; // Foreign key referencing UnitCard.id
    quantity: number;     // uint [6, 20] [87, 118]
  }&gt;;

  /** Unlocking prerequisites &amp; structural dependencies */
  unlock_requirements: {
    /** Technology ID required from Mastery of the Arts tree */
    required_technology_id: string | null; // [67, 116, 119]

    /** Strategic resource required in clan network */
    required_resource_type: "HORSES" | "TIMBER" | "SILK" | "IRON" | "STONE" | "NONE"; // [2, 120]

    /** Minimum castle tier required in settlement [6, 7, 9, 18, 19] */
    required_settlement_level: number; // uint [6, 19] [95, 116, 117]

    /** Mutually exclusive branch ID in the same building slot */
    mutually_exclusive_branch_id: string | null; // e.g., Government Palace vs Barracks [81, 82]
  };
}
```


### 3\. `Settlement` Schema

Maintains the state variables of a province capital, tracking population growth, public order balance, active garrisons, and construction slots.

```
interface Settlement {
  /** Settlement entity identifier */
  id: string; // e.g., "set_kyoto"

  /** Parent province ID &amp; campaign map coordinate vector */
  province_id: string; // [35, 121]
  coordinates: {
    x: number; // float [35, 117, 122]
    y: number; // float [35, 117, 122]
  };

  /** Castle level tier [1: Fort, 2: Stronghold, 3: Fortress, 4: Castle, 5: Citadel] */
  level: number; // uint [6, 19] [39, 116, 117]

  /** Active construction slots (length bounded strictly by level: Level 1 = 1 slot, Level 5 = 5 slots) */
  building_slots_array: Array&lt;{
    slot_index: number; // uint [9]
    building_node_id: string | null; // Foreign key referencing BuildingNode.id [95, 117]
    is_under_construction: boolean;
    remaining_construction_turns: number; // uint [19]
  }&gt;;

  /** Combined military garrison (Stationed field armies + auto-garrison from buildings) */
  active_garrison_array: Array&lt;{
    unit_card_id: string; // Foreign key referencing UnitCard.id
    current_unit_count: number; // uint [6, 13]
    experience_chevrons: number; // uint [23]
    is_building_garrison: boolean; // True if granted by building node [87, 115, 118]
  }&gt;;

  /** Net public order/happiness score [-100 to +100] */
  public_order_value: number; // int [-100, 100] [37, 72, 85, 118, 123]

  /** Controlling faction identifier */
  owner_faction_id: string; // [35, 124, 125]

  /** Cumulative economic asset base of the region */
  region_wealth: number; // float [0.0, 100000.0] [16, 35]

  /** Accumulated growth surplus points required to unlock new building slots */
  population_surplus: number; // uint [108] [126]

  /** Tax exemption status flag (if true, tax rate = 0%, eliminating tax unrest &amp; boosting growth) */
  tax_exemption_status: boolean; // [37, 125]

  /** Counter tracking consecutive turns where public_order_value &lt; 0 */
  consecutive_unrest_turns: number; // uint [18]
  // Rule: Reaching 2 consecutive turns triggers an armed rebellion army spawn [93]

  /** Resistance to foreign occupation unrest penalty decay rate */
  resistance_to_occupation_decay: number; // int [-30, 0] (decays toward 0 each turn post-conquest) [76, 118]
}
```


Data Schema Dependencies & Numerical ConstraintsSlot Capacity Limit: building_slots_array.length is constrained by Settlement.level (Level 1 Fort grants 1 slot; Level 5 Citadel grants 5 slots)12.Rebellion Trigger: If Settlement.public_order_value < 0 for consecutive_unrest_turns == 2, an independent rebel army spawns outside the castle town34.Armor Penetration Rule: When UnitCard.stats.ammo_type == "MATCHLOCK_BULLET", defender UnitCard.stats.armor is set to 0 during hit resolution5.Empire Wealth Growth Metric: Regional wealth growth $WG$ is updated per turn as $WG = PWG + NWG$, where $NWG$ is derived from upper-class tax levels67.