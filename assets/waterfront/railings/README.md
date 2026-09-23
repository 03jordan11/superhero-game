# Riverbank railing

`riverbank_railings.res` contains all 124 authored railing spans in one surface (496 triangles). The mesh uses `railing_material.tres`, a double-sided alpha-cutout material with an embedded ImageTexture. `railing.png` is the readable source/preview of that texture; replacing the PNG alone does not replace the embedded image. To change its appearance in Godot, assign the replacement texture to the material's Albedo Texture field and save the material.

The builder is `../tools/riverbank_railings.gd`. It preserves an existing material and constructs the mesh from each QuayWall's `railing_length` metadata and transform. The waterfront generator calls this helper automatically. Do not regenerate the whole waterfront merely to change the material: that generator also rebuilds unrelated authored scenery.

The instance is `Riverbanks/RiverbankRailings` in `scenes/waterfront.tscn`. `scenes/super_city.tscn` hides it because all the previous railing pieces were already hidden in Main. It has no collision, matching the previous bars and posts; quay-wall collision is unchanged.
