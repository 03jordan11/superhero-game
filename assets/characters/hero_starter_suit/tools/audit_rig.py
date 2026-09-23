"""Verify the exported suit rather than relying on authoring counts."""
import hashlib
import json
import struct
from pathlib import Path
import numpy as np
OUT=Path(__file__).resolve().parents[1]

def read(path):
    raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+n]),raw[28+n:]

def values(doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    width={'VEC2':2,'VEC3':3,'VEC4':4,'SCALAR':1}[a['type']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
    result=np.frombuffer(binary,dtype=dtype,count=a['count']*width,
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    if a.get('normalized',False): result=result.astype(float)/np.iinfo(dtype).max
    return result

def images(doc,binary):
    hashes=[]
    for image in doc['images']:
        view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
        hashes.append(hashlib.sha256(binary[start:start+view['byteLength']]).hexdigest())
    return sorted(hashes)

source,source_binary=read(OUT/'hero_starter_suit.glb')
doc,binary=read(OUT/'hero_starter_suit_rigged.glb')
primitive=doc['meshes'][0]['primitives'][0];attributes=primitive['attributes']
positions=values(doc,binary,attributes['POSITION'])
triangles=values(doc,binary,primitive['indices']).reshape(-1,3)
weights=values(doc,binary,attributes['WEIGHTS_0'])
joints=values(doc,binary,attributes['JOINTS_0'])
assert len(triangles)==2172 and len(doc['skins'][0]['joints'])==65
assert weights.shape==(len(positions),4)
assert np.isfinite(positions).all() and np.isfinite(weights).all()
assert np.all(weights>=0) and np.allclose(weights.sum(1),1,atol=1e-6)
assert np.all(joints<65)
normal=np.cross(positions[triangles[:,1]]-positions[triangles[:,0]],positions[triangles[:,2]]-positions[triangles[:,0]])
assert np.all(np.linalg.norm(normal,axis=1)>1e-10)
head=[doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']].index('Head')
face=(positions[:,1]>=1.54)&(abs(positions[:,0])<.23)
assert np.allclose((weights[face]*(joints[face]==head)).sum(1),1,atol=1e-6)
names=[doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
neck=names.index('neck_01')
shoulders=(abs(positions[:,0])>=.185)&(abs(positions[:,0])<.23)&(positions[:,1]>1.47)&(positions[:,1]<1.525)
assert shoulders.sum()>=4
assert np.max((weights[shoulders]*((joints[shoulders]==head)|(joints[shoulders]==neck))).sum(1))<.05, 'Shoulder caps must not be pinned to the hood/head'
seams={}
for point,indices,influences in zip(positions,joints,weights):
    signature=np.zeros(65)
    for index,weight in zip(indices,influences): signature[index]+=weight
    key=tuple(point)
    if key in seams: assert np.allclose(signature,seams[key],atol=1e-7)
    seams[key]=signature
assert images(source,source_binary)==images(doc,binary)
source_attributes=source['meshes'][0]['primitives'][0]['attributes']
for name in ['TEXCOORD_0','COLOR_0']:
    original=values(source,source_binary,source_attributes[name])
    for value in values(doc,binary,attributes[name]):
        if name=='COLOR_0':
            # Blender's byte-color round trip permits one code value per
            # channel, not one code value for the combined RGB vector norm.
            assert np.min(np.max(abs(original.astype(float)-value),axis=1))<1./255
        else: assert np.min(np.linalg.norm(original.astype(float)-value,axis=1))<2e-7
audit=json.loads((OUT/'rig_audit.json').read_text())
audit.update({'exported_vertices':len(positions),'normalized_weights':True,'matching_seam_weights':True,
    'rigid_face_and_upper_hood':True,'shoulder_caps_follow_body_not_head':True,
    'degenerate_triangles':0,'all_three_texture_images_byte_identical':True})
(OUT/'rig_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('STARTER_SUIT_EXPORTED_RIG_AUDIT_PASS',json.dumps(audit))
