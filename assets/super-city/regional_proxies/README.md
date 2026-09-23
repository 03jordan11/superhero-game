# Coastal POI proxies

Runtime meshes: `PrisonIsland.res`, `CargoShip.res`, `Airport.res`, `Flight1.res`, `Flight2.res`.

Each contains one material surface and embedded directional facade/night textures. PNG files are previews; changing one does not change the embedded runtime texture until rebaked. `near/` contains the prison/airport full-detail budget reductions. `inventory.json` records bake coverage and geometry. `scenery_audit.json` lists remaining scenery candidates without changing them.

See `docs/regional_proxies.md` for controls, exact counts, limitations, validation, changed files and rebuild commands. Runtime controller: `Main/SuperCity/RegionalProxies`.
