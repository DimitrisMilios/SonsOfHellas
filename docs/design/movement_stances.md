# Technical Specification: Campaign Map Movement, Terrain Navigation & Army Stances

This specification outlines the data models, movement mechanics, stance state machines, and Zone of Control (ZoC) rules compiled from campaign engine mechanics.

---

### 1. Action Point (AP) System & Movement Mechanics

#### **1.1 Campaign Movement Pool & Boundaries**
* **Movement Limit ($AP_{\text{rem}}$):** Each army possesses a maximum per-turn movement range, represented visually on the campaign map by a yellow movement boundary [207]. Moving to the boundary depletes available Action Points for that turn ($AP_{\text{rem}} = 0$) [207].
* **Territory Control Boundaries:** Moving into territory controlled by a neutral or hostile entity (demarcated on the campaign map in red) forces an engagement or attack against the occupant [207].

#### **1.2 Terrain & Infrastructure Modifiers**
* **Paved Roads Modifier ($M_{\text{road}}$):** Constructing and utilizing upgraded road networks increases army and agent campaign movement speeds across regions ($Speed_{\text{road}} > Speed_{\text{base}}$) [56].
* **Off-Road / Rough Terrain:** Off-road movement consumes movement points at standard baseline rates without the multiplicative speed bonus granted by road infrastructure [56].

$$\text{Effective Speed } S_{\text{effective}} = S_{\text{base}} \times (1 + M_{\text{road}})$$

---

### 2. Army Stances & State Machine

#### **2.1 Stance Parameter & Modifier Matrix**

| Stance | Min AP to Activate | AP Cost | Campaign Movement Bonus | Line of Sight ($LOS$) | Morale Modifier | Unit Upkeep Modifier ($U$) | Special Combat & Economic Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Normal** | $0\%$ | $0\%$ | $0\%$ (Baseline) | $0$ (Baseline) | $0$ (Baseline) | $100\%$ | Standard campaign movement and combat readiness [120]. |
| **Forced March** | $0\%$ | $0\%$ | $+ \Delta AP$ (Extended) | Reduced ($LOS < LOS_{\text{base}}$) | Baseline | $100\%$ | Increases total movement distance; heightened vulnerability to ambush attacks [120, 121]. |
| **Raiding** | $\le 50\%$ remaining | $50\%$ | $-50\%$ ($AP_{\text{max, raid}} = 0.50 \cdot AP_{\text{max}}$) | $-25$ | $+5\%$ | $-50\%$ ($U_{\text{raid}} = 0.50 \cdot U_{\text{base}}$) | Raids trade routes and settlements for income; forages local supplies [45, 46, 121]. |
| **Encampment** | *Unspecified in sources* | *Unspecified* | Restricted | Baseline | Baseline | $100\%$ | Defensive fortification posture [120]. |
| **Ambush** | *Unspecified in sources* | *Unspecified* | $0\%$ | Baseline | Baseline | $100\%$ | Conceals army in terrain to initiate surprise attacks [121, 134]. |
| **Siege** | $100\%$ to target | $100\%$ | $0\%$ (Stationary) | Baseline | Baseline | $100\%$ | Enforces blockade on settlement; builds siege engines or starves defenders [116, 172-174]. |

#### **2.2 Mathematical Formulations for Stances**

##### **Raiding Stance Mechanics**
Raiding stance reduces unit upkeep while incurring movement and vision penalties [121]:

$$LOS_{\text{raiding}} = LOS_{\text{base}} - 25$$

$$AP_{\text{max, raiding}} = 0.50 \times AP_{\text{max}}$$

$$U_{\text{land, raiding}} = 0.50 \times U_{\text{base}}$$

$$M_{\text{raiding}} = M_{\text{base}} \times 1.05$$

$$\text{Activation Condition: } AP_{\text{spent}} \le 0.50 \times AP_{\text{max}}$$

Trade route raiding extracts revenue directly from land carriage paths or naval shipping lanes [45, 46]:

$$I_{\text{raid}} = W_{\text{lane}} \times \alpha_{\text{raid}}$$

Where $W_{\text{lane}}$ is the total trade wealth traversing the route and $\alpha_{\text{raid}}$ is the effective raid extraction fraction [45, 46].

##### **Forced March Stance Mechanics**
Forced March grants extended campaign map reach at the expense of reconnaissance and defensive security [120, 121]:

$$AP_{\text{forced\_march}} = AP_{\text{base}} + \Delta AP$$

$$LOS_{\text{forced\_march}} < LOS_{\text{base}}$$

$$\text{Ambush Interception Risk: } P_{\text{ambushed, forced\_march}} > P_{\text{ambushed, normal}}$$

---

### 3. Zone of Control (ZoC) & Engagement Rules

#### **3.1 Campaign & Tactical Zone of Control**
* **Hostile Boundary Interception:** Any movement into a region tile marked as enemy-controlled (red zone) halts campaign movement and initiates a battle prompt or tactical engagement [207].
* **Tactical Objective Control:** Tactical capture points within settlements enforce localized zones of control; attackers occupying the zone countdown victory tickets to secure settlement control [136].

#### **3.2 Siege & Blockade Mechanics**
* **Settlement Blockades:** Armies surrounding a settlement prevent military reinforcement and regional wealth collection [116].
* **Naval Port Blockades:** Blockading an enemy commercial port completely cuts off all associated sea trade routes and colony resource imports [43, 44].

---

### 4. Specification Gaps & Omitted Parameters

The source materials provide structural mechanics for army stances, movement limits, and raiding formulas, but omit certain underlying engine constants:

1. **Baseline Action Point Constant:** The sources state that armies have movement limits and that Forced March increases Action Points, but do not state the exact base integer value (e.g., 100 AP) [120, 207].
2. **Per-Terrain AP Cost Formulas:** Sources confirm that roads increase movement speed [56], but do not provide exact numerical AP cost deductions for Plains, Forests, Swamps, or Mountain Passes.
3. **Encampment & Ambush Stance AP Thresholds:** Sources detail the exact numerical bounds for Raiding stance (-50% movement, -25 LOS, -50% upkeep, +5% morale, max 50% movement spent) [121], but do not specify the exact AP activation cost percentage for Encampment or Ambush stances.
4. **ZoC Radius & Retreat Penalty Formulas:** Sources confirm that entering enemy-controlled red zones forces an attack [207], but do not specify the exact mathematical radius formula or retreat distance penalty equations.
