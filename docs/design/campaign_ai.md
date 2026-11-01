# Technical Specification: Turn Execution Pipeline & AI Decision Engine

This document defines the turn processing sequence, computer player (AI) resource allocation models, and tactical decision scoring algorithms for campaign-level campaign simulation, synthesized from *Total War* system mechanics and engine rules.

---

## 1. Turn Execution Pipeline

When the active player clicks the **End Turn** command [92, 161], the campaign state machine executes a deterministic sequence of operations across all active human and computer-controlled factions [10, 209]. 

```
[End Turn Trigger] 
       │
       ▼
 1. Active Faction Tax & Revenue Settlement ──► (Add Base Purse, Taxes, Trade & Raiding)
       │
       ▼
 2. Sequential AI Faction Processing ────────► (Run AI Logic per Faction in Turn Order)
       │
       ▼
 3. Infrastructure & Unit Build Queue Tick ───► (Decrement Construction & Recruitment Timers)
       │
       ▼
 4. Strategic Movement & Action Phase ───────► (Agent Actions & Army Movement Pathing)
       │
       ▼
 5. Collision & Conflict Resolution ──────────► (Siege Declaration, Field Battles & Interception)
       │
       ▼
 6. Upkeep Deductions & Attrition Evaluation ──► (Deduct Army Maintenance, Apply Winter/Supply Loss)
       │
       ▼
 7. Public Order & Global State Reset ────────► (Apply Public Order Delta, Reset AP, Increment Turn)
```

---

### Step-by-Step Pipeline Specifications

#### Step 1: Revenue Collection & Financial Update
* **Income Calculation:** Active faction gross income is calculated and deposited into the treasury:
  $$I_{\text{gross}} = \sum I_{\text{tax}} + I_{\text{trade}} + I_{\text{purse}} + I_{\text{tribute}} + I_{\text{raiding}}$$
  Where $I_{\text{tax}}$ accounts for regional taxation yields [23, 85], $I_{\text{trade}}$ for sea/land trade agreements [20, 35], $I_{\text{purse}}$ for baseline national allowance [33], $I_{\text{tribute}}$ for vassal contributions [34], and $I_{\text{raiding}}$ for trade lane blockades [34, 45].
* **Wealth Delta Application:** Positive and negative wealth growth values ($PWG + NWG$) are applied to regional wealth pools ($W_{\text{region}}$) [31, 32].

#### Step 2: Sequential AI Turn Execution
* AI factions execute their turn logic sequentially according to turn order [209].
* **Fog of War Visibility:** CPU movement and action rendering are filtered by player Line of Sight (LOS) settings [209].

#### Step 3: Construction & Recruitment Progress Timers
* **Building Progress:** Timers ($T_{\text{build}}$) for structural upgrades (castles, markets, farms, ports) decrement by 1 turn [85]. Completed buildings instantly update settlement stats and unlock recruitment slots [205, 206].
* **Unit Recruitment Queue:** Unit construction timers decrement by 1 turn [208]. Units reaching $T=0$ are spawned into local garrisons or host armies [118, 208].

#### Step 4: AI Strategic Movement & Agent Deployment
* AI factions calculate strategic vectors and execute movement for armies and agents using allocated Action Points ($AP_{\text{max}}$) [120, 129, 207].
* Agent subterfuge and religious actions (assassination, sabotage, bribery) are resolved against target stats [130, 209].

#### Step 5: Conflict Checks & Interception
* **Zone of Control Collisions:** Moving forces entering hostile ZoC trigger engagement prompts or interceptions [120, 136, 207].
* **Siege & Field Battle Resolution:** Battles triggered by AI movement are queued for real-time tactical combat or auto-resolve calculation [4, 210, 212].
* **Settlement Resolution Choice:** Victorious AI armies execute settlement fate algorithms (Peaceful Occupation, Sack, or Vassalize/Subjugate) based on personality traits [210].

#### Step 6: Upkeep Deductions, Bankruptcy & Attrition Checks
* **Upkeep Payment:** Recurring military costs ($U_{\text{army}} + U_{\text{navy}} + U_{\text{watch}}$) are deducted from treasury balances [20, 61, 203].
* **Bankruptcy Failure Check:** If Treasury Balance $< 0$, global bankruptcy triggers: random unit desertion occurs and capital wealth growth penalties are applied [33, 64].
* **Environmental Attrition:** Armies in harsh climate zones (winter snow, desert, swamp) or suffering food deficits ($F_{\text{net}} < 0$) lose a percentage of unit model counts [168, 204].

#### Step 7: Public Order & Seasonal Turn Reset
* **Public Order Accumulation:** Net Public Order delta is added to regional happiness meters [127]. If $PO < 0$ for two consecutive turns, rebel armies spawn outside the settlement [84].
* **Action Point Reset:** All character and unit AP pools are fully restored ($AP_{\text{current}} = AP_{\text{max}}$) [120].
* **Date Advance:** Campaign calendar increments by 1 season/turn [10, 209].

---

## 2. AI Budgeting & Resource Allocation

Computer players evaluate available seasonal funds ($Treasury_{\text{available}}$) and allocate capital across three core financial buckets: **Infrastructure**, **Recruitment**, and **Reserve Pools** [84, 88].

$$\text{Treasury}_{\text{available}} = I_{\text{net}} + \text{Treasury}_{\text{current}}$$

### 2.1 Budget Allocation Formulas

The total available funds are distributed according to dynamic strategic priority weights ($\omega_{\text{infra}}$, $\omega_{\text{recruit}}$, $\omega_{\text{reserve}}$):

$$\begin{aligned}
B_{\text{infra}} &= \text{Treasury}_{\text{available}} \times \omega_{\text{infra}} \\
B_{\text{recruit}} &= \text{Treasury}_{\text{available}} \times \omega_{\text{recruit}} \\
B_{\text{reserve}} &= \text{Treasury}_{\text{available}} \times \omega_{\text{reserve}}
\end{aligned}$$

Where:
$$\omega_{\text{infra}} + \omega_{\text{recruit}} + \omega_{\text{reserve}} = 1.0$$

```
                               ┌──────────────────────────────────┐
                               │ Treasury Available (Net + Cache) │
                               └────────────────┬─────────────────┘
                                                │
         ┌──────────────────────────────────────┼──────────────────────────────────────┐
         ▼                                      ▼                                      ▼
┌─────────────────────────┐           ┌─────────────────────────┐           ┌─────────────────────────┐
│ Infrastructure Budget   │           │ Recruitment Budget      │           │ Emergency Reserve Pool  │
│ (Farms, Ports, Castles) │           │ (Units & Upkeep Cap)    │           │ (Agent & Repair Fund)   │
└─────────────────────────┘           └─────────────────────────┘           └─────────────────────────┘
```

---

### 2.2 Strategic Phase Weighting Mechanics

AI resource weighting shifts dynamically across campaign phases based on economic philosophy (e.g. military expansionist vs. infrastructural development) [84, 88, 199]:

#### **Early Campaign Phase (Expansion Focus)**
AI prioritizes army expansion over long-term Return-on-Investment (ROI) infrastructure projects due to slow building break-even periods (e.g. 11.5–14 turns for market structures) [85].
$$\omega_{\text{infra}} = 0.25, \quad \omega_{\text{recruit}} = 0.60, \quad \omega_{\text{reserve}} = 0.15$$

#### **Mid-Campaign Phase (Consolidation & Border Defense)**
After expanding borders, AI rebalances toward agricultural food production ($F_{\text{net}}$) and border defense posts [87, 88, 89].
$$\omega_{\text{infra}} = 0.45, \quad \omega_{\text{recruit}} = 0.45, \quad \omega_{\text{reserve}} = 0.10$$

#### **Late Campaign / Realm Divide Phase**
Faced with total diplomatic isolation or total war, AI channels maximum capital into military unit recruitment and full-stack reinforcement pools [88, 90].
$$\omega_{\text{infra}} = 0.15, \quad \omega_{\text{recruit}} = 0.75, \quad \omega_{\text{reserve}} = 0.10$$

---

## 3. AI Tactical Decision Weights & Scoring Algorithms

### 3.1 Settlement Attack vs. Siege vs. Retreat Threshold Model

When an AI army arrives at a target settlement, it evaluates combat power ratios, siege defense multipliers, and reinforcement availability before deciding whether to **Direct Assault**, **Lay Siege / Blockade**, or **Fall Back** [4, 8, 116, 210].

$$\text{Power Ratio } (R_{\text{power}}) = \frac{CP_{\text{attacker}}}{CP_{\text{defender}} \times M_{\text{fort}}}$$

Where:
* $CP_{\text{attacker}}$: Total Combat Power of attacking army and allied reinforcements [4, 119].
* $CP_{\text{defender}}$: Total Combat Power of defending garrison and garrisoned army [118, 137].
* $M_{\text{fort}}$: Settlement Fortification Defense Multiplier (scaling from $1.2$ for unfortified towns to $2.5$ for Level 5 Citadels/Castles) [116, 174, 219].

```
                          ┌───────────────────────────┐
                          │ Calculate Power Ratio (R) │
                          └─────────────┬─────────────┘
                                        │
             ┌──────────────────────────┼──────────────────────────┐
             ▼                          ▼                          ▼
    R_power ≥ 1.5              0.9 ≤ R_power < 1.5           R_power < 0.9
┌────────────────────────┐  ┌────────────────────────┐  ┌────────────────────────┐
│ DIRECT ASSAULT TRIGGER │  │ LAY SIEGE / BLOCKADE   │  │ FALL BACK / RETREAT    │
│ (Immediate Attack)     │  │ (Starve Defender Out)  │  │ (Withdraw Force)       │
└────────────────────────┘  └────────────────────────┘  └────────────────────────┘
```

#### Decision Rules:
1. **Direct Assault ($R_{\text{power}} \ge 1.5$):** AI immediately launches a tactical battle or auto-resolve siege [8, 210].
2. **Lay Siege / Blockade ($0.9 \le R_{\text{power}} < 1.5$):** AI surrounds the castle town to cut off food supplies and deplete defense tickets without risking storming casualties [116, 136, 173].
3. **Fall Back / Retreat ($R_{\text{power}} < 0.9$):** AI withdraws to allied territory or merges with nearby secondary stacks [4, 207].

---

### 3.2 Target Selection Scoring Algorithm

For every accessible settlement on the campaign map, the AI decision engine calculates a **Target Priority Score ($S_{\text{target}}$)** to dictate force vectoring [199, 207]:

$$S_{\text{target}} = \left( \frac{V_{\text{econ}} + V_{\text{strat}}}{D_{\text{turns}}} \right) \times M_{\text{diplomacy}} \times \left( 2.0 - R_{\text{power}} \right)$$

#### Explicit Variable Definitions:
* $V_{\text{econ}}$ **(Economic Value):** Regional wealth ($W_{\text{region}}$), tax yield, and unique trade resource plot bonuses (e.g. craft works, ports, horses) [30, 175, 199].
* $V_{\text{strat}}$ **(Strategic Value):** Provincial capital status, choke-point positioning, or military recruitment specialization slots [115, 175, 205].
* $D_{\text{turns}}$ **(Distance in Turns):** Campaign map movement turns required for the army to reach the target ($D_{\text{turns}} = \frac{\text{Distance}}{AP_{\text{turn}}}$) [120, 207].
* $M_{\text{diplomacy}}$ **(Diplomatic Attitude Multiplier):** Numerical weighting derived from faction relationships, trust scores, and alliance obligations ($M_{\text{diplomacy}} \in [0.1, 3.0]$) [126, 199].
* $R_{\text{power}}$ **(Power Ratio):** Attacker relative strength versus target garrison defense ($CP_{\text{attacker}} / CP_{\text{defender}}$) [4, 137].

The settlement returning the highest positive $S_{\text{target}}$ score is assigned as the primary objective for the campaign force [207].

---

## 4. Specification Gaps & Abstract Parameters

While the source documentation details turn flow steps, diplomacy impact, tax auto-management, siege mechanics, and economic choices, specific internal program values remain unstated:

1. **Exact AI Weighting Multipliers:** The source materials describe strategic tradeoffs (e.g. aggressive expansion vs. domestic growth) [84, 88], but do not provide the exact engine source code floating-point constants for $\omega_{\text{infra}}$, $\omega_{\text{recruit}}$, and $\omega_{\text{reserve}}$.
2. **Pathfinding Node Heuristics:** The sources detail distance and movement mechanics [120, 207], but omit the exact A* pathfinding node weight calculations across fog of war terrain layers.
3. **Diplomatic Aggression Thresholds:** General diplomatic attitudes and personality traits are detailed [126, 199], but specific numeric thresholds that convert negative attitude scores directly into immediate declarations of war are unlisted.
