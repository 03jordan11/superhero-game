"""Small shared authoring helpers for the two bank POIs; requires Blender Python."""
import bpy
import math
import json
from pathlib import Path
from collections import defaultdict
import numpy as np
from mathutils import Vector

class Bank:
    def __init__(self, folder, modern=False):
        self.folder=Path(folder)
        self.name=self.folder.name
        self.out=self.folder.parents[2]/'artifacts'/self.name
        for p in [self.folder/'props',self.out]:p.mkdir(parents=True,exist_ok=True)
        (self.out/'.gdignore').touch()
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        bpy.context.scene.unit_settings.system='METRIC'
        bpy.context.scene.unit_settings.scale_length=1
        self.buffers=defaultdict(lambda:[[],[],[],[]])
        self.materials={};self.boxes=[];self.hulls=[];self.props=[]
        self.modern=modern
        self.rng=np.random.default_rng(7202 if modern else 7201)
        self.make_materials()

    def texture(self,name,pixels):
        h,w=pixels.shape[:2]
        im=bpy.data.images.new(self.name+'_'+name,width=w,height=h,alpha=True)
        rgba=np.ones((h,w,4),dtype=np.float32);rgba[:,:,:pixels.shape[2]]=pixels
        im.pixels.foreach_set(rgba.ravel())
        im.filepath_raw=str(self.folder/(self.name+'_'+name+'.png'));im.file_format='PNG';im.save()
        return im

    def material(self,name,color,image=None,emission=None,metallic=0,roughness=.75):
        mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
        bs=mat.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*color,1)
        bs.inputs['Roughness'].default_value=roughness;bs.inputs['Metallic'].default_value=metallic
        for im,socket in [(image,'Base Color'),(emission,'Emission Color')]:
            if im is not None:
                tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
                mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[socket])
        if emission is not None:bs.inputs['Emission Strength'].default_value=1
        self.materials[name]=mat

    def make_materials(self):
        y,x=np.mgrid[:512,:512]
        row=y//32
        mortar=(y%32<1)|((x+(row%2)*64)%128<1)
        shade=self.rng.normal(0,.005,x.shape)-mortar*.035
        rgb=np.array([.57,.51,.39] if not self.modern else [.40,.43,.43])+shade[:,:,None]
        self.material('Stone',(.57,.51,.39),self.texture('stone',rgb))
        self.material('Pale trim',(.65,.60,.48))
        self.material('Shadow stone',(.25,.25,.22))
        self.material('Bronze',(.16,.12,.055),metallic=.45)
        self.material('Gold',(.64,.43,.13),metallic=.5)
        self.material('Steel',(.40,.47,.50),metallic=.55,roughness=.38)
        self.material('Dark metal',(.035,.055,.065),metallic=.4)
        self.material('Roof',(.095,.12,.13))
        self.material('Paving',(.40,.42,.39))
        # Eight by eight window atlas. Every cell has painted trim and nonemitting frames.
        # bank1's upper half contains arches; bank2 uses full curtain-wall modules.
        atlas=np.ones((1024,1024,3),dtype=np.float32)
        emission=np.zeros_like(atlas)
        yy,xx=np.mgrid[:128,:128]
        for row in range(8):
            for col in range(8):
                cell=np.zeros((128,128,3),dtype=np.float32)
                if self.modern:
                    cell[:]=[.10,.15,.18]
                    glass=(xx>3)&(xx<125)&(yy>14)&(yy<125)
                    glass &= abs(xx-64)>1
                    tint=np.array([.085,.18,.24])*self.rng.uniform(.85,1.18)
                    cell[glass]=tint+(yy[glass]/128*.045)[:,None]
                    cell[yy<3]=[.33,.40,.43]
                else:
                    cell[:]=[.55,.49,.37]
                    outer=(xx>8)&(xx<120)&(yy>8)&(yy<123)
                    glass=(xx>16)&(xx<112)&(yy>18)&(yy<117)
                    if row>=4:
                        outer &= (yy<85)|(((xx-64)/56)**2+((yy-85)/38)**2<1)
                        glass &= (yy<85)|(((xx-64)/48)**2+((yy-85)/32)**2<1)
                    cell[outer]=[.20,.15,.08]
                    glass &= (abs(xx-64)>2)&(abs(yy-58)>2)
                    cell[glass]=np.array([.09,.16,.17])+(yy[glass]/128*.05)[:,None]
                    cell[(yy>=6)&(yy<=12)]=[.70,.64,.49]
                    cell[yy<6]=[.23,.21,.16]
                atlas[row*128:(row+1)*128,col*128:(col+1)*128]=cell
                if self.rng.random()<.46:
                    glow=np.zeros_like(cell)
                    glow[glass]=np.array([.70,.54,.30] if (row+col)%3 else [.43,.57,.65])*self.rng.uniform(.55,.95)
                    emission[row*128:(row+1)*128,col*128:(col+1)*128]=glow
        im=self.texture('windows_albedo',atlas);em=self.texture('windows_emission',emission)
        self.material('Windows',(.1,.2,.25),im,em,metallic=.20,roughness=.32)
        self.material('Unlit glazing',(.1,.2,.25),im,metallic=.20,roughness=.32)
        self.material('Entrance glass',(.045,.10,.13),metallic=.30,roughness=.25)
        # Clock detail for the historic bank: dial, ticks and hands painted on one quad.
        cy,cx=np.mgrid[:256,:256];dx=(cx-128)/128;dy=(cy-128)/128
        radius=np.sqrt(dx*dx+dy*dy)
        clock=np.broadcast_to(np.array([.24,.19,.11]),(256,256,3)).copy()
        clock[radius<.89]=[.70,.66,.50]
        angle=np.arctan2(dy,dx)
        ticks=(radius>.72)&(radius<.84)&(np.abs(np.sin(angle*6))<.12)
        clock[ticks]=[.075,.09,.09]
        hands=((abs(dx)<.018)&(dy>-.06)&(dy<.60))|((abs(dy+dx*.55)<.025)&(dx>0)&(dx<.45))
        clock[hands]=[.05,.065,.065]
        self.material('Clock face',(.7,.66,.5),self.texture('clock',clock))

    def face(self,group,material,points,uv=None):
        vs,fs,uvs,ms=self.buffers[group];start=len(vs)
        vs.extend([tuple(p) for p in points]);fs.append(tuple(range(start,start+len(points))))
        if uv is None:
            a,b,c=map(Vector,points[:3]);n=(b-a).cross(c-a)
            axis=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=axis]
            uv=[(p[axes[0]]/8,p[axes[1]]/8) for p in points]
        uvs.extend(uv);ms.append(material)

    def box(self,group,mat,center,size,collision=False):
        x,y,z=center;a,b,c=[v/2 for v in size]
        p=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
           (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
        for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.face(group,mat,[p[i] for i in f])
        if collision:self.boxes.append({'name':group,'center':[x,z,-y],'size':[size[0],size[2],size[1]]})

    def lathe(self,group,mat,center,rings,segments=8,collision=False):
        x,y=center
        p=[(x+math.cos(i*math.tau/segments)*r,y+math.sin(i*math.tau/segments)*r,z) for z,r in rings for i in range(segments)]
        if collision:self.hulls.append({'name':group,'points':[[x,z,-y] for x,y,z in p]})
        self.face(group,mat,list(reversed(p[:segments])));self.face(group,mat,p[-segments:])
        for row in range(len(rings)-1):
            for i in range(segments):
                j=(i+1)%segments
                self.face(group,mat,[p[row*segments+i],p[row*segments+j],p[(row+1)*segments+j],p[(row+1)*segments+i]])

    def window(self,group,p,t,width,height,index=0,arch=False,lit=True):
        p,t=Vector(p),Vector(t)
        if not self.modern:index=index%32+(32 if arch else 0)
        else:index%=64
        u,v=index%8/8,index//8/8
        self.face(group,'Windows' if lit else 'Unlit glazing',
                  [p-t*width/2,p+t*width/2,p+t*width/2+Vector((0,0,height)),p-t*width/2+Vector((0,0,height))],
                  [(u+.001,v+.001),(u+.124,v+.001),(u+.124,v+.124),(u+.001,v+.124)])

    def ring(self,group,center,inner,outer,start=0,end=math.pi,segments=16,mat='Pale trim'):
        x,y,z=center
        for i in range(segments):
            a=start+(end-start)*i/segments;b=start+(end-start)*(i+1)/segments
            self.face(group,mat,[(x+math.cos(t)*r,y,z+math.sin(t)*r) for t,r in [(a,inner),(a,outer),(b,outer),(b,inner)]])

    def objects(self,collection):
        objects=[]
        for name,(vs,fs,uvs,slots) in self.buffers.items():
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();assert not mesh.validate(),name
            ob=bpy.data.objects.new(name,mesh);collection.objects.link(ob)
            used=list(dict.fromkeys(slots))
            for key in used:mesh.materials.append(self.materials[key])
            layer=mesh.uv_layers.new(name='UVMap');cursor=0
            for poly,key in zip(mesh.polygons,slots):
                poly.material_index=used.index(key)
                for loop in poly.loop_indices:layer.data[loop].uv=uvs[cursor];cursor+=1
            objects.append(ob)
        self.buffers.clear();return objects

    def text(self,objects,collection,text,p,size,mat='Gold'):
        curve=bpy.data.curves.new(text,'FONT');curve.body=text;curve.align_x='CENTER';curve.size=size;curve.extrude=0;curve.resolution_u=1
        ob=bpy.data.objects.new(text,curve);collection.objects.link(ob);ob.location=p;ob.rotation_euler=(math.pi/2,0,0)
        curve.materials.append(self.materials[mat])
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.convert(target='MESH');objects.append(bpy.context.object)

    def export(self,path,objects):
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_cameras=False,export_lights=False)

    @staticmethod
    def triangles(objects):
        total=0
        for ob in objects:ob.data.calc_loop_triangles();total+=len(ob.data.loop_triangles)
        return total

    def finish(self,lettering,bench_positions,camera,target,ortho,roof_tests):
        architecture=bpy.data.collections.new(self.name+' | architecture');bpy.context.scene.collection.children.link(architecture)
        objects=self.objects(architecture)
        for text,p,size,mat in lettering:self.text(objects,architecture,text,p,size,mat)
        prop_collection=bpy.data.collections.new('PROPS | separately editable');bpy.context.scene.collection.children.link(prop_collection)
        self.box('Bench','Pale trim',(0,0,.46),(2.2,.60,.16))
        for x in [-.72,.72]:self.box('Bench','Shadow stone',(x,0,.19),(.32,.46,.38))
        bench=self.objects(prop_collection)[0];self.export(self.folder/'props/bench.glb',[bench])
        for i,p in enumerate(bench_positions):
            ob=bpy.data.objects.new('Bench_%02d'%i,bench.data);prop_collection.objects.link(ob);ob.location=p
            self.props.append({'name':ob.name,'position':[p[0],p[2],-p[1]]})
        bpy.data.objects.remove(bench,do_unlink=True)
        total=self.triangles(objects)+self.triangles(list(prop_collection.objects));assert total<10000,total
        self.export(self.folder/(self.name+'.glb'),objects)
        all_objects=objects+list(prop_collection.objects)
        points=[ob.matrix_world@v.co for ob in all_objects for v in ob.data.vertices]
        report={'name':self.name,'units':'metres','godot_front':'+Z','base_triangles':self.triangles(objects),'total_triangles':total,
                'base_meshes':len(objects),'bench_triangles':36,'props':self.props,'collision_boxes':self.boxes,'collision_hulls':self.hulls,
                'bounds_min_blender':[min(p[i] for p in points) for i in range(3)],'bounds_max_blender':[max(p[i] for p in points) for i in range(3)],
                'mesh_triangles':{ob.name:self.triangles([ob]) for ob in objects},'roof_tests':roof_tests,'triangle_limit':10000}
        (self.folder/(self.name+'_manifest.json')).write_text(json.dumps(report,indent=2))
        rig=bpy.data.collections.new('PREVIEW ONLY | excluded from export');bpy.context.scene.collection.children.link(rig)
        def move(ob):
            for col in list(ob.users_collection):col.objects.unlink(ob)
            rig.objects.link(ob);return ob
        bpy.ops.mesh.primitive_plane_add(size=3000,location=(0,0,-.02));ground=move(bpy.context.object);ground.data.materials.append(self.materials['Paving'])
        bpy.ops.object.camera_add(location=camera);cam=move(bpy.context.object);cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.type='ORTHO';cam.data.ortho_scale=ortho;bpy.context.scene.camera=cam
        bpy.ops.object.light_add(type='SUN',location=(0,0,200));sun=move(bpy.context.object);sun.rotation_euler=(.4,-.5,-.4);sun.data.energy=2.5
        scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True
        scene.render.resolution_x=1400;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
        scene.world.color=(.30,.30,.30)
        for im in bpy.data.images:
            if im.source=='FILE':im.pack();im.filepath=bpy.path.relpath(im.filepath,start=str(self.folder))
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type=='VIEW_3D':
                    space=area.spaces.active;space.clip_end=4000;space.region_3d.view_location=Vector(target);space.region_3d.view_distance=ortho*1.4
                    space.region_3d.view_rotation=cam.rotation_euler.to_quaternion();space.shading.color_type='MATERIAL'
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(self.folder/(self.name+'.blend')))
        for m in self.materials.values():m.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=0
        scene.render.filepath=str(self.out/(self.name+'_blender.png'));bpy.ops.render.render(write_still=True)
        print('BANK_COMPLETE '+self.name+' '+str(total)+' triangles')
