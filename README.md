# 🥚 Steal An Egg Simulator

> **2D Top-Down Egg Stealing Simulator** — xây dựng bằng **Godot 4.3** (engine 2D tốt nhất hiện nay cho Windows).

[![Build Windows EXE](https://github.com/binhdzs1tg/steel-an-egg/actions/workflows/build-release.yml/badge.svg)](https://github.com/binhdzs1tg/steel-an-egg/actions/workflows/build-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Godot 4.3](https://img.shields.io/badge/Godot-4.3%20stable-blue)](https://godotengine.org)

## 🎮 Giới thiệu

**Steal An Egg Simulator** là game 2D góc nhìn từ trên xuống (top-down). Bạn vào vai một kẻ trộm trứng táo bạo:

- 🔍 **Khám phá** 5 vùng đất với độ khó tăng dần: Sân Trường → Rừng Xanh → Sa Mạc → Núi Lửa → Vũ Trụ
- 🥚 **Trộm trứng** từ các sinh vật bảo vệ (ngỗng, gấu, hổ, rồng, boss vũ trụ)
- 🏃 **Chạy trốn** khỏi những kẻ đuổi theo với AI thông minh
- 🐾 **Ấp trứng** thành sinh vật tại chuồng
- 💰 **Kiếm tiền** thụ động từ sinh vật đã nở
- ⚡ **Nâng cấp** tốc độ, sức mang, chuồng, tốc độ ấp, hệ số thu nhập
- 🗺️ **Mở rộng** vùng đất khám phá khi tiến triển

## 🎯 Vòng lặp gameplay

```
🏠 Căn cứ → 🗺️ Khám phá → 🥚 Tìm trứng → ✋ Trộm → 🚨 Bị truy đuổi
   → 🏃💨 Chạy về → 🏠 Đặt trứng → 🥚 Ấp → 🐾 Sinh vật → 💰 Kiếm tiền
   → ⚡ Nâng cấp → 🗺️ Đi xa hơn → ...
```

## 🕹️ Điều khiển

| Phím | Hành động |
|------|-----------|
| **W A S D** | Di chuyển nhân vật |
| **Shift** | Chạy (tăng tốc độ) |
| **E** | Tương tác (trộm trứng / đặt trứng) |
| **U** | Mở menu Nâng cấp |
| **M** | Bật/tắt minimap |
| **Esc** | Tạm dừng game |

## 🛠️ Tech Stack

| Thành phần | Công nghệ | Lý do |
|-----------|-----------|-------|
| **Game engine** | Godot 4.3 stable | Engine 2D mạnh nhất, free, open-source, native Windows export |
| **Scripting** | GDScript | Cú pháp Python-like, dễ đọc, compile nhanh |
| **Physics** | Godot Physics2D | Native CharacterBody2D + Area2D |
| **Audio** | AudioStreamGenerator | Synthesize SFX procedural, không cần ship audio assets |
| **Save system** | JSON (user://) | Đơn giản, con người đọc được |
| **CI/CD** | GitHub Actions | Auto-build Windows .exe khi tạo tag |
| **Distribution** | GitHub Releases | Source + prebuilt EXE |

## 🚀 Cách chạy

### Cách 1: Tải bản dựng sẵn (khuyến nghị)

1. Tải file `StealAnEgg-Windows.zip` từ [Releases](https://github.com/binhdzs1tg/steel-an-egg/releases)
2. Giải nén
3. Chạy `StealAnEgg-Windows.exe`

### Cách 2: Chạy từ source (cho developer)

1. Tải [Godot 4.3](https://godotengine.org/download) (stable)
2. Clone repo:
   ```bash
   git clone https://github.com/binhdzs1tg/steel-an-egg.git
   ```
3. Mở Godot 4.3 → **Import** → chọn file `project.godot`
4. Nhấn **F5** để chạy

### Cách 3: Export sang Windows EXE

1. Mở project trong Godot 4.3
2. **Project → Export → Import** file `export_presets.cfg`
3. Tải export templates: **Editor → Manage export templates**
4. Chọn preset **Windows Desktop** → **Export Project**

## 📁 Cấu trúc dự án

```
steel-an-egg/
├── project.godot                # Cấu hình Godot project
├── export_presets.cfg            # Windows export preset
├── icon.svg                      # Game icon
├── data/                         # JSON data files
│   ├── biomes.json              # 5 biomes (Sân trường, Rừng, Sa mạc, Núi lửa, Vũ trụ)
│   ├── eggs.json                # 13 loại trứng khác nhau
│   ├── guardians.json           # 5 sinh vật bảo vệ (Goose, Bear, Tiger, Dragon, Boss)
│   ├── pets.json                # 12 loại sinh vật nuôi
│   └── upgrades.json            # 5 nâng cấp (Speed, Carry, Coop, Hatch, Income)
├── scenes/                       # Godot scene files (.tscn)
│   ├── Main.tscn                # Scene gốc
│   ├── Player.tscn              # Nhân vật
│   ├── Egg.tscn                 # Trứng
│   ├── Guardian.tscn            # Sinh vật bảo vệ
│   ├── Base.tscn                # Căn cứ
│   ├── Treadmill.tscn           # Máy chạy tốc độ
│   ├── Coop.tscn                # Chuồng ấp trứng
│   ├── world/
│   │   ├── World.tscn
│   │   └── Biome.tscn
│   └── ui/
│       ├── HUD.tscn             # Giao diện chính
│       ├── UpgradeMenu.tscn     # Menu nâng cấp
│       ├── UpgradeItem.tscn     # Item trong menu nâng cấp
│       └── PauseMenu.tscn       # Menu tạm dừng
├── scripts/                      # GDScript (.gd)
│   ├── autoload/                # Singletons toàn cục
│   │   ├── GameManager.gd
│   │   ├── DataRegistry.gd
│   │   ├── Economy.gd
│   │   ├── SaveSystem.gd
│   │   ├── AudioManager.gd
│   │   └── NotificationSystem.gd
│   ├── player/Player.gd
│   ├── world/{World,Biome,Main}.gd
│   ├── egg/Egg.gd
│   ├── npc/Guardian.gd
│   ├── base/{Base,Treadmill,Coop}.gd
│   └── ui/{HUD,UpgradeMenu,UpgradeItem,PauseMenu,Minimap}.gd
├── tests/                        # Smoke tests
└── .github/workflows/             # CI để build Windows EXE
    └── build-release.yml
```

## 🎨 Tính năng chính

- ✅ **World dọc lớn** với 5 biomes có màu sắc và độ khó khác nhau
- ✅ **Player controller** mượt mà với acceleration/friction
- ✅ **Camera follow** với position smoothing
- ✅ **Egg steal mechanic** với prompt "[E] ĐỂ TRỘM TRỨNG!"
- ✅ **Carry state** làm giảm tốc độ (càng trứng quý càng chậm)
- ✅ **Guardian AI** với 4 trạng thái: PATROL → CHASE → RETURN → STUNNED
- ✅ **Detection & chase radius** khác nhau cho từng guardian
- ✅ **Coop với hatch slots** hiển thị tiến trình ấp
- ✅ **Pet income** thụ động theo thời gian
- ✅ **5 nâng cấp** với cost progression exponential
- ✅ **Treadmill** tăng Speed XP khi đứng trên
- ✅ **HUD** hiển thị Speed, Money, Day, prompt, chase warning
- ✅ **Minimap** góc trên phải với player/guardian/biome markers
- ✅ **Pause menu** với save/quit
- ✅ **Procedural SFX** (không cần file audio)
- ✅ **Save/Load** JSON-based với autosave mỗi 10s
- ✅ **Notification system** với toast messages

## 🔧 Kiểm tra (Smoke Test)

Chạy headless smoke test:

```bash
godot --headless --script res://tests/SmokeTest.gd
```

## 📜 License

MIT License — freely use, modify, distribute.

## 👤 Author

**binhdzs1tg** — [GitHub](https://github.com/binhdzs1tg)

## 🙏 Cảm ơn

- [Godot Engine](https://godotengine.org) — engine tuyệt vời và miễn phí
- Tất cả contributor và player
