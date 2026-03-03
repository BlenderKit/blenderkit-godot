# Changelog

Small bugfix/polish release improving Wayland integration.

## 0.4.1 - 2026-03-03

### Added

- Add "Auto" and "Original" resolution options
- Unsubscribe from Client when disabled or in error state

### Changed

- Improve Client integration with high latency clients
    - This fixes disconnects on Wayland when Godot editor isn't visible
- Change default Log Level to INFO and clean up Output
- Fix alignment of the version label with docs links
