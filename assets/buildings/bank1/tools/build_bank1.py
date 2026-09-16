"""Blender source builder for the traditional bank1 POI."""
from pathlib import Path
import sys
import math
import numpy as np
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parent/'bank_tools'))
from geometry import Bank
b=Bank(HERE)

b.box('Banking hall','Stone',(0,0,10),(34,26,20),True)
b.box('Entrance pavilion','Stone',(0,-15,11.25),(14,4,22.5),True)
# A stone base around the perimeter stops behind every door face.
b.box('Foundation','Shadow stone',(0,0,.35),(34.16,26.08,.70))
for side in [-1,1]:b.box('Portico base','Shadow stone',(side*4.5,-15,.35),(5,4.12,.70))
for z,h,over in [(6.2,.35,.30),(17.3,.40,.50),(19.7,.45,.85),(20.3,.18,1.0)]:
    b.box('Front cornices','Pale trim',(0,-13.12,z),(34+over,.65,h))
    b.box('Rear cornices','Pale trim',(0,13.12,z),(34+over,.65,h))
    for side in [-1,1]:b.box('Side cornices','Pale trim',(side*17.12,0,z),(.65,26,h))
# Entrance stays clear below the header: no band or plinth across its door.
b.box('Entrance doors','Entrance glass',(0,-17.085,2.0),(3.5,.06,4),True)
for x in [-1.9,1.9]:b.box('Door frame','Bronze',(x,-17.17,2.1),(.20,.20,4.2))
b.box('Door frame','Bronze',(0,-17.17,4.3),(4,.20,.20))
b.box('Door mullion','Bronze',(0,-17.18,2),(.08,.15,4))
for x in [-.35,.35]:b.box('Door handles','Gold',(x,-17.29,1.4),(.08,.10,.60))
b.box('Door canopy','Pale trim',(0,-17.50,4.65),(5,1.30,.25),True)
# Give the large entrance window its own sharp atlas instead of stretching a
# small office-window cell over thirteen metres. Its stone and frame never emit.
gy,gx=np.mgrid[:1024,:512]
wx=(gx/511-.5)*7.4;wz=gy/1023*13.5
hero=np.broadcast_to(np.array([.57,.51,.39]),(1024,512,3)).copy()
outer=(abs(wx)<3.65)&(wz>.12)&((wz<=9.8)|(wx*wx+(wz-9.8)**2<3.65**2))
glass=(abs(wx)<3.38)&(wz>.40)&((wz<=9.8)|(wx*wx+(wz-9.8)**2<3.38**2))
glass &= (abs(wx)>.06)&(abs(wz-3.9)>.065)&(abs(wz-7.8)>.065)
hero[outer]=[.20,.15,.08]
hero[glass]=np.array([.09,.16,.17])+(wz[glass]/13.5*.05)[:,None]
hero[wz<.12]=[.22,.20,.15]
hero_emit=np.zeros_like(hero)
hero_emit[glass]=[.55,.40,.23]
b.material('Great window glass',(.09,.16,.17),b.texture('great_window_albedo',hero),b.texture('great_window_emission',hero_emit),metallic=.20,roughness=.32)
b.face('Great arched window','Great window glass',[(-3.7,-17.075,6),(3.7,-17.075,6),(3.7,-17.075,19.5),(-3.7,-17.075,19.5)],[(0,0),(1,0),(1,1),(0,1)])
# Arc band is silhouette detail; sash, sill and ornate tracery are painted.
b.ring('Great arch surround',(0,-17.13,15.8),3.7,4.15,segments=16)
for side in [-1,1]:
    b.box('Great arch jambs','Pale trim',(side*3.92,-17.13,10.9),(.44,.22,9.8))
    for x in [side*5.4]:
        b.box('Column bases','Pale trim',(x,-17.15,.70),(1.85,1.85,1.4),True)
        b.lathe('Entrance columns','Stone',(x,-17.15),[(1.4,.68),(16.5,.56)],10,True)
        b.box('Column capitals','Bronze',(x,-17.15,16.9),(1.8,1.8,.8))
    b.box('Corner pilasters','Pale trim',(side*16.4,-13.18,10.7),(.7,.40,18.6))
    for x in [side*10,side*14]:
        b.window('Front windows',(x,-13.055,1.4),(1,0,0),2.45,4.0,int(abs(x)))
        b.window('Front arched windows',(x,-13.055,8.0),(1,0,0),2.65,7.5,int(abs(x))+3,True)
# Strong entablature and a raised sign crown, without sculpted statues.
for side in [-1,1]:
    b.box('Split column entablature','Pale trim',(side*5.8,-15,17.8),(3.9,5.5,.55))
for z,w,d,h in [(20.6,15.5,5.4,.40),(22.6,15.4,5.3,.30)]:
    b.box('Portico entablature','Pale trim',(0,-15,z),(w,d,h))
b.box('Crown sign block','Stone',(0,-15,23.9),(11.8,3.9,2.3),True)
b.box('Sign recess','Bronze',(0,-16.97,24),(9.8,.08,1.65))
b.box('Crown cap','Pale trim',(0,-15,25.15),(12.5,4.4,.24),True)
b.box('Raised crest','Stone',(0,-15,25.45),(8,3.9,.4),True)
# Repeated cornice brackets are six-sided blocks; no modeled floral carving.
for x in [-6,-4.5,-3,3,4.5,6]:
    b.box('Cornice brackets','Bronze',(x,-17.48,21.9),(.40,.42,.9))
for side in [-1,1]:
    for y in [-9,-4,1,6,10]:
        for z,height,arch in [(1.4,4.0,False),(8,7.5,True)]:
            b.window('Side windows',(side*17.025,y,z),(0,side,0),2.5,height,int(y+20+z),arch)
for x in [-13,-8,-3,3,8,13]:
    b.window('Rear windows',(x,13.025,8),(-1,0,0),2.6,7.5,x+16,True)
    if abs(x)>3:b.window('Rear windows',(x,13.025,1.4),(-1,0,0),2.4,4,x+20)
# Rear service door and frame stand in front of the base, not behind its stone face.
b.box('Rear door','Bronze',(0,13.16,1.5),(1.65,.10,3),True)
for x in [-.97,.97]:b.box('Rear door surround','Pale trim',(x,13.18,1.5),(.28,.20,3))
b.box('Rear door surround','Pale trim',(0,13.18,3.14),(2.22,.20,.28))
b.box('Main roof','Roof',(0,0,20.05),(33.4,25.4,.10),True)
b.box('Portico roof','Roof',(0,-15,22.56),(13.5,3.5,.12),True)
for x in [-16.75,16.75]:b.box('Roof parapets','Stone',(x,0,20.6),(.45,26,1.2),True)
for y in [-12.75,12.75]:b.box('Roof parapets','Stone',(0,y,20.6),(34,.45,1.2),True)
for x in [-10,10]:
    b.box('Roof vents','Dark metal',(x,5,20.65),(2,2,1.1))
    b.box('Roof vent caps','Bronze',(x,5,21.25),(2.3,2.3,.15))
b.finish([('BANK',(0,-17.04,23.5),1.25,'Gold')],
         [(-10,13.7,0),(10,13.7,0)],(56,-78,44),(0,0,12),66,
         [{'position':[10,0,0],'height':20.1},{'position':[0,0,15],'height':25.65}])
