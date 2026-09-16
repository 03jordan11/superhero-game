# Shared stack smoke

Instance `stack_smoke.tscn` as a child of a building at its smokestack outlet. Used by industrial models 03, 07 and 09. Keep the effect separate from the building mesh.

- `activation_distance`: 350 m by default; checked against the active camera every 0.5 s.
- `smoke_enabled`: per-instance switch.
- `MAX_ACTIVE` in `stack_smoke.gd`: shared cap of 12 emitting instances.
- Particle `amount`: 18; `lifetime`: 8 seconds; fixed simulation: 15 FPS.
- Tune direction, speed, growth and color in the scene's ParticleProcessMaterial.

The shared radial texture and billboard quads produce soft gray smoke without additional lights, shadow casting or collision. Each emitter renders at most 36 triangles. Distant emitters are hidden and stop spawning particles; remaining particles can finish their lifetime. Occupancy/window seeds do not control smoke.
