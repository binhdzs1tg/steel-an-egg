# Changelog

Tất cả thay đổi đáng chú ý của dự án **Steal An Egg Simulator** được ghi lại tại đây.

Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/),
và dự án tuân thủ [Semantic Versioning](https://semver.org/lang/vi/).

## [1.0.0] - 2026-09-13

### Đã thêm (Added)

- **Game engine**: Godot 4.3 stable + GDScript
- **5 biomes**: Sân Trường, Rừng Xanh, Sa Mạc, Núi Lửa, Vũ Trụ — mỗi biome có màu sắc, kích thước và độ khó riêng
- **13 loại trứng** phân bố theo 5 biomes:
  - Sân Trường: Trứng Ngỗng, Trứng Ngỗng Lớn, Trứng Ngỗng Vàng
  - Rừng Xanh: Trứng Gấu, Trứng Gấu Nâu, Trứng Gấu Polar
  - Sa Mạc: Trứng Hổ, Trứng Hổ Trắng, Trứng Hổ Saber
  - Núi Lửa: Trứng Rồng Lửa, Trứng Rồng Đen
  - Vũ Trụ: Trứng Boss Vũ Trụ, Trứng Huyền Thoại
- **5 sinh vật bảo vệ** với AI thông minh:
  - 🪿 Ngỗng (Sân Trường) — dễ tránh
  - 🐻 Gấu (Rừng Xanh) — chậm dai dẳng
  - 🐯 Hổ (Sa Mạc) — nhanh tàn nhẫn
  - 🐉 Rồng (Núi Lửa) — mạnh khó chạy
  - 👾 Boss Vũ Trụ (Vũ Trụ) — tối đa mọi chỉ số
- **12 loại sinh vật nuôi** tạo thu nhập thụ động
- **5 nâng cấp** với cost progression exponential:
  - Tốc Độ Di Chuyển (20 cấp)
  - Sức Chịu Trứng (10 cấp)
  - Mở Rộng Chuồng (10 cấp)
  - Tốc Độ Ấp (8 cấp)
  - Bộ Nhân Thu Nhập (10 cấp)
- **Player controller** mượt mà với acceleration, friction, run toggle
- **Camera follow** với position smoothing
- **Egg steal mechanic** với prompt "BẤM [E] ĐỂ TRỘM TRỨNG!"
- **Carry state** — mang trứng giảm tốc độ, trứng càng quý giảm càng nhiều
- **Guardian AI** với 4 trạng thái: PATROL → CHASE → RETURN → STUNNED
- **Detection & chase radius** khác nhau cho từng guardian
- **Coop với hatch slots** hiển thị tiến trình ấp trực quan
- **Pet income** thụ động theo thời gian thực
- **Treadmill** tăng Speed XP khi đứng trên
- **HUD** hiển thị Speed, Money, Day, prompt, chase warning
- **Minimap** góc trên phải với player/guardian/biome markers
- **Pause menu** với save/resume/quit
- **Upgrade menu** với thông tin cấp độ, giá, mô tả
- **Notification system** với toast messages trượt vào
- **Procedural SFX** synthesized runtime (không cần file audio)
- **Save/Load** JSON-based với autosave mỗi 10 giây
- **Smoke test** kiểm tra data integrity (12 tests)
- **GitHub Actions** workflow tự động build Windows .exe khi push tag

### Tech Stack

| Thành phần | Công nghệ |
|-----------|-----------|
| Game engine | Godot 4.3 stable |
| Scripting | GDScript |
| Physics | Godot Physics2D |
| Audio | AudioStreamGenerator (procedural) |
| Save format | JSON |
| CI/CD | GitHub Actions |
| Distribution | GitHub Releases |

### Điều khiển

| Phím | Hành động |
|------|-----------|
| W A S D | Di chuyển |
| Shift | Chạy |
| E | Tương tác |
| U | Mở menu nâng cấp |
| Esc | Tạm dừng |
