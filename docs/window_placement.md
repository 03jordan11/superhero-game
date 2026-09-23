# Windowed display-mode placement

Switching to Windowed or Borderless Windowed now centers the entire native window
on its current monitor. Oversized preferred resolutions scale down proportionally
to leave room for the title bar, borders, taskbar and an 8-pixel edge gap. The saved
preferred resolution remains unchanged, so a larger monitor can still use it.

The code measures the monitor work area and native frame/client offsets using
[Godot DisplayServer](https://docs.godotengine.org/en/latest/classes/class_displayserver.html#class-displayserver-method-screen-get-usable-rect).
Placement is checked immediately and over the next two frames to accommodate
native mode/decorations changes, including while gameplay is paused. Pending work
is cancelled when another display setting is chosen. It does not continuously
recenter the window during normal use.

Files changed:

- `scripts/game_settings.gd`: safe sizing, centering and bounded deferred checks.
- `scripts/ui-scripts/settings_menu.gd`: tooltip explains preferred size and fitting.
- `tests/test_display_window_fit.gd`: real OS window-placement regression coverage.
- This document.

Validation: native Windows test passed on both connected monitors (work areas
2560 × 1392 and 1920 × 1032, at different desktop offsets). Covered fullscreen
exits into both windowed modes, oversized 7680 × 4320 preferences, smaller exact
sizes, off-screen placement, paused settings and rapid mode changes. Bounds were
checked using native window measurements; no visual inspection is claimed.

The existing `test_settings_tabs.gd` display checks passed, but its overall run
failed on unrelated missing audio buses. `project.godot` references unresolved
audio-layout UID `uid://cuwmlf4j1kqls`. That audio configuration was not changed.

Manual check: use a standalone game window/export, select Fullscreen, then switch
to Windowed and Borderless Windowed. Try a resolution larger than the monitor.
The entire window should remain visible, and Windowed mode's title bar should be
reachable without Windows hotkeys. Ask the original tester to repeat this with
their monitor/scaling setup in a new build.
