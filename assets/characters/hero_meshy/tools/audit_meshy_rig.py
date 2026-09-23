"""Audit exported geometry, skin weights, UV seams and original texture bytes."""
import hashlib
import json
import struct
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT/'assets/characters/hero_meshy'

def read(path):
    raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+size]), raw[28+size:]

def values(doc,binary,index):
    a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
    count={'VEC2':2,'VEC3':3,'VEC4':4,'SCALAR':1}[a['type']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
    return np.frombuffer(binary,dtype=dtype,count=a['count']*count,
        offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,count)

def image_hashes(doc,binary):
    result=[]
    for image in doc['images']:
        v=doc['bufferViews'][image['bufferView']]; start=v.get('byteOffset',0)
        result.append(hashlib.sha256(binary[start:start+v['byteLength']]).hexdigest())
    return sorted(result)

source,source_binary=read(OUT/'source/meshy_reference_fro.glb')
doc,binary=read(OUT/'hero_meshy.glb')
primitive=doc['meshes'][0]['primitives'][0]; attributes=primitive['attributes']
positions=values(doc,binary,attributes['POSITION'])
triangles=values(doc,binary,primitive['indices']).reshape(-1,3)
weights=values(doc,binary,attributes['WEIGHTS_0'])
joints=values(doc,binary,attributes['JOINTS_0'])
assert len(triangles)==1552 and len(doc['skins'][0]['joints'])==65
assert weights.shape==(len(positions),4) and np.all(np.isfinite(weights))
assert np.all(weights>=0) and np.allclose(weights.sum(axis=1),1,atol=1e-6)
assert np.all(joints<65)
joint_names=[doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
head_joint=joint_names.index('Head')
head_mask=(positions[:,1]>=1.54)&(np.abs(positions[:,0])<.17)
assert head_mask.any()
assert np.allclose(np.sum(weights[head_mask]*(joints[head_mask]==head_joint),axis=1),1,atol=1e-7)
chest_mask=(positions[:,1]>=1.34)&(positions[:,1]<=1.41)&(np.abs(positions[:,0])<=.12)
assert np.all(positions[chest_mask,2] <= .068001), 'Pointed chest exceeds flattened profile'
edges_a=positions[triangles[:,1]]-positions[triangles[:,0]]
edges_b=positions[triangles[:,2]]-positions[triangles[:,0]]
assert np.all(np.linalg.norm(np.cross(edges_a,edges_b),axis=1)>1e-10)
seams={}
maximum_seam_weight_difference=0.0
for point,js,ws in zip(positions,joints,weights):
    signature=np.zeros(65)
    for j,w in zip(js,ws): signature[j]+=w
    key=tuple(point)
    if key in seams:
        difference=float(np.max(np.abs(seams[key]-signature)))
        maximum_seam_weight_difference=max(maximum_seam_weight_difference,difference)
        assert difference < 1e-7  # Float32 normalization roundoff only.
    seams[key]=signature
assert image_hashes(source,source_binary)==image_hashes(doc,binary)
source_attrs=source['meshes'][0]['primitives'][0]['attributes']
source_uv=values(source,source_binary,source_attrs['TEXCOORD_0'])
uv=values(doc,binary,attributes['TEXCOORD_0'])
# Export may reorder or merge equivalent UV/normal splits; every UV coordinate
# must still belong to the original atlas (Blender's V flip introduces roundoff).
for coordinate in uv:
    assert np.min(np.linalg.norm(source_uv-coordinate,axis=1))<2e-7
audit=json.loads((OUT/'rig_audit.json').read_text())
audit.update({'exported_vertices':len(positions), 'unique_geometric_vertices':len(seams),
    'normalized_weights':True,'matching_seam_weights':True,'degenerate_triangles':0,
    'maximum_seam_weight_difference':maximum_seam_weight_difference,
    'all_three_embedded_texture_images_byte_identical':True,
    'complete_lower_face_rigid_to_head':True,'rigid_head_exported_vertices':int(head_mask.sum()),
    'original_texture_sha256':image_hashes(source,source_binary)})
(OUT/'rig_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('EXPORTED_MESHY_RIG_AUDIT_PASS',json.dumps(audit))
