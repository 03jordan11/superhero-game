# Gameplay HUD

The HUD shows health at the top left, level/XP progress at the bottom left, and optional key hints at the bottom right. Health and XP are driven by player signals. Both stay visible by default. In **Settings → Gameplay**, disable Always Show Health to show it only while damaged or for four seconds after a change; disable Always Show Level / XP to show it for four seconds after progression changes. These timers pause with the game. See [Settings menu](SETTINGS_MENU.md) for all preferences.

**Settings → Gameplay → Show Control Hints** is a checkbox in both menus. It immediately controls the hints and persists in the `hud/show_control_hints` field of `user://settings.cfg`. It defaults to enabled for new or older settings files. Always Show Stamina controls the live stamina bar below health. When disabled, it appears while stamina is below capacity, including recovery. Exhaustion is labeled until the 20% recovery threshold is met.

Hints read the current `InputMap` events for `jump`, `toggle_flight`, and `sprint`. This project's defaults currently display Space, F, and Shift. Keyboard modifiers and physical-key layout conversion are supported; keyboard/mouse alternatives are displayed together. If only controller bindings exist, Godot's event text is used. Missing bindings display Unbound. The hints refresh every 0.25 seconds while enabled, so future runtime rebinding is reflected without hard-coded key names. This task does not add a key-remapping screen.

The old `ChargeUI` diagnostics remain controlled by the developer performance-HUD checkbox. The new gameplay HUD is separate and does not depend on that toggle.

## Changing the color scheme

Open **`assets/ui/default_palette.tres`** in Godot's Inspector. This is the shared palette used by the new HUD and the main, pause, and Powers menus. Change its color fields, save, and restart the running game to refresh all styles.

- **Accent / Accent Soft:** cyan bars, icons, highlights, and soft highlights.
- **Text Primary / Text Secondary / Text On Accent:** foreground text colors.
- **Background / Surface / Surface Raised / Surface Selected:** menu and selection backgrounds.
- **Border / Focus / Owned Border / Locked Tint:** state and outline colors.
- **Shadow:** text contrast against the world.

`scripts/ui-scripts/ui_palette.gd` defines the exported resource fields and common menu styling. The `.tres` holds the active scheme; individual HUD/menu scripts reference it instead of defining their own hex colors. Glow opacity is derived from the accent. Developer diagnostics retain their existing styling.

## Editing layout, copy, and hint actions

- `scenes/ui/gameplay_hud.tscn`: positions, spacing, bar widths, font sizes, health icon, and corner anchors. It is instanced under Player as `GameplayHUD` without moving existing nodes.
- `scripts/ui-scripts/gameplay_hud.gd`: health/XP subscriptions, shared-palette styling, and key-hint display. The `HINTS` mapping selects input action IDs and label keys.
- `localization/powers.json`: the `hud.*` keys hold HUD text and settings labels using the existing locale-aware text lookup. Restart after editing text.
- `scripts/game_settings.gd`: persistent hint and always-show preferences.
- `scripts/ui-scripts/control_hint_settings.gd`: shared settings checkbox for main and pause menus.

## Validation

`tests/test_gameplay_hud.gd` checks starting visibility, actual damage, XP/level changes, changing maximum health, live key rebinding and modifiers, unbound actions, both settings menus, persistence, population-setting coexistence, and shared palette use. It writes preferences only to a temporary test file. Existing population/HUD and Powers localization tests cover affected integrations.

In Godot, test damage and XP gains with Always Show enabled and disabled. Check the contextual four-second readouts and health remaining visible while damaged. Toggle Show Control Hints in Settings → Gameplay, restart, and check persistence. Rebind an action through InputMap or a future controls screen and check the hint. Edit the shared palette, restart, and compare the HUD with the menus.

## Files changed

Added the palette script/resource, gameplay HUD script/scene, shared hint-settings control, this guide, and `tests/test_gameplay_hud.gd`. Updated `scenes/player.tscn`, `scripts/game_settings.gd`, `scripts/ui-scripts/main_menu.gd`, `pause_menu.gd`, `powers_page.gd`, `power_menu_icon.gd`, and `localization/powers.json`. Existing gameplay movement, combat, and ability logic is unchanged.
