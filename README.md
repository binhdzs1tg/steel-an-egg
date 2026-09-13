# 🥚 Steel An Egg

A 3D single-player collection / simulation / adventure game built with **Godot Engine 4.7.2** and GDScript.

> **Genre:** Collection / Simulation / Adventure / Progression  
> **Mode:** Single-player, offline, local save  
> **Platform:** Windows (export target)

## 🎮 Gameplay Loop

```
KHÁM PHÁ → TÌM EGG → THU THẬP EGG → MANG VỀ CĂN CỨ → ẤP EGG → NHẬN PET → PET TẠO TIỀN → NÂNG CẤP → TĂNG SPEED → MỞ KHU VỰC MỚI → TÌM EGG HIẾM HƠN → LẶP LẠI
```

You explore the world, collect eggs, carry them back to your base, hatch them into pets, and pets passively generate money. Money buys upgrades (Speed, Treadmill, Pet Slots, Egg Storage, Base, Income Boost). Higher Speed unlocks new biomes with rarer eggs.

## 📷 Camera Modes (the headline feature)

| Mode | How to enter | Description |
|------|--------------|-------------|
| **3rd-person Classic** | Default | Camera behind & slightly above avatar. Hold **RMB** to free-rotate around character. |
| **Shift Lock** | Hold **Shift** | Camera locks behind shoulder, crosshair appears, mouse rotates the character. Release Shift to exit. |
| **1st-person** | Scroll wheel forward past threshold | Camera enters the head; body hidden. Scroll back out to exit. |

Additional camera features:
- **Camera shake** on damage and rare+ hatches (toggleable in Settings)
- **Smooth zoom** between 0.4 and 9.0 distance
- **Spring arm collision** so camera never clips through walls

## 🔊 Audio System

All audio is **procedurally synthesized** in code — no external audio files needed:
- **Ambient music**: continuous pad with arpeggio (AudioStreamGenerator)
- **SFX**: 16 one-shot sound effects synthesized as 16-bit WAV (egg pickup, hatch crack, pet appear by rarity tier, money tick, upgrade buy, speed level up, quest complete, achievement, biome unlock, damage, UI click/hover)
- **Volume sliders** for music and SFX (saved in settings)

## ✨ VFX System

- **GPUParticles3D** bursts on rare+ hatches, achievements, and damage
- Particle count, color, size, and speed scale with **rarity tier**
- Mutation color tints the pet mesh via emission
- Egg glow intensity based on rarity

## 🗺️ Minimap

A bottom-left minimap shows:
- Player position (cyan dot with direction arrow)
- Base (green dot at center)
- Unlocked biome gates (yellow dots)
- Nearby eggs within range (orange dots)
- NPCs (red dots, brighter when chasing/attacking)

## 🕹️ Controls

| Action | Key |
|--------|-----|
| Move | WASD |
| Jump | Space |
| Run | Ctrl (hold while moving) |
| Interact | E |
| Camera free-rotate | Right Mouse Button (hold) |
| Camera zoom in / out | Scroll Wheel |
| Shift Lock camera | Shift (hold) |
| Reset camera | R |
| Open Inventory | I |
| Open Collection | C |
| Open Upgrades | U |
| Open Quests | Q |
| Pause / Settings | Esc |

## 🗺️ World Layout

Eight biomes are arranged in a line, each behind the previous one:

| # | Biome | Required Speed | Egg Rarity Tier |
|---|-------|----------------|-----------------|
| 0 | Grassland | 0 | Common |
| 1 | Forest | 50 | Common–Epic |
| 2 | Desert | 150 | Uncommon–Epic |
| 3 | Snow | 400 | Epic–Legendary |
| 4 | Volcano | 1000 | Legendary–Mythic |
| 5 | Crystal Cave | 2500 | Mythic |
| 6 | Sky Island | 5000 | Mythic |
| 7 | Void | 10000 | Secret |

Each biome has its own ground color, sky, fog, NPC guardians, egg spawn points, and decorative trees. Biome gates show "LOCKED — Requires Speed X" until the player reaches the threshold.

## 🐾 Pet Systems

- **30 pets** across 7 rarities (Common → Secret)
- **6 sizes**: Tiny, Small, Normal, Large, Huge, Titanic (×0.7 to ×5 income multiplier)
- **7 mutations**: Normal, Golden, Diamond, Rainbow, Shadow, Galaxy, Void (×1 to ×25 income multiplier)
- **10 levels** per pet (×1.0 to ×12.0 income multiplier)
- **Pet Income formula**: `base × size_mult × mutation_mult × level_mult × income_boost`

## 💾 Save System

- **Local JSON save** at `user://save.json`
- **Backup save** at `user://save.backup.json` (auto-rotated on each save)
- **Versioned schema** with migration support
- **Auto-save** every 30 seconds when dirty
- **Offline earnings**: capped at 30 minutes of accumulated pet income

## 🏗️ Project Structure

```
steel-an-egg/
├── project.godot           # Godot project config (autoloads, input map, layers)
├── icon.svg                # App icon
├── scenes/
│   └── Main.tscn           # Entry scene (loads Main.gd)
├── scripts/
│   ├── autoload/           # Singletons
│   │   ├── GameManager.gd       # World/player refs, biome switching, egg/pet inventory
│   │   ├── SaveSystem.gd        # JSON save + backup + auto-save + offline earnings
│   │   ├── AudioManager.gd      # Procedural SFX + ambient music synthesis
│   │   ├── VFXBurst.gd          # Particle burst factory (one-shot, auto-free)
│   │   ├── Economy.gd           # Money, speed, upgrades, pet income
│   │   ├── Collection.gd        # Pet/Size/Mutation index
│   │   ├── QuestSystem.gd       # Quest definitions + tracking + rewards
│   │   ├── AchievementSystem.gd # Stat-based achievements
│   │   ├── NotificationSystem.gd # Toast notifications + activity log
│   │   ├── DataRegistry.gd      # JSON data loader + weighted rolls
│   │   └── InputMapHelper.gd    # Centralized input reader
│   ├── player/Player.gd    # Player + 3-mode camera + camera shake
│   ├── world/
│   │   ├── Main.gd         # World root, builds biomes + base + player + HUD
│   │   ├── Biome.gd        # Biome region (ground/sky/spawn points/NPCs/gate)
│   │   ├── BiomeGate.gd    # Trigger zone for biome transitions
│   │   └── EggSpawnPoint.gd # Egg spawner with respawn timer
│   ├── egg/Egg.gd          # Pickable egg in the world
│   ├── pet/PetVisual.gd    # Visual representation of a pet
│   ├── hatch/HatchStation.gd # 7-stage hatch animation + VFX + SFX
│   ├── npc/NPC.gd          # Patrol/Detect/Chase/Attack/Return state machine
│   ├── base/
│   │   ├── Base.gd         # Player base (hatch/treadmill/upgrades/display)
│   │   ├── Treadmill.gd    # Active speed-XP training station
│   │   └── PetDisplayArea.gd # Showcase top-6 pets by income
│   ├── upgrade/UpgradeStation.gd # Buy upgrades
│   └── ui/
│       ├── HUD.gd              # In-game overlay + crosshair + minimap + XP bar
│       ├── InventoryMenu.gd    # Egg inventory
│       ├── CollectionMenu.gd  # Pet/Size/Mutation/Biome index
│       ├── UpgradeMenu.gd     # Upgrade shop
│       ├── QuestMenu.gd       # Quest log
│       ├── PauseMenu.gd       # Pause overlay (resume/save/settings/quit)
│       ├── SettingsMenu.gd    # Volume sliders + camera shake toggle
│       ├── SpeedXPBar.gd      # Speed XP progress bar
│       └── Minimap.gd         # Top-down 2D minimap
└── data/
    ├── eggs.json           # 16 egg definitions
    ├── pets.json           # 30 pet definitions
    ├── biomes.json         # 8 biomes + 8 NPC types
    ├── upgrades.json       # 6 upgrade tracks + speed XP table
    ├── quests.json         # 10 quest chains
    ├── achievements.json   # 14 achievements
    └── pet_attributes.json # Size/Mutation/Level tables
```

## 🚀 Getting Started (Developer)

### Requirements

- **Godot Engine 4.7.2** (download from <https://godotengine.org/download>)
- .NET SDK is **not** required — this project uses pure GDScript

### Running the project

1. Clone the repo: `git clone https://github.com/binhdzs1tg/steel-an-egg.git`
2. Open **Godot 4.7.2**
3. Click **Import** → select `project.godot` from this repo
4. Godot will import all assets (first import takes ~10s)
5. Press **F5** to run the project

### Exporting to Windows

1. In Godot, go to **Editor → Manage Export Templates → Download** (for 4.7.2)
2. Go to **Project → Export → Add → Windows Desktop**
3. Set the export path (e.g., `builds/SteelAnEgg.exe`)
4. Click **Export Project**

The resulting `.exe` can be distributed standalone.

## 🔧 Architecture Notes

- **No `.tscn` files for gameplay objects.** Everything (player, eggs, NPCs, base, UI) is built procedurally in GDScript's `_ready()`. Only `Main.tscn` exists as the entry point. This keeps the codebase diff-friendly and avoids binary scene merge conflicts.
- **All gameplay data lives in JSON** under `data/`. Adding a new egg/pet/biome/upgrade is a JSON edit, no recompile needed.
- **Singletons** (autoloads) own all global state. UI reads from singletons via signals.
- **No external assets** — all 3D meshes are primitives (capsules, boxes, spheres, cones, cylinders) with procedural materials. No textures, no model files. This keeps the repo tiny (~50 KB without Godot's import cache).

## 📜 License

MIT — see `LICENSE` file (or feel free to relicense for your own use).

## 🤝 Contributing

This is a personal project. Commits are signed with `binhdzs1tg <binhdzs1tg@users.noreply.github.com>`.

## ⚠️ Security Note

If you have access to this repo via a leaked Personal Access Token, **that token is compromised and must be revoked immediately** at GitHub → Settings → Developer settings → Personal access tokens. Create a new one and never share it in plaintext.
