"""Local vertex edits shared by the two approved hero costumes (Blender Z up)."""
import numpy as np


def smooth(a, b, value):
    t = max(0., min(1., (value-a)/(b-a)))
    return t*t*(3-2*t)


def flatten_lips(mesh, outfit):
    # Mouth landmarks in metres after fitting. Nose, cheeks and chin stay put.
    low, lower, upper, high, depth = {
        'underwear': (1.596, 1.604, 1.623, 1.631, .0740),
        'starter': (1.574, 1.583, 1.605, 1.614, .0830),
    }[outfit]
    before = np.array([tuple(v.co) for v in mesh.vertices])
    color = mesh.color_attributes.get('LipTone') or mesh.color_attributes.new(name='LipTone',type='FLOAT_COLOR',domain='POINT')
    mesh.color_attributes.active_color = color
    mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(color)
    for vertex in mesh.vertices:
        x, y, z = vertex.co
        weight = smooth(low, lower, z)*(1-smooth(upper, high, z))
        weight *= 1-smooth(.017, .033, abs(x))
        weight *= smooth(.038, .052, -y)
        target = depth-.004*min(1., (x/.033)**2)
        if weight and -y > target:
            # Retain ten percent of the relief instead of collapsing coplanar
            # lip folds into zero-area triangles. Only depth changes.
            vertex.co.y += (-y-target)*weight*.90
        # Vertex paint, not an atlas edit: mute the generated pale lip band
        # without touching eye whites, beard, skin textures or normal maps.
        tint = (.64,.47,.39)
        color.data[vertex.index].color = tuple(1+(c-1)*weight for c in tint)+(1.,)
    mesh.update()
    after = np.array([tuple(v.co) for v in mesh.vertices])
    delta = after-before
    moved = np.linalg.norm(delta,axis=1)>1e-8
    assert np.all(delta[:,[0,2]]==0)
    return {'unique_vertices_adjusted':len(np.unique(before[moved],axis=0)),
            'maximum_depth_retraction_m':float(delta[:,1].max()),
            'maximum_recess_fill_m':float(-delta[:,1].min()),
            'mouth_width_height_unchanged':True,'local_lip_vertex_tint':True}
