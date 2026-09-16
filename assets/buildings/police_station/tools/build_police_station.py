"""Five-storey tan masonry precinct; Blender metres, front -Y / Godot +Z."""
from pathlib import Path
import sys
import numpy as np
HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE.parent / 'bank_tools'))
from geometry import Bank


class Precinct(Bank):
    def make_materials(self):
        y, x = np.mgrid[:1024, :1024]
        row = y // 32
        joints = (y % 32 < 2) | ((x + row % 2 * 64) % 128 < 2)
        blocks = self.rng.uniform(-.018, .018, (32, 8))
        variation = blocks[row, ((x + row % 2 * 64) // 128) % 8]
        stone = np.array([.49, .41, .29]) + (variation - joints * .045 + self.rng.normal(0, .004, x.shape))[:, :, None]
        self.material('Stone', (.49, .41, .29), self.texture('masonry', stone))
        for name, color in [('Pale trim', (.60, .53, .40)), ('Shadow stone', (.29, .29, .26)),
                            ('Blue steel', (.025, .18, .28)), ('Dark metal', (.045, .07, .08)),
                            ('Roof', (.14, .16, .15)), ('Paving', (.40, .42, .39)),
                            ('Lettering', (.82, .82, .72)), ('Gold', (.68, .44, .09)),
                            ('Entrance glass', (.045, .105, .14))]:
            self.material(name, color, metallic=.25 if 'steel' in name else 0)
        atlas = np.zeros((1024, 1024, 3), dtype=np.float32)
        emission = np.zeros_like(atlas)
        yy, xx = np.mgrid[:128, :128]
        for row in range(8):
            for col in range(8):
                cell = np.zeros((128, 128, 3)); cell[:] = [.025, .15, .24]
                glass = (xx > 4) & (xx < 123) & (yy > 8) & (yy < 120)
                glass &= (abs(xx - 64) > 2) & (abs(yy - 41) > 2)
                cell[glass] = np.array([.085, .16, .19]) + (yy[glass] / 128 * .06)[:, None]
                # Blinds, mullions and sill shadow all live in the texture.
                blinds = glass & (xx < 63) & (yy > (75 if (row + col) % 3 else 47))
                cell[blinds] = [.38, .40, .36]
                cell[blinds & (yy % 8 < 1)] *= .76
                cell[yy < 4] = [.055, .085, .10]
                cell[(yy >= 4) & (yy <= 7)] = [.21, .30, .32]
                glow = np.zeros_like(cell)
                if self.rng.random() < .55:
                    glow[glass] = [.54, .49, .33]
                    glow[blinds] *= .25
                atlas[row*128:(row+1)*128, col*128:(col+1)*128] = cell
                emission[row*128:(row+1)*128, col*128:(col+1)*128] = glow
        im = self.texture('windows_albedo', atlas)
        self.material('Windows', (.1, .2, .25), im, self.texture('windows_emission', emission), metallic=.2, roughness=.35)
        self.material('Unlit glazing', (.1, .2, .25), im, metallic=.2)
        # Original fictional precinct shield: a single textured quad, no sculpted badge.
        yy, xx = np.mgrid[:512, :512]; u=(xx-256)/256; v=yy/512
        badge = np.broadcast_to(np.array([.49, .41, .29]), (512, 512, 3)).copy()
        width = np.minimum(.80, np.maximum(0, v * 1.6))
        shield = (abs(u) < width) & (v > .07) & (v < .93)
        inner = (abs(u) < width-.075) & (v > .15) & (v < .87)
        badge[shield] = [.72, .49, .13]; badge[inner] = [.025, .12, .23]
        dx=u; dy=(v-.53)*2
        angles=np.arange(10)*np.pi/5
        radii=np.where(np.arange(10)%2 == 0, .43, .18)
        vertices=list(zip(np.sin(angles)*radii, np.cos(angles)*radii))
        star=np.zeros(dx.shape, dtype=bool)
        for i,(ax,ay) in enumerate(vertices):
            bx,by=vertices[(i+1)%10]
            star ^= ((ay>dy)!=(by>dy)) & (dx < (bx-ax)*(dy-ay)/(by-ay+1e-10)+ax)
        badge[star & inner] = [.83, .62, .22]
        badge[inner & (v>.77)] = [.67, .48, .18]
        self.material('Crest', (.5, .4, .2), self.texture('crest', badge))
        self.material('Lamps', (.7, .76, .72), emission=self.texture('lamps_emission', np.ones((8,8,3)) * [.48,.56,.57]))


b = Precinct(HERE, modern=True)
# Ground floor 4.8m, four office floors 4m each; roof at 20.8m.
b.box('Five storey main block', 'Stone', (0, 0, 10.4), (36, 24, 20.8), True)
b.box('Raised entrance tower', 'Stone', (-4.7, -12.55, 11.8), (4.4, 1.1, 23.6), True)
b.box('Tower edge', 'Pale trim', (-7.02, -12.5, 11.9), (.24, 1.25, 23.8))
b.box('Public entrance wing', 'Stone', (8.2, -13.9, 2.6), (17.6, 3.8, 5.2), True)
# Base bands stop at every doorway; no trim crosses a door face.
for x,w in [(-10,16),(11.5,13)]:
    b.box('Rear base', 'Shadow stone', (x,12.045,.30), (w,.12,.60))
b.box('Front left base','Shadow stone',(-12.6,-12.045,.30),(10.8,.12,.60))
for side in [-1,1]:b.box('Side base','Shadow stone',(side*18.045,0,.30),(.12,24,.60))
for x,w in [(2,4.8),(13,8)]:b.box('Wing base','Shadow stone',(x,-15.84,.30),(w,.12,.60))

for floor, z in enumerate([1.7, 6.0, 10.0, 14.0, 18.0]):
    # Continuous narrow ribbons, split by the solid entrance tower.
    for i,x in enumerate([-16,-13,-10]):
        b.window('Front office glazing', (x,-12.035,z), (1,0,0), 3, 1.65, floor*9+i)
    if floor > 0:
        for i,x in enumerate([-1,2,5,8,11,14,16.5]):
            b.window('Front office glazing',(x,-12.035,z),(1,0,0),3 if x<16 else 2,1.65,floor*9+i+3)
    for side in [-1,1]:
        for i,y in enumerate([-9,-5,-1,3,7,10]):
            b.window('Side office glazing',(side*18.035,y,z),(0,side,0),2.8,1.65,floor*11+i+(7 if side>0 else 0))
    for i,x in enumerate([-15,-11,-7,-3,5,9,13,16]):
        b.window('Rear office glazing',(x,12.035,z),(-1,0,0),2.6,1.65,floor*13+i)

# Recess-colored door panels sit outside masonry and end at grade.
def door(label,x,y,width,height,front=True):
    sign=-1 if front else 1
    b.box(label,'Entrance glass',(x,y,height/2),(width,.12,height),True)
    for xx in [x-width/2-.09,x+width/2+.09]:
        b.box(label+' frame','Blue steel',(xx,y+sign*.09,height/2),(.18,.19,height))
    b.box(label+' header','Blue steel',(x,y+sign*.09,height+.09),(width+.36,.19,.18))
    b.box(label+' center','Blue steel',(x,y+sign*.10,height/2),(.08,.20,height))
    for xx in [x-.18,x+.18]:b.box(label+' handles','Lettering',(xx,y+sign*.23,1.1),(.06,.08,.46))

door('Public doors',6.3,-15.94,3,3.15)
door('Rear service doors',1.5,12.18,2.1,2.8,False)
b.box('Blue entrance canopy','Blue steel',(6.3,-16.4,3.65),(5.6,2.2,.20),True)
b.box('Entrance sign panel','Blue steel',(6.3,-15.87,4.55),(10,.09,.85))
for x in [1.2,11.4,14.6]:
    b.window('Wing clerestory',(x,-15.845,2.15),(1,0,0),2.3,.85,int(x*3))
for x in [-.1,16.5]:
    b.box('Wall lamp housings','Blue steel',(x,-15.97,3.65),(.40,.22,.30))
    b.box('Wall lamp lenses','Lamps',(x,-16.10,3.62),(.28,.035,.16))
for x in [-1,4]:
    b.box('Rear lamp housings','Blue steel',(x,12.18,3.5),(.38,.22,.25))
    b.box('Rear lamp lenses','Lamps',(x,12.305,3.48),(.28,.03,.14))
b.face('Precinct shield','Crest',[(-6.35,-13.115,18.6),(-3.05,-13.115,18.6),(-3.05,-13.115,22),(-6.35,-13.115,22)],[(0,0),(1,0),(1,1),(0,1)])

b.box('Main roof','Roof',(0,0,20.85),(35.4,23.4,.10),True)
for side in [-1,1]:
    b.box('Side parapets','Stone',(side*17.8,0,21.3),(.4,24,1),True)
    b.box('Parapet coping','Pale trim',(side*17.8,0,21.84),(.54,23.06,.08))
for y in [-11.8,11.8]:
    b.box('Front rear parapets','Stone',(0,y,21.3),(36,.4,1),True)
    b.box('Parapet coping','Pale trim',(0,y,21.84),(36.25,.54,.08))
b.box('Tower coping','Pale trim',(-4.7,-12.55,23.67),(4.65,1.35,.14),True)
b.box('Wing roof','Roof',(8.2,-13.9,5.26),(17.6,3.8,.12),True)
b.box('Wing roof fascia','Pale trim',(8.2,-15.82,5.3),(18,.20,.30))
for x in [-10,9]:
    b.box('Rooftop equipment','Dark metal',(x,4,21.45),(3.5,2.7,1.1),True)
    b.box('Equipment caps','Shadow stone',(x,4,22.05),(3.7,2.9,.10))
# Low-poly rectangular antenna: silhouette only, no dense lattice.
b.box('Radio mast','Blue steel',(9,4,24.6),(.12,.12,5.2))
for z in [25,26.5]:b.box('Radio crossbars','Blue steel',(9,4,z),(1.6,.08,.08))

b.finish([('POLICE',(6.3,-15.935,4.26),.72,'Lettering'),
          ('PRECINCT 05',(-4.7,-13.12,17.6),.40,'Blue steel')],
         [(-10,12.8,0),(10,12.8,0)], (53,-72,41),(0,0,12),65,
         [{'position':[0,0,0],'height':20.9},{'position':[9,0,14],'height':5.32},
          {'position':[-4.7,0,12.55],'height':23.74}])
