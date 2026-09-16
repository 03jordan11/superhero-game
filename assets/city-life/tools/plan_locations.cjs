const fs = require('fs');
const layout = JSON.parse(fs.readFileSync('assets/super-city/layout.json','utf8'));
const overlaps = (a,b,pad=0) => a[0]<b[0]+b[2]+pad && a[0]+a[2]>b[0]-pad && a[1]<b[1]+b[3]+pad && a[1]+a[3]>b[1]-pad;
const buildings=layout.buildings.map(b=>b.rect);
const roads=layout.roads.map(r=>r.rect);
const blocked=[...buildings,...roads,layout.park_rect,...layout.river_rects];
const index=new Map();
for(const rect of blocked) for(let x=Math.floor(rect[0]/100);x<=Math.floor((rect[0]+rect[2])/100);x++) for(let z=Math.floor(rect[1]/100);z<=Math.floor((rect[1]+rect[3])/100);z++){ const key=`${x},${z}`; if(!index.has(key)) index.set(key,[]); index.get(key).push(rect); }
function clear(rect,pad=1) {for(let x=Math.floor((rect[0]-pad)/100);x<=Math.floor((rect[0]+rect[2]+pad)/100);x++)for(let z=Math.floor((rect[1]-pad)/100);z<=Math.floor((rect[1]+rect[3]+pad)/100);z++)for(const other of index.get(`${x},${z}`)||[])if(overlaps(rect,other,pad))return false;return true;}
const alleys=layout.roads.filter(r=>r.kind==='alley').map(r=>r.rect);
function distanceToRect(x,z,r){return Math.hypot(Math.max(r[0]-x,0,x-r[0]-r[2]),Math.max(r[1]-z,0,z-r[1]-r[3]));}
let field=null;
for(const [w,h] of [[80,70],[70,60],[60,52],[52,46]]){
 const candidates=[];
 for(let x=-1390;x<-620;x+=5)for(let z=-900;z<500;z+=5){const r=[x,z,w,h];if(clear(r,2)){const distance=Math.min(...alleys.map(a=>distanceToRect(x+w/2,z+h/2,a)));if(distance< w/2+18)candidates.push({rect:r,alley_distance:distance});}}
 if(candidates.length){candidates.sort((a,b)=>a.alley_distance-b.alley_distance);field=candidates[0];break;}
}
const diners=[];
if(!field){
 const candidates=[];
 for(let x=-1420;x<-680;x+=5)for(let z=-900;z<480;z+=5){
  const r=[x,z,68,62];
  if(roads.some(a=>overlaps(r,a,2)))continue;
  const nearby=layout.buildings.filter(b=>overlaps(r,b.rect,2));
  if(nearby.some(b=>b.district!=='WestVillage'||b.height_m>28)||nearby.length>4)continue;
  const distance=Math.min(...alleys.map(a=>distanceToRect(x+34,z+31,a)));
  if(distance>43)continue;
  candidates.push({rect:r,alley_distance:distance,cleared_buildings:nearby.map(b=>b.node),score:nearby.length*100+nearby.reduce((s,b)=>s+b.height_m,0)+distance});
 }
 candidates.sort((a,b)=>a.score-b.score);field=candidates[0]||null;
}
for(const road of layout.roads){if(road.kind!=='junction'||road.crossing_corridor)continue;const [x,z,w,h]=road.rect;
 for(const side of [-1,1])for(const end of [-1,1]){
  const r=[side<0?x-31:x+w+5,end<0?z-20:z+h+5,26,15];
  if(r[0]<-1480||r[0]+26>1480||r[1]<-960||r[1]+15>770||!clear(r,1))continue;
  if(field&&overlaps(r,field.rect,10))continue;
  if(diners.some(d=>Math.hypot(d.rect[0]-r[0],d.rect[1]-r[1])<400))continue;
  diners.push({rect:r,yaw:end<0?0:Math.PI});
  if(diners.length===5)break;
 }if(diners.length===5)break;
}
const result={field,diners};
fs.writeFileSync('assets/city-life/locations.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
