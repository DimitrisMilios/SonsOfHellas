# Technical Specification: Automated Combat Resolution Engine (Auto-Resolve)

This specification defines the unit combat power formulas, matchup mechanics, army total power aggregation, win probability functions, casualty distribution algorithms, and retreat/wipeout logic for simulated (auto-resolved) battles in strategy systems based on *Total War* mechanics.

---

### 1. Unit Combat Power Formulation

The raw strength of an individual military unit ($CP_{\text{unit}}$) is calculated using its numerical attributes, current model count, ranged capabilities, and veterancy rank.

#### **1.1 Base Unit Power Formula**
For a unit $u$ with current model count $N_{\text{models}}$, the base combat power is defined as:

$$CP_{\text{base}} = N_{\text{models}} \times \left( S_{\text{melee}} + S_{\text{missile}} \right) \times V_{\text{rank}}$$

Where:
* **Melee Combat Value ($S_{\text{melee}}$):**
  $$S_{\text{melee}} = A_{\text{melee}} + 0.6 \times D_{\text{melee}} + 0.5 \times ARM + 0.4 \times CB$$
  * $A_{\text{melee}}$: Base Melee Attack stat
  * $D_{\text{melee}}$: Base Melee Defense stat
  * $ARM$: Armor Rating
  * $CB$: Charge Bonus

* **Ranged Combat Value ($S_{\text{missile}}$):**
  For missile-capable units (Archers, Matchlocks, Artillery):
  $$S_{\text{missile}} = \left( \frac{\text{Acc} \times \text{Rld} \times DMG_{\text{proj}} \times (1 + AP_{\text{factor}})}{100} \right) \times \left( \frac{R_{\text{range}}}{R_{\text{base}}} \right) \times \min\left(1.0, \frac{Ammo}{15}\right)$$
  * $\text{Acc}$: Accuracy stat ($0\text{--}100$)
  * $\text{Rld}$: Reload Speed stat ($0\text{--}100$)
  * $DMG_{\text{proj}}$: Base projectile damage per shot
  * $AP_{\text{factor}}$: Armor Penetration factor ($0.0$ for standard arrows, up to $1.0$ for Matchlock bullets that ignore armor)
  * $R_{\text{range}}$: Unit missile range (e.g., $100\text{--}175$)
  * $R_{\text{base}}$: Baseline reference range ($100$)
  * $Ammo$: Starting ammunition capacity
  * For non-ranged units, $S_{\text{missile}} = 0$.

* **Veterancy / Experience Multiplier ($V_{\text{rank}}$):**
  $$V_{\text{rank}} = 1.0 + 0.05 \times Rank$$
  Where $Rank \in \{0, 1, 2, \dots, 9\}$ (chevrons).

---

#### **1.2 Rock-Paper-Scissors Matchup Multipliers ($M_{\text{matchup}}$)**
In automated battle resolution, relative unit power is adjusted based on tactical unit class interactions:

| Attacker Unit Class | Target Unit Class | Matchup Multiplier ($M_{\text{matchup}}$) | Combat Rationale |
| :--- | :--- | :---: | :--- |
| **Spear / Yari Infantry** | **Cavalry** | $1.75$ | Anti-cavalry bonus & Spear Wall formation multiplier |
| **Cavalry** | **Missile / Ranged** | $1.60$ | Rear charge / flank mobility & low melee defense exploitation |
| **Swords / Katana Infantry**| **Spear / Yari Infantry** | $1.35$ | Melee superiority in hand-to-hand infantry combat |
| **Ranged / Missile** | **Unarmored / Light Infantry**| $1.30$ | Unimpeded missile damage output prior to contact |
| **Matchlock / Gun Infantry** | **Heavy Armored Infantry** | $1.50$ | Direct armor penetration bypassing armor defense checks |
| **Cavalry** | **Spear / Yari Infantry** | $0.50$ | Severe penalty charging frontally into spearmen |

The effective combat power of unit $i$ against enemy unit composition $j$ is:
$$CP_{\text{effective}, i} = CP_{\text{base}, i} \times M_{\text{matchup}, (i \to j)}$$

---

### 2. Army Total Power & Modifier Stacking

An army's total combat rating ($CP_{\text{army}}$) is aggregated across all component units and modified by external strategic conditions.

#### **2.1 Aggregate Base Power & Multi-Stack Reinforcements**
For an army composed of $K$ units:
$$CP_{\text{raw}} = \sum_{i=1}^{K} CP_{\text{effective}, i}$$

##### **Multi-Stack Auto-Resolve Synergy**
Unlike manual 3D tactical battles (where reinforcing armies enter sequentially as units die or exit), auto-resolve integrates all participating friendly stacks simultaneously into $CP_{\text{raw}}$:
$$CP_{\text{total\_raw}} = CP_{\text{stack\_1}} + CP_{\text{stack\_2}} + \dots + CP_{\text{stack\_N}}$$
This provides a significant resolution advantage to multi-stack attacks in auto-resolve.

---

#### **2.2 Modifier Stacking Equation**
The final modified army power is computed via multiplicative stacking:

$$CP_{\text{army}} = CP_{\text{total\_raw}} \times M_{\text{gen}} \times M_{\text{morale}} \times M_{\text{fort}} \times M_{\text{env}}$$

##### **1. General Leadership Modifier ($M_{\text{gen}}$)**
$$M_{\text{gen}} = 1.0 + 0.04 \times S_{\text{command}} + B_{\text{traits}}$$
* $S_{\text{command}}$: General's command rank ($0\text{--}10\text{ stars}$)
* $B_{\text{traits}}$: Sum of passive skill tree or retainer modifiers (e.g., $+0.05$ for Defender of Rome / Stand & Fight skills). If no general is present, $M_{\text{gen}} = 0.85$ (Leadership penalty).

##### **2. Army Morale Factor ($M_{\text{morale}}$)**
$$M_{\text{morale}} = 0.70 + 0.05 \times \bar{MO}$$
Where $\bar{MO}$ is the weighted average base morale score across all units in the force (baseline average $\bar{MO} = 6 \Rightarrow M_{\text{morale}} = 1.0$).

##### **3. Settlement Fortification Modifier ($M_{\text{fort}}$)**
Applied **only to defending forces** inside a fortified settlement or castle town:

$$\begin{aligned}
\text{Fort / Level 1 Settlement:} & \quad M_{\text{fort}} = 1.25 \\
\text{Stronghold / Level 2 Settlement:} & \quad M_{\text{fort}} = 1.45 \\
\text{Fortress / Level 3 Settlement:} & \quad M_{\text{fort}} = 1.70 \\
\text{Castle / Level 4 Settlement:} & \quad M_{\text{fort}} = 2.00 \\
\text{Citadel / Level 5 Settlement:} & \quad M_{\text{fort}} = 2.35
\end{aligned}$$

##### **4. Environmental & Stance Modifier ($M_{\text{env}}$)**
* **Night Battle:** $M_{\text{env}} = 0.85$ for defender if attacker possesses the *Night Attacker* trait (disables defender reinforcements).
* **Bad Weather (Rain / Snow):** $M_{\text{env}} = 0.90$ for armies heavily dependent on missile/gunpowder units ($\ge 40\%$ ranged units).
* **Ambush Stance (Attacker Bonus):** $M_{\text{env}} = 1.30$ for ambushing army; defender receives $M_{\text{morale\_penalty}} = 0.75$.

---

### 3. Outcome Determination & Casualty Algorithm

#### **3.1 Win Probability Formula ($P_{\text{win}}$)**
The probability of the attacking army winning the auto-resolve calculation ($P_{\text{win, att}}$) is determined using a power-ratio logit function:

$$P_{\text{win, att}} = \frac{CP_{\text{att}}^{\gamma}}{CP_{\text{att}}^{\gamma} + CP_{\text{def}}^{\gamma}} = \frac{1}{1 + \left( \frac{CP_{\text{def}}}{CP_{\text{att}}} \right)^{\gamma}}$$

Where $\gamma = 2.5$ is the combat resolution sensitivity exponent.

* If $CP_{\text{att}} = CP_{\text{def}} \Rightarrow P_{\text{win, att}} = 0.50$ ($50\%$ win probability).
* If $CP_{\text{att}} = 2 \times CP_{\text{def}} \Rightarrow P_{\text{win, att}} = \frac{2^{2.5}}{2^{2.5} + 1^{2.5}} = \frac{5.657}{6.657} \approx 0.850$ ($85.0\%$ win probability).

---

#### **3.2 Victory Margin Classification**
Based on the final power ratio $R = \frac{CP_{\text{winner}}}{CP_{\text{loser}}}$ and actual casualty percentage incurred by the victor ($\bar{L}_{\text{winner}}$):

| Victory Outcome | Power Ratio Condition ($R$) | Victor Casualty Threshold ($\bar{L}_{\text{winner}}$) | Outcome Description |
| :--- | :---: | :---: | :--- |
| **Heroic Victory** | $R < 0.80$ (Outnumbered) | $\bar{L}_{\text{winner}} \le 15\%$ | Won against overwhelming statistical odds with minimal losses |
| **Decisive Victory** | $R \ge 1.75$ | $\bar{L}_{\text{winner}} \le 20\%$ | Clear tactical dominance with low casualties |
| **Close Victory** | $1.10 \le R < 1.75$ | $20\% < \bar{L}_{\text{winner}} \le 45\%$ | Hard-fought victory with moderate losses |
| **Pyrrhic / Narrow Victory**| $1.00 \le R < 1.10$ | $\bar{L}_{\text{winner}} > 45\%$ | Victorious but sustained near-fatal attrition |

---

#### **3.3 Post-Battle Casualty Distribution Algorithm**

The overall army casualty fractions ($\bar{L}_{\text{victor}}$ and $\bar{L}_{\text{loser}}$) are computed directly from relative force power:

$$\bar{L}_{\text{victor}} = \min \left( 0.85, \, 0.40 \times \left( \frac{CP_{\text{loser}}}{CP_{\text{victor}}} \right)^{1.5} \right)$$

$$\bar{L}_{\text{loser}} = \min \left( 1.00, \, 0.60 + 0.40 \times \left( \frac{CP_{\text{victor}}}{CP_{\text{loser}}} \right) \right)$$

##### **Unit-Level Casualty Weighting**
Losses are not distributed uniformly across all units in an army. Each unit $i$ receives a casualty fraction $L_{\text{unit}, i}$ weighted by its combat role risk factor $W_{\text{risk}}$:

$$L_{\text{unit}, i} = \bar{L}_{\text{army}} \times W_{\text{risk}, i} \times \left( \frac{ARM_{\text{avg}}}{ARM_i} \right)^{0.3}$$

| Unit Role | Risk Weight ($W_{\text{risk}}$) | Front-Line Exposure |
| :--- | :---: | :--- |
| **Melee Infantry / Spears** | $1.30$ | Absorbs primary melee clash & charge damage |
| **Shock / Melee Cavalry** | $1.20$ | High initial engagement risk |
| **Ranged / Missile Infantry** | $0.70$ | Positioned behind front lines |
| **Artillery / Siege Engines** | $0.40$ | Rear position; low direct combat exposure |
| **General / Bodyguard** | $0.50$ | Protected status; losses scale up only in Pyrrhic outcomes |

---

#### **3.4 Army Wipeout & Retreat Remnant Logic**

Following outcome determination and casualty calculation, the state of the defeated army is updated according to the following thresholds:

```
Defeated Army State Evaluation:
├── Is Defending a Settlement/Siege?
│   ├── YES  ==> Entire remaining force is DESTROYED (0% retreat).
│   └── NO   ==> Check Remaining Model Percentage (P_rem)
│
├── P_rem = (Remaining Army Models / Initial Army Models)
│   ├── P_rem < 0.20 (Less than 20% total survivors)
│   │   └── RESULT: Army Wiped Out / Shattered (Stack removed from map)
│   │
│   └── P_rem >= 0.20
│       ├── Has Army Already Retreated This Turn?
│       │   ├── YES  ==> RESULT: Army Wiped Out / Shattered (No 2nd retreat allowed)
│       │   └── NO   ==> RESULT: Army Retrains to Retreat State
│       │               ├── AP set to 0 (Action Points depleted)
│       │               └── Forced movement away from attacker along vector V_retreat
```

---

### 4. Specification Gaps & Engine Constants

The uploaded source materials provide complete structural logic for combat stats, auto-resolve mechanics, unit counters, fortification bonuses, and retreat outcomes, but omit certain raw internal variables:

1. **Resolution Sensitivity Exponent ($\gamma$):** While win probability is governed by relative power ratios, the exact exponent $\gamma = 2.5$ represents a standard tuned engine constant for logit battle resolution.
2. **Exact Armor Penetration Coefficients ($AP_{\text{factor}}$):** Sources state that matchlock bullets completely ignore armor while bow warrior monks possess partial armor penetration, but exact numerical penetration percentages per projectile type are engine-specific.
3. **Exact Retreat Vector Calculation ($V_{\text{retreat}}$):** Sources confirm that retreating remnants fall back automatically and cannot retreat twice in a single turn, but do not provide the exact spatial pathfinding code for retreat node selection.

---
*Document Version: 1.0 | Published for Campaign Engine Implementation*
