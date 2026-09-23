// One-time authored thinning. Run with node; never regenerate the regional scene.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const scenePath = path.join(root, 'scenes/city_life.tscn');
const reportPath = path.join(root, 'assets/trees/forest_transition.json');
const work = path.join(root, 'artifacts/forest_transition');
const source = fs.readFileSync(scenePath, 'utf8');
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
if (fs.existsSync(reportPath)) {
  const previous = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  if (hash(source) !== previous.after_sha256) throw Error('Scene has subsequent edits; do not reapply this one-time thinning.');
  console.log('Forest transition is already applied.');
  process.exit(0);
}
const smooth = value => { const t = Math.max(0, Math.min(1, value)); return t * t * (3 - 2 * t); };
function highwayX(z) {
  const knots = [[-740,-960],[-740,-1180],[-830,-1500],[-1040,-1900],[-1100,-2300],[-1100,-2845]];
  for (let i = 0; i < knots.length - 1; ++i) {
    const [x0,z0] = knots[i], [x1,z1] = knots[i + 1];
    if (z >= z1) return x0 + (x1 - x0) * smooth((z - z0) / (z1 - z0));
  }
  return -1100;
}
const blocks = source.split(/(?=^\[node )/m);
const treeHeader = /^\[node name="((?:Oak|Pine)_\d+)"[^\n]*parent="(Highway\/NorthernForest_[^"]+)"/;
const removed = [];
const bins = Array.from({length: 10}, (_, i) => ({distance_m: [i * 100, (i + 1) * 100], before: 0, after: 0}));
let before = 0;
const edited = blocks.filter(block => {
  const match = block.match(treeHeader);
  if (!match) return true;
  ++before;
  const pose = block.match(/transform = Transform3D\(([^)]+)\)/)[1].split(',').map(Number);
  const [x,y,z] = pose.slice(-3);
  const distance = Math.abs(x - highwayX(z));
  let keep = 1;
  // The original extra highway population ends abruptly at 550 m. Match the
  // sparser background there, then smoothly retain more toward the road.
  if (z >= -2845 && distance < 550) {
    const inward = 1 - smooth((distance - 60) / 490);
    const patch = Math.sin(x / 180 + Math.sin(z / 260)) * Math.cos(z / 210);
    keep = Math.max(0.25, Math.min(1, 0.38 + 0.50 * inward + 0.10 * patch));
  }
  // Feather the straight southern edge with varying depth, without moving trees.
  const edgeDepth = -1050 - z;
  const fadeWidth = 450 + 90 * Math.sin(x / 270) + 45 * Math.cos(x / 120);
  keep *= 0.20 + 0.80 * smooth(edgeDepth / fadeWidth);
  const nodePath = match[2] + '/' + match[1];
  const roll = crypto.createHash('sha256').update('forest-transition-2026-09-22/' + nodePath).digest().readUInt32LE(0) / 4294967296;
  const keepTree = roll < keep;
  if (z > -2300 && z < -1100 && distance < 1000) {
    const bin = bins[Math.floor(distance / 100)];
    ++bin.before;
    if (keepTree) ++bin.after;
  }
  if (!keepTree) removed.push({path: nodePath, position: [x,y,z]});
  return keepTree;
}).join('').replace(/(&"background_trees": )\d+/, (_, prefix) => prefix + (before - removed.length));
// Aside from removed tree blocks and their count, preserve every serialized byte.
const nonTrees = text => text.split(/(?=^\[node )/m).filter(block => !treeHeader.test(block)).join('').replace(/(&"background_trees": )\d+/, '$1COUNT');
if (nonTrees(source) !== nonTrees(edited)) throw Error('Unexpected non-tree change.');
fs.mkdirSync(work, {recursive: true});
fs.writeFileSync(path.join(work, 'city_life_before.txt'), source);
fs.writeFileSync(scenePath, edited);
const report = {
  scope: 'NorthernForest: gradual density within 550 m of Pine Pass highway, plus a 315–585 m feather along the city-facing edge at Z=-1050.',
  scene_before: before, removed_count: removed.length, scene_after: before - removed.length,
  before_sha256: hash(source), after_sha256: hash(edited),
  highway_density_bands_z_minus2300_to_minus1100: bins,
  removed
};
fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({...report, removed: undefined}, null, 2));
