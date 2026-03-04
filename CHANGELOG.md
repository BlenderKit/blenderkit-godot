# Changelog

## 0.4.2 - 2026-03-04

Tiny bugfix release to remove harmless Warning on startup.

### Changed

- Remove script uid reference which was causing a harmless warning. Just Godot things.

## 0.4.1 - 2026-03-03

Small bugfix/polish release improving Wayland integration.

### Added

- Add "Auto" and "Original" resolution options
- Unsubscribe from Client when disabled or in error state

### Changed

- Improve Client integration with high latency clients
  - This fixes disconnects on Wayland when Godot editor isn't visible
- Change default Log Level to INFO and clean up Output
- Fix alignment of the version label with docs links
