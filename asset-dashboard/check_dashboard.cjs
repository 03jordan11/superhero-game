// Check the actual single-file deliverable without opening a browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),zlib=require('node:zlib'),assert=require('node:assert/strict');
const html=fs.readFileSync(path.join(__dirname,'../Asset Dashboard.html'),'utf8');
assert(!html.includes('__VIEWER__')&&!html.includes('__SNAPSHOT__'),'Unfilled template');
const scripts=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
assert.equal(scripts.length,2);
new vm.Script(scripts[1],{filename:'Asset Dashboard.html inline JavaScript'});
const d=JSON.parse(zlib.gunzipSync(Buffer.from(scripts[0].trim(),'base64')));
assert(d.assets.length>1000);assert(d.errors.length===0);
assert(!/<(?:script|link)\b[^>]*(?:src|href)\s*=\s*["']https?:/i.test(html),'External runtime dependency');
assert(!/\bfetch\s*\(/.test(scripts[1]),'Viewer must not fetch external data');
const expected={hospital:5612,city_hall:6738,firehouse:1520,bank1:1082,bank2:1896,police_station:1147};
for(const [name,tris] of Object.entries(expected)){
 const a=d.assets.find(a=>a.source===`res://assets/buildings/${name}/${name}.tscn`);
 assert(a,`Missing ${name}`);
 assert.equal(a.parts.filter(p=>p.visible).reduce((n,p)=>n+d.meshes[p.g].triangles,0),tris,name);
 assert(a.bounds.size.every(n=>Number.isFinite(n)&&n>0));
}
const bank=d.assets.find(a=>a.source==='res://assets/buildings/bank1/bank1.tscn');
assert(bank.parts.some(p=>d.materials[p.m].maps.emission!==undefined),'Bank emission texture missing');
assert(d.assets.some(a=>a.kind==='audio'&&a.audio.startsWith('data:audio/')),'Offline audio missing');
assert(d.assets.some(a=>a.source.includes('/trees/')&&a.kind==='model'),'Tree models missing');
for(const m of d.materials)for(const id of Object.values(m.maps))assert(d.textures[id].preview.startsWith('data:image/png;base64,'));
console.log(`PASS: inline JavaScript parses; offline payload decodes; ${d.assets.length} entries, textures/audio/trees and all six POI counts verified.`);
