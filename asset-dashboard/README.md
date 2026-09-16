# Asset workspace

Open **`../Asset Dashboard.html`** in a current Chrome, Edge, or Firefox browser.
The single HTML file contains its model data, textures, audio, code, and viewer;
it works offline and does not require a server. Allow a few seconds for its
embedded library to decompress. WebGL2/hardware acceleration is needed for 3D.

## Inspecting assets

- Search or filter the left catalog. **Assets** shows complete models, scenes,
  embedded props and audio; **Resources** shows supporting meshes, textures,
  materials, shaders and source files. **All** searches both.
- Drag to orbit, scroll to zoom, right-drag or Shift-drag to pan. Double-click
  the viewer or click **Fit** to reset framing.
- **Wireframe** reveals triangles. **Illumination** isolates captured emission;
  the **Day/Night** slider changes inspection lighting and emission strength.
- Expand **Mesh breakdown** to see triangle contributions and repeated instances.
- **Materials** includes texture thumbnails, original dimensions, mipmap status,
  emission, transparency and source shaders. Click a texture to enlarge it.
- **Files & feedback** links to source files and lists static references. Notes
  stay in the browser; **Copy asset + feedback** prepares text to send to Codex.
  Browser source-file links may display or download the file. Copy its `res://`
  path when you want to locate it in Godot.

## Measurement limits

This is an authored snapshot, not a running Godot scene. It includes library
assets as well as referenced assets; a static reference does not prove that an
asset is spawned in the current game. Dynamic spawning, scripts, skeletal
animation, visibility decisions, custom shaders and physics are not executed.
Large world scenes take more work to draw than individual objects.

Triangle and vertex totals count all visible authored placements at full detail.
Collision triangles are separate. Materials and image content are deduplicated.
Surface totals are **not** measured draw calls. Texture memory is an RGBA8
estimate with captured mipmaps, **not** measured VRAM. The viewer embeds previews
up to 1,024 px; it reports original texture dimensions. Preview shading is an
approximation, including glass, custom shaders and illumination. No in-game FPS
is measured. The page does not update automatically.

## Rebuilding this snapshot

These helper files are development artifacts, not a game feature. The extractor
loads resources read-only and never saves game scenes or assets. The web page
uses vanilla JavaScript/WebGL2 and has no third-party dependencies.

From the project root in PowerShell, first run the Godot resource extractor with
the real renderer (headless dummy rendering loses MultiMesh transform data):

```powershell
$dashboardProcess = Start-Process -FilePath 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--path "D:/Superhero Game/superhero-demo" --script res://asset-dashboard/export_snapshot.gd --log-file "D:/Superhero Game/superhero-demo/asset-dashboard/export.log"' -WindowStyle Hidden -PassThru -Wait
```

After it finishes, bundle the page:

```powershell
& 'C:/Users/jorda/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'asset-dashboard/build_dashboard.py'
node 'asset-dashboard/check_dashboard.cjs'
```

`validation.json` records entry counts, independent geometry checks and the POI
triangle totals. The extractor completed without GDScript parse/runtime errors;
the local environment reported unrelated certificate-store and shader-cache
warnings. Browser visual verification was blocked by the automation browser's
local-file URL security policy. Opening the HTML manually is the remaining
visual check; no Godot gameplay test is required for this external page.
