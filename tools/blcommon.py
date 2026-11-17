# 블렌더 스크립트 공통 도구
import bpy, bmesh, math, random
from mathutils import Vector, Matrix

class Builder:
    def __init__(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.mats = {}
        self.parts = []

    def mat(self, name, col):
        if name not in self.mats:
            m = bpy.data.materials.new(name)
            m.diffuse_color = (*col, 1.0)
            self.mats[name] = m
        return self.mats[name]

    def finish(self, obj, m, bevel=0.0, segs=2, smooth=False):
        obj.data.materials.append(m)
        if bevel > 0:
            md = obj.modifiers.new("bev", "BEVEL")
            md.width = bevel
            md.segments = segs
            md.limit_method = "NONE"
        if smooth:
            for p in obj.data.polygons:
                p.use_smooth = True
        self.parts.append(obj)
        return obj

    def box(self, size, loc, m, bevel=0.015, rot=(0, 0, 0), segs=2):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
        o = bpy.context.object
        o.scale = size
        bpy.ops.object.transform_apply(scale=True)
        return self.finish(o, m, bevel, segs, smooth=segs > 2)

    def cyl(self, r, depth, loc, m, rot=(0, 0, 0), verts=12, r2=None, bevel=0.0):
        if r2 is None:
            bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
        else:
            bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
        return self.finish(bpy.context.object, m, bevel, 2, smooth=True)

    def blob(self, size, loc, m, rot=(0, 0, 0), segs=12, rings=8):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=loc, rotation=rot, segments=segs, ring_count=rings)
        o = bpy.context.object
        o.scale = size
        bpy.ops.object.transform_apply(scale=True)
        return self.finish(o, m, 0, 2, smooth=True)

    def curve(self, points, radius, m, res=1, radii=None, fill_caps=True):
        cu = bpy.data.curves.new("c", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = radius
        cu.bevel_resolution = res
        cu.use_fill_caps = fill_caps
        sp = cu.splines.new("POLY")
        sp.points.add(len(points) - 1)
        for i, p in enumerate(points):
            sp.points[i].co = (p[0], p[1], p[2], 1)
            if radii:
                sp.points[i].radius = radii[i]
        o = bpy.data.objects.new("c", cu)
        self.scene.collection.objects.link(o)
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.convert(target="MESH")
        return self.finish(bpy.context.object, m, 0, 2, smooth=True)

    def lattice_door(self, cx, cz, w, h, y, rot_z, paper, frame, wood, panel=True):
        rm = Matrix.Rotation(rot_z, 4, "Z")
        def P(lx, ly, lz):
            v = rm @ Vector((lx, ly, lz))
            return (cx + v.x, y + v.y, cz + v.z)
        self.box((w, 0.02, h), P(0, 0, 0), paper, 0.0, rot=(0, 0, rot_z))
        f = 0.07
        for dz in (h / 2 + f / 2, -h / 2 - f / 2):
            self.box((w + 2 * f, 0.09, f), P(0, -0.03, dz), frame, 0.01, rot=(0, 0, rot_z))
        for dx in (w / 2 + f / 2, -w / 2 - f / 2):
            self.box((f, 0.09, h), P(dx, -0.03, 0), frame, 0.01, rot=(0, 0, rot_z))
        n = max(2, int(w / 0.16))
        for i in range(1, n):
            self.box((0.022, 0.04, h), P(-w / 2 + w * i / n, -0.025, 0), frame, 0.0, rot=(0, 0, rot_z))
        m = max(2, int(h / 0.16))
        for j in range(1, m):
            if panel and j < m * 0.2:
                continue
            self.box((w, 0.04, 0.022), P(0, -0.025, -h / 2 + h * j / m), frame, 0.0, rot=(0, 0, rot_z))
        if panel:
            self.box((w, 0.05, h * 0.2), P(0, -0.02, -h / 2 + h * 0.1), wood, 0.008, rot=(0, 0, rot_z))

    def join_export(self, name, out, objs=None):
        objs = objs if objs is not None else self.parts
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.convert(target="MESH")
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = name
        me = obj.data
        if "Col" in me.color_attributes:
            for a in list(me.color_attributes):
                if a.name != "Col":
                    me.color_attributes.remove(a)
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = 0
        return obj

    def export(self, out):
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=out, export_apply=True, export_yup=True, export_normals=True,
                                  export_materials="EXPORT", export_vertex_color="ACTIVE")
        tris = 0
        for o in bpy.data.objects:
            if o.type == "MESH":
                tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        print("saved", out, "triangles", tris)

def paint_vertex_colors(obj, fn):
    """fn(world_co, normal) -> (r,g,b)"""
    me = obj.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    attr = me.color_attributes["Col"]
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = obj.matrix_world @ me.vertices[vi].co
            c = fn(co, me.vertices[vi].normal)
            attr.data[li].color = (c[0], c[1], c[2], 1.0)
