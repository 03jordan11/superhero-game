// Build disposable baseline copies without changing any game scene.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const commit = '7679e234789e272071d1008f692b2f238cee5a42';
const work = path.join(root, 'artifacts/park_forest_benchmark');
fs.mkdirSync(work, {recursive: true});
const removed = new Set(JSON.parse(fs.readFileSync(path.join(root, 'assets/trees/forest_transition.json'))).removed.map(row => row.path));
const counts = {};
for (const name of ['central_park', 'city_life']) {
  let before = cp.execFileSync('git', ['show', commit + ':scenes/' + name + '.tscn'], {cwd: root, maxBuffer: 30e6}).toString();
  if (name === 'city_life') {
    before = before.split(/(?=^\[node )/m).filter(block => {
      const header = block.match(/^\[node name="([^"]+)"[^\n]*parent="([^"]+)"/);
      return !header || !removed.has(header[2] + '/' + header[1]);
    }).join('');
  }
  // A fixture must never claim the original scene's UID in the editor cache.
  before = before.replace(/^(\[gd_scene[^\r\n]*?) uid="[^"]+"/m, '$1');
  fs.writeFileSync(path.join(work, name + '_before.tscn'), before);
  const after = fs.readFileSync(path.join(root, 'scenes', name + '.tscn'), 'utf8');
  const inventory = text => ({
    trees: (text.match(/^\[node name="(?:Oak|Pine|Birch|Willow)_/gm) || []).length,
    lights: (text.match(/type="(?:OmniLight3D|SpotLight3D)"/g) || []).length,
    nodes: (text.match(/^\[node /gm) || []).length,
  });
  counts[name] = {before: inventory(before), after: inventory(after)};
}
fs.writeFileSync(path.join(work, 'source_counts.json'), JSON.stringify(counts, null, 2) + '\n');
console.log(JSON.stringify(counts, null, 2));
