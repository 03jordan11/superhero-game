const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const work = path.join(root, 'artifacts/park_forest_benchmark');
const read = name => JSON.parse(fs.readFileSync(path.join(work, name + '.json')));
const median = values => {
  const sorted = values.slice().sort((a, b) => a - b), mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
};
const runs = {before: [read('before_manual_1'), read('before_manual_2')], after: [read('current_1'), read('current_2')]};
const comparisons = [];
for (const view of ['park_day', 'park_night', 'forest_day']) {
  const entry = {view};
  for (const [variant, records] of Object.entries(runs)) {
    const samples = records.flatMap(run => run.scenarios.filter(row => row.name.startsWith(view)));
    if (samples.length !== 4) throw Error('Incomplete trials for ' + variant + ' ' + view);
    const frames = samples.map(row => row.stats.wall_ms.median);
    entry[variant] = {
      median_frame_ms: median(frames), trial_frame_ms: frames,
      median_trial_p95_ms: median(samples.map(row => row.stats.wall_ms.p95)),
      render_cpu_ms: median(samples.map(row => row.stats.render_cpu_ms.median)),
      gpu_ms: median(samples.map(row => row.stats.gpu_ms.median)),
      draw_calls: median(samples.map(row => row.stats.draw_calls.median)),
      primitives: median(samples.map(row => row.stats.primitives.median)),
      rendered_objects: median(samples.map(row => row.stats.objects.median)),
    };
  }
  entry.frame_time_change_percent = (entry.after.median_frame_ms / entry.before.median_frame_ms - 1) * 100;
  entry.draw_call_change_percent = (entry.after.draw_calls / entry.before.draw_calls - 1) * 100;
  comparisons.push(entry);
}
const history = JSON.parse(fs.readFileSync(path.join(root, 'artifacts/performance_audit/followup.json')));
const occlusion = JSON.parse(fs.readFileSync(path.join(root, 'artifacts/performance_audit/city_occlusion.json')));
const live = read('historical_1');
const historical = live.scenarios.map(now => {
  const old = [...history.scenarios, ...occlusion.scenarios].find(row => row.name === now.name);
  return {view: now.name, old_median_ms: old.stats.wall_ms.median, current_median_ms: now.stats.wall_ms.median,
    old_p95_ms: old.stats.wall_ms.p95, current_p95_ms: now.stats.wall_ms.p95,
    old_draws: old.stats.draw_calls.median, current_draws: now.stats.draw_calls.median,
    current_median_fps_equivalent: 1000 / now.stats.wall_ms.median};
});
const result = {
  date: '2026-09-22', engine: runs.after[0].engine.string, gpu: runs.after[0].gpu,
  viewport: runs.after[0].viewport,
  method: 'Fixed 1600x900 cameras, full render scale, High graphics, uncapped, VSync off. Static A/B: current code, actors removed, world frozen, identical seed 8421. Run order current/before/before/current; two 4-second trials per view per run. Historical: live simulation, 12-second settle then 5-second sample per camera. Historical comparisons include all intervening project changes.',
  before_source: 'Park from git 7679e234789e272071d1008f692b2f238cee5a42; CityLife tree containers from the same commit with the 596 prior automated forest-transition deletions applied. Current uses the user-saved scenes.',
  source_counts: read('source_counts'), source_hashes: runs.after[0].source_hashes,
  comparisons, historical,
  inventories: Object.fromEntries(Object.entries(runs).map(([key, values]) => [key, {park: values[0].park, forest: values[0].forest, total_nodes: values[0].total_nodes}])),
  trials: Object.fromEntries(Object.entries(runs).map(([key, values]) => [key, values.map(run => ({run: run.run, scenarios: run.scenarios}))])),
  historical_run: live,
};
fs.mkdirSync(path.join(root, 'benchmarks/results'), {recursive: true});
fs.writeFileSync(path.join(root, 'benchmarks/results/park_forest_2026-09-22.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({comparisons, historical, inventory: Object.fromEntries(Object.entries(result.inventories).map(([key, val]) => [key, {nodes: val.total_nodes, park_triangles: val.park.triangles, forest_triangles: val.forest.triangles}]))}, null, 2));
