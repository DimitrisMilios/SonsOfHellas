# Mobile Grand Strategy Clean Architecture Guidelines (Sons of Hellas)

## Platform & Offline Constraints
- **Target Platform**: Mobile (Android / iOS). Must also remain fully testable in the Godot Editor.
- **Offline First**: 100% local execution. No backend servers, no cloud authentication, zero network dependencies.
- **Renderer**: `gl_compatibility` (OpenGL ES 3.0) for low battery consumption, fast startup, and 99.9% device compatibility. Do NOT use `Forward+` desktop features.
- **Frame Rate Limit**: Strictly capped at 60 FPS (`run/max_fps=60`) to prevent excessive thermal throttling and battery drain.

## Clean Architecture Layers
1. **Domain Layer (`res://scripts/data/`)**:
   - Custom Resources only (`UnitData`, `BuildingData`, `FactionData`, `ProvinceData`, `ArmyData`).
   - Pure data, zero scene tree dependencies, no Node inheritance.
   - Strict typing and `@export` annotations.
2. **Domain Services & Math (`res://scripts/core/`)**:
   - Pure calculation logic (e.g., `AutoResolveCalculator.gd`, `BattleResult.gd`).
   - Pure GDScript extending `RefCounted` or static methods. Completely testable without instantiating nodes.
3. **Application Layer (`res://scripts/core/`)**:
   - Singletons (`TurnManager`, `CampaignManager`, `SaveManager`).
   - TurnManager handles round progression and async AI ticks without locking the main thread.
   - SaveManager handles atomic serialization to `user://saves/*.json` and listens to `NOTIFICATION_APPLICATION_PAUSED`.
4. **Presentation Layer (`res://scripts/world/`, `res://scripts/ui/`)**:
   - `CampaignCamera.gd`: Handles 1-finger pan, 2-finger pinch-zoom, and inertia friction.
   - `CampaignHUD.gd`: Respects mobile device safe areas (`DisplayServer.get_display_safe_area()`).
   - Touch targets must be at least 44x44px for thumb accessibility.
