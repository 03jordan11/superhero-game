# Superhero Prototype — Codex Instructions

## Project

This is a Godot 4 third-person superhero game prototype written in GDScript.

The immediate goal is to make superhero traversal fun before building combat, missions, NPCs, or a detailed city.

Current mechanics include:

* Third-person character movement
* Mouse-controlled camera
* Walking
* Sprinting
* Normal/charged jumping
* Forward momentum during charged jumps

## Development priorities

Prioritize gameplay feel and rapid iteration over production architecture.

Current development order:

1. Third-person movement
2. Charged superhero jumping
3. Air control
4. Landing impacts
5. Flight
6. Basic city traversal
7. Physics objects
8. Picking up and throwing vehicles
9. Combat
10. World systems

Do not implement later systems unless specifically asked.

## Coding guidelines

* Use GDScript.
* Target the version of Godot defined by this project's `project.godot`.
* Prefer simple, readable implementations over complicated abstractions.
* Use Godot-native nodes and APIs where practical.
* Expose gameplay tuning values using `@export` so they can be adjusted in the Inspector.
* Keep movement code easy to tune.
* Do not introduce third-party addons without asking.
* Do not rewrite working systems unnecessarily.
* Preserve existing controls unless the requested feature requires changing them.
* Avoid premature architecture or generalized frameworks.

## Godot scenes

Be careful when modifying `.tscn` files manually.

Do not remove or restructure existing nodes unless required by the task.

When adding nodes programmatically to `.tscn` files, verify node paths used by existing GDScript still resolve correctly.

## Testing

After making changes:

1. Check GDScript for parse errors.
2. Run any available project validation or Godot command-line checks.
3. Report which files were modified.
4. Describe what changed.
5. Tell the user exactly what behavior to test in Godot.

Never claim gameplay behavior was visually verified unless the game was actually run and observed.

## Current philosophy

The prototype should evoke games such as Hulk: Ultimate Destruction and older Superman games where simply traversing the city is entertaining.

Movement should feel powerful, exaggerated, responsive, and fun rather than realistic.
