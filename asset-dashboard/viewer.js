// Dependency-free WebGL2 inspector. All resources are embedded by the builder.
const canvas=$('viewer'), gl=canvas.getContext('webgl2',{antialias:true,alpha:true});
const gpu=new Map(), texGPU=new Map();let previewParts=[], previewBounds=null, pending=false, dragging=null;
let yaw=.65,pitch=.28,distance=30,target=[0,0,0],radius=10;
const I=()=>[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
const sub=(a,b)=>a.map((x,i)=>x-b[i]), dot=(a,b)=>a.reduce((n,x,i)=>n+x*b[i],0), cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]], unit=a=>{const d=Math.hypot(...a)||1;return a.map(x=>x/d)};
function mul(a,b){const o=new Float32Array(16);for(let c=0;c<4;c++)for(let r=0;r<4;r++)for(let k=0;k<4;k++)o[c*4+r]+=a[k*4+r]*b[c*4+k];return o}
function look(eye,at){const z=unit(sub(eye,at)),x=unit(cross([0,1,0],z)),y=cross(z,x);return [x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-dot(x,eye),-dot(y,eye),-dot(z,eye),1]}
function perspective(aspect,near,far){const f=1/Math.tan(Math.PI/8),v=1/(near-far);return [f/aspect,0,0,0,0,f,0,0,0,0,(far+near)*v,-1,0,0,2*far*near*v,0]}
function normalMatrix(m){const x=[m[0],m[1],m[2]],y=[m[4],m[5],m[6]],z=[m[8],m[9],m[10]],d=dot(x,cross(y,z))||1;return [...cross(y,z),...cross(z,x),...cross(x,y)].map(v=>v/d)}
function decode(b64,Type){if(!b64)return new Type(0);const s=atob(b64),a=new Uint8Array(s.length);for(let i=0;i<s.length;i++)a[i]=s.charCodeAt(i);return new Type(a.buffer)}
let program,U,white,black;
if(gl){
 const vs=`#version 300 es
 precision highp float;layout(location=0)in vec3 position;layout(location=1)in vec3 normal;layout(location=2)in vec2 uv;layout(location=3)in vec4 color;
 uniform mat4 model,viewProjection;uniform mat3 normalTransform;out vec3 N;out vec3 P;out vec2 UV;out vec4 C;
 void main(){vec4 p=model*vec4(position,1.);P=p.xyz;N=normalTransform*normal;UV=uv;C=color;gl_Position=viewProjection*p;}`;
 const fs=`#version 300 es
 precision highp float;in vec3 N;in vec3 P;in vec2 UV;in vec4 C;out vec4 outColor;
 uniform vec4 albedo;uniform vec3 emission,eye;uniform float energy,nightAmount,metallic,roughness,cutoff;uniform int mode,alphaMode,vertexColor,emissionOperator;uniform sampler2D baseMap,glowMap;
 void main(){vec4 base=texture(baseMap,UV)*albedo;if(vertexColor==1)base*=C;if(alphaMode>=2&&base.a<cutoff)discard;
 vec3 normal=length(N)>.01?normalize(N):normalize(cross(dFdx(P),dFdy(P)));if(!gl_FrontFacing)normal=-normal;
 vec3 light=normalize(vec3(-.6,1.,.7)),toEye=normalize(eye-P);float diffuse=max(dot(normal,light),0.);float fill=max(dot(normal,normalize(vec3(.7,.25,-.8))),0.);
 vec3 color=base.rgb*(mix(.47,.13,nightAmount)+mix(.63,.14,nightAmount)*diffuse+.12*fill);
 float spec=pow(max(dot(normal,normalize(light+toEye)),0.),mix(80.,8.,roughness));color+=mix(vec3(.13),base.rgb,metallic)*spec*(1.-roughness*.6);
 vec3 texGlow=texture(glowMap,UV).rgb;vec3 glow=(emissionOperator==1?emission*texGlow:emission+texGlow)*energy;
 if(mode==2)color=vec3(.035)+glow;else color+=glow*nightAmount;
 if(mode==1)color=mix(vec3(.69,.95,.84),vec3(.9,.96,1.),nightAmount);
 color=vec3(1.)-exp(-color*1.15);outColor=vec4(color,alphaMode==1?base.a:1.);}`;
 function shader(type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s}
 program=gl.createProgram();gl.attachShader(program,shader(gl.VERTEX_SHADER,vs));gl.attachShader(program,shader(gl.FRAGMENT_SHADER,fs));gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));
 U=Object.fromEntries(['model','viewProjection','normalTransform','albedo','emission','eye','energy','nightAmount','metallic','roughness','cutoff','mode','alphaMode','vertexColor','emissionOperator','baseMap','glowMap'].map(n=>[n,gl.getUniformLocation(program,n)]));
 function solidTexture(color){const t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array(color));return t}
 white=solidTexture([255,255,255,255]);black=solidTexture([0,0,0,255]);
 gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);
}
function texture(id){if(id===undefined||id<0)return white;if(texGPU.has(id))return texGPU.get(id);const t=gl.createTexture();texGPU.set(id,t);gl.bindTexture(gl.TEXTURE_2D,t);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([255,255,255,255]));const im=new Image();im.onload=()=>{gl.bindTexture(gl.TEXTURE_2D,t);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,false);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,im);gl.generateMipmap(gl.TEXTURE_2D);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR_MIPMAP_LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);requestDraw()};im.src=D.textures[id].preview;return t}
function geometry(id){if(gpu.has(id))return gpu.get(id);const m=D.meshes[id],vao=gl.createVertexArray();gl.bindVertexArray(vao);
 for(const [loc,key,n,def]of [[0,'positions',3,[0,0,0,1]],[1,'normals',3,[0,0,0,1]],[2,'uv',2,[0,0,0,1]],[3,'colors',4,[1,1,1,1]]]){const a=decode(m[key],Float32Array);if(a.length){const b=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.bufferData(gl.ARRAY_BUFFER,a,gl.STATIC_DRAW);gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,n,gl.FLOAT,false,0,0)}else{gl.disableVertexAttribArray(loc);gl.vertexAttrib4fv(loc,def)}}
 let indices=decode(m.indices,Uint32Array);if(!indices.length)indices=Uint32Array.from({length:m.vertices},(_,i)=>i);
 const ib=gl.createBuffer();gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,ib);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,indices,gl.STATIC_DRAW);
 const g={vao,ib,count:indices.length,indices,wire:null};gpu.set(id,g);return g}
function wireBuffer(g){if(!g.wire){const edges=new Uint32Array(g.indices.length*2);for(let i=0,j=0;i<g.indices.length;i+=3){const a=g.indices[i],b=g.indices[i+1],c=g.indices[i+2];edges[j++]=a;edges[j++]=b;edges[j++]=b;edges[j++]=c;edges[j++]=c;edges[j++]=a}g.wire=gl.createBuffer();gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,g.wire);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,edges,gl.STATIC_DRAW)}return g.wire}
function requestDraw(){if(!pending){pending=true;requestAnimationFrame(draw)}}
let lastTime=0;
function draw(time){pending=false;if(!gl||!previewParts.length)return;if(auto){yaw+=Math.min(time-lastTime,50)*.00018}lastTime=time;
 const dpr=Math.min(devicePixelRatio,1.7),w=Math.max(1,Math.round(canvas.clientWidth*dpr)),h=Math.max(1,Math.round(canvas.clientHeight*dpr));if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h}
 gl.viewport(0,0,w,h);gl.clearColor(0,0,0,0);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.useProgram(program);
 const eye=[target[0]+distance*Math.sin(yaw)*Math.cos(pitch),target[1]+distance*Math.sin(pitch),target[2]+distance*Math.cos(yaw)*Math.cos(pitch)];
 gl.uniformMatrix4fv(U.viewProjection,false,mul(perspective(w/h,Math.max(radius*.0005,distance-radius*2,.01),distance+radius*4+10),look(eye,target)));gl.uniform3fv(U.eye,eye);gl.uniform1f(U.nightAmount,night);gl.uniform1i(U.mode,view==='wire'?1:view==='emission'?2:0);gl.uniform1i(U.baseMap,0);gl.uniform1i(U.glowMap,1);
 for(const transparent of [false,true]){transparent?gl.enable(gl.BLEND):gl.disable(gl.BLEND);gl.depthMask(!transparent);
 for(const p of previewParts){const m=D.materials[p.m];if((m.alpha===1)!==transparent)continue;const g=geometry(p.g);gl.bindVertexArray(g.vao);gl.uniformMatrix4fv(U.model,false,p.t);gl.uniformMatrix3fv(U.normalTransform,false,p.normal||(p.normal=normalMatrix(p.t)));
 // Godot's native triangle winding is clockwise; mirrored transforms reverse it.
 const determinant=p.t[0]*(p.t[5]*p.t[10]-p.t[6]*p.t[9])-p.t[4]*(p.t[1]*p.t[10]-p.t[2]*p.t[9])+p.t[8]*(p.t[1]*p.t[6]-p.t[2]*p.t[5]);gl.frontFace(determinant<0?gl.CCW:gl.CW);if(m.cull===2||view==='wire')gl.disable(gl.CULL_FACE);else{gl.enable(gl.CULL_FACE);gl.cullFace(m.cull===1?gl.FRONT:gl.BACK)}
 gl.uniform4fv(U.albedo,m.albedo);gl.uniform3fv(U.emission,m.emission.slice(0,3));gl.uniform1f(U.energy,m.emission_enabled||m.maps.emission!==undefined?m.energy:0);gl.uniform1f(U.metallic,m.metallic);gl.uniform1f(U.roughness,m.roughness);gl.uniform1f(U.cutoff,m.cutoff);gl.uniform1i(U.alphaMode,m.alpha);gl.uniform1i(U.vertexColor,m.vertex_color?1:0);gl.uniform1i(U.emissionOperator,m.emission_operator??1);
 gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,texture(m.maps.albedo));gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,m.maps.emission===undefined&&m.emission_operator===0?black:texture(m.maps.emission));
 if(view==='wire'){gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,wireBuffer(g));gl.drawElements(gl.LINES,g.count*2,gl.UNSIGNED_INT,0)}else{gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,g.ib);gl.drawElements(gl.TRIANGLES,g.count,gl.UNSIGNED_INT,0)}
 }}gl.depthMask(true);gl.bindVertexArray(null);if(auto)requestDraw()}
function fit(){if(!previewBounds)return;target=previewBounds.center.slice();radius=Math.max(.3,Math.hypot(...previewBounds.size)/2);distance=radius*2.8/Math.min(1,Math.max(.3,canvas.clientWidth/canvas.clientHeight));yaw=.65;pitch=.28;requestDraw()}
function sphere(){const pos=[],norm=[],uv=[],indices=[];for(let y=0;y<=20;y++)for(let x=0;x<=32;x++){const a=y*Math.PI/20,b=x*Math.PI/16,v=[Math.sin(a)*Math.cos(b),Math.cos(a),Math.sin(a)*Math.sin(b)];pos.push(...v);norm.push(...v);uv.push(x/32,y/20)}for(let y=0;y<20;y++)for(let x=0;x<32;x++){const a=y*33+x;indices.push(a,a+33,a+1,a+1,a+33,a+34)}const enc=a=>{let s='';for(const b of new Uint8Array(a.buffer))s+=String.fromCharCode(b);return btoa(s)};const id=D.meshes.length;D.meshes.push({positions:enc(new Float32Array(pos)),normals:enc(new Float32Array(norm)),uv:enc(new Float32Array(uv)),colors:'',indices:enc(new Uint32Array(indices)),vertices:pos.length/3,triangles:indices.length/3,lods:{}});return id}
let sphereId;
function setPreview(a){previewParts=[];previewBounds=a.bounds;const other=$('preview-other');other.innerHTML='';other.style.display='none';canvas.style.display='block';$('stage-help').style.display='block';
 if(a.kind==='model')previewParts=(a.parts||[]).filter(p=>p.visible);
 if(a.kind==='material'){sphereId??=sphere();previewParts=[{g:sphereId,m:a.material,t:I()}];previewBounds={center:[0,0,0],size:[2,2,2]};$('stage-meta').textContent='Material preview sphere · not asset geometry'}
 if(!gl&&previewParts.length){other.innerHTML='<p>WebGL2 is unavailable. Enable graphics acceleration in your browser to use the 3D viewer.</p>';previewParts=[]}
 else if(a.kind==='image')other.innerHTML=`<img src="${D.textures[a.texture].preview}" alt="${esc(a.name)}">`;
 else if(a.kind==='audio')other.innerHTML=a.audio?`<div style="width:100%;text-align:center"><h2>♫</h2><p>${esc(a.name)}</p><audio controls preload="none" src="${a.audio}"></audio><p class="note">${Number(a.seconds||0).toFixed(1)} seconds · ${esc(a.source)}</p></div>`:'<p>Audio resource inventory. Open its source for playback.</p>';
 else if(a.code)other.innerHTML=`<pre>${esc(a.code)}</pre>`;
 else if(!previewParts.length)other.innerHTML='<div><h3>Source inventory</h3><p class="note">No static 3D surfaces in this entry. Runtime scripts, UI scenes and animation resources can be inspected through Files & feedback.</p>'+sourceBox(a.source)+'</div>';
 if(!previewParts.length){canvas.style.display='none';other.style.display='flex';$('stage-help').style.display='none'}
 for(const id of ['view-shaded','view-wire','view-emission','fit','rotate','night'])$(id).disabled=!previewParts.length;
 fit();requestDraw()}
for(const id of ['shaded','wire','emission'])$('view-'+id).onclick=()=>{view=id;for(const n of ['shaded','wire','emission'])$('view-'+n).classList.toggle('active',n===id);requestDraw()};
$('fit').onclick=fit;$('rotate').onclick=()=>{auto=!auto;$('rotate').classList.toggle('active',auto);lastTime=performance.now();requestDraw()};$('night').oninput=e=>{night=+e.target.value;requestDraw()};
canvas.oncontextmenu=e=>e.preventDefault();canvas.onpointerdown=e=>{dragging={x:e.clientX,y:e.clientY,pan:e.button===2||e.shiftKey};canvas.setPointerCapture(e.pointerId)};
canvas.onpointermove=e=>{if(!dragging)return;const dx=e.clientX-dragging.x,dy=e.clientY-dragging.y;dragging.x=e.clientX;dragging.y=e.clientY;if(dragging.pan){const scale=distance*.0015,right=[Math.cos(yaw),0,-Math.sin(yaw)],up=[-Math.sin(yaw)*Math.sin(pitch),Math.cos(pitch),-Math.cos(yaw)*Math.sin(pitch)];target=target.map((v,i)=>v-dx*scale*right[i]+dy*scale*up[i])}else{yaw-=dx*.006;pitch=Math.max(-1.48,Math.min(1.48,pitch+dy*.006))}requestDraw()};
canvas.onpointerup=canvas.onpointercancel=()=>dragging=null;canvas.ondblclick=fit;canvas.addEventListener('wheel',e=>{e.preventDefault();distance=Math.min(radius*100,Math.max(radius*.035,distance*Math.exp(e.deltaY*.001)));requestDraw()},{passive:false});new ResizeObserver(requestDraw).observe(canvas);
