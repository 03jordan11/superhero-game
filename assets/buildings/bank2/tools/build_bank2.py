"""Blender source builder for the contemporary glass-and-steel bank2 POI."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parent/'bank_tools'))
from geometry import Bank
b=Bank(HERE,modern=True)
# A granite banking podium supports a slim office tower and two upper setbacks.
b.box('Banking podium','Stone',(0,0,4.5),(40,30,9),True)
b.box('Main tower core','Dark metal',(0,1,49.5),(30,24,81),True)
b.box('Upper setback core','Dark metal',(0,2,101),(24,20,22),True)
# The sealed sloped crown below supplies its own shell and collision; no
# overlapping rectangular core surfaces underneath it.
b.box('Podium coping','Steel',(0,0,9.12),(40.3,30.3,.24))
# Lobby glazing modules; central front modules are replaced by a doorway.
for side in [-1,1]:
    for x in [-17,-12,-7,7,12,17]:b.window('Lobby glazing',(x,side*15.025,.6),(-side,0,0),4.6,7.3,int(x+20),lit=True)
    for y in [-12,-7,-2,3,8,12]:b.window('Lobby returns',(side*20.025,y,.6),(0,side,0),3.8,7.3,int(y+35))
for x in [-19.5,19.5]:b.box('Podium piers','Steel',(x,-15.16,4.1),(.28,.32,8.2))
# Recessed-looking glazed entrance, with an explicit gap in its decorative base.
b.box('Entrance doors','Entrance glass',(0,-15.095,1.8),(5.2,.12,3.6),True)
for x in [-2.8,0,2.8]:b.box('Entrance frames','Steel',(x,-15.20,1.9),(.12,.18,3.8))
b.box('Entrance header','Steel',(0,-15.20,3.9),(5.72,.18,.20))
for x in [-.65,.65]:b.box('Entry handles','Steel',(x,-15.34,1.5),(.06,.12,.70))
b.box('Floating canopy','Dark metal',(0,-16.2,4.5),(12,4,.25),True)
b.box('Canopy fascia','Steel',(0,-18.23,4.5),(12,.12,.34))
b.box('Bank sign plaque','Dark metal',(0,-15.10,6.6),(9,.15,1.5))
for left,right in [(-20,-2.9),(2.9,20)]:
    b.box('Front granite plinth','Stone',((left+right)/2,-15.08,.25),(right-left,.12,.5))
# Curtain modules include spandrels, mullions and floor divisions in their texture.
# Broad structural fins are retained as actual silhouette geometry.
for floor in range(20):
    z=9.4+floor*4.0
    for side in [-1,1]:
        for i,x in enumerate([-12.5,-7.5,-2.5,2.5,7.5,12.5]):
            b.window('Main curtain wall',(x,1+side*12.025,z),(-side,0,0),4.98,3.96,floor*7+i+(0 if side<0 else 19))
        for i,y in enumerate([-8.0,-2,4,10]):
            b.window('Main curtain returns',(side*15.025,y,z),(0,side,0),5.98,3.96,floor*5+i+11)
for x in [-15,-5,5,15]:
    for y in [-11.13,13.13]:b.box('Vertical steel fins','Steel',(x,y,49.5),(.22,.38,81))
for x in [-15.13,15.13]:
    for y in [-11,1,13]:b.box('Side steel fins','Steel',(x,y,49.5),(.38,.22,81))
for floor in range(5):
    z=90.3+floor*4.2
    for side in [-1,1]:
        for i,x in enumerate([-9,-3,3,9]):b.window('Upper curtain wall',(x,2+side*10.025,z),(-side,0,0),5.98,4.16,floor*5+i+3)
        for i,y in enumerate([-5.5,-.5,4.5,9.5]):b.window('Upper curtain returns',(side*12.025,y,z),(0,side,0),4.98,4.16,floor*7+i+27)
for x in [-12.1,12.1]:
    for y in [-8.1,12.1]:b.box('Setback corner fins','Steel',(x,y,101),(.30,.30,22))
b.box('Podium terrace','Roof',(0,0,9.05),(39.4,29.4,.10),True)
b.box('First setback terrace','Roof',(0,1,90.05),(29.5,23.5,.10),True)
b.box('Second setback terrace','Roof',(0,2,112.05),(23.5,19.5,.10),True)
for z,w,d,cy in [(90.25,30.4,24.4,1),(112.25,24.4,20.4,2)]:
    for y in [cy-d/2,cy+d/2]:b.box('Setback edge rails','Steel',(0,y,z),(w,.16,.30))
    for x in [-w/2,w/2]:b.box('Setback edge rails','Steel',(x,cy,z),(.16,d,.30))
# Slanted crown: sealed sloping roof, with a matching convex collision hull.
p=[(-10,-5,112),(10,-5,112),(10,11,112),(-10,11,112),
   (-10,-5,120),(10,-5,128),(10,11,128),(-10,11,120)]
for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
    b.face('Sloped crown','Steel',[p[i] for i in f])
b.hulls.append({'name':'SlopedCrown','points':[[x,z,-y] for x,y,z in p]})
# Dark louver panels stay below the lowest edge of the sloping roof.
for side in [-1,1]:
    b.box('Crown ventilation','Dark metal',(0,3+side*8.03,116),(17,.10,5))
    for z in [114,115,116,117,118]:b.box('Crown louver bands','Steel',(0,3+side*8.10,z),(17,.12,.10))
# Rear service door reaches grade and has a simple steel surround.
b.box('Rear service door','Dark metal',(0,15.12,1.6),(2.0,.14,3.2),True)
for x in [-1.1,1.1]:b.box('Rear frame','Steel',(x,15.18,1.65),(.18,.18,3.3))
b.box('Rear frame','Steel',(0,15.18,3.4),(2.4,.18,.18))
b.finish([('BANK',(0,-15.20,6.13),1.0,'Steel')],
         [(-15,15.7,0),(15,15.7,0)],(135,-175,115),(0,0,61),165,
         [{'position':[18,0,0],'height':9.1},{'position':[14,0,0],'height':90.1},{'position':[0,0,-3],'height':124}])
