"""Helpers shared by the Blender map scripts.

Conventions
-----------
* 1 Blender unit == 1 Roblox stud.
* Roblox is Y-up, Blender is Z-up. A Roblox point (x, y, z) lives at
  Blender (x, -z, y). Every helper below takes *Roblox* coordinates so the
  generator reads like the Luau code it replaces.
* Every exported object carries ``rbx_*`` custom properties. Materials carry
  ``rbx_material`` (a Roblox Enum.Material name) and ``rbx_color`` (sRGB 0-255).
"""

import math

import bpy
from mathutils import Matrix, Vector

# Blender -> Roblox basis change: roblox_vec = C @ blender_vec
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
CT = C.transposed()
# Roblox cylinders run along their local X axis, Blender cylinders along Z.
CYL_Q = Matrix(((0, 1, 0), (1, 0, 0), (0, 0, -1)))

PALETTE = {
    # name: (Roblox material, sRGB colour, transparency)
    "FloorSlate": ("Slate", (40, 49, 64), 0),
    "FloorTile": ("SmoothPlastic", (64, 76, 94), 0),
    "FloorPlate": ("DiamondPlate", (72, 84, 108), 0),
    "FloorSeam": ("SmoothPlastic", (24, 31, 43), 0),
    "Marble": ("Marble", (196, 206, 218), 0),
    "WallPanel": ("Metal", (54, 66, 88), 0),
    "WallDark": ("Metal", (32, 41, 58), 0),
    "WallLight": ("SmoothPlastic", (150, 166, 184), 0),
    "Trim": ("Metal", (95, 112, 128), 0),
    "TrimDark": ("Metal", (26, 33, 47), 0),
    "Ceiling": ("Metal", (28, 36, 52), 0),
    "Glass": ("Glass", (118, 168, 214), 0.55),
    "GlassTint": ("Glass", (92, 130, 190), 0.35),
    "NeonCyan": ("Neon", (48, 207, 247), 0),
    "NeonBlue": ("Neon", (55, 135, 255), 0),
    "NeonViolet": ("Neon", (162, 91, 247), 0),
    "NeonMint": ("Neon", (88, 224, 196), 0),
    "NeonOrange": ("Neon", (255, 151, 53), 0),
    "NeonPink": ("Neon", (250, 118, 200), 0),
    "NeonWhite": ("Neon", (214, 232, 255), 0),
    "Grass": ("Grass", (58, 140, 112), 0),
    "Foliage": ("Grass", (54, 168, 150), 0),
    "FoliageDeep": ("Grass", (40, 118, 128), 0),
    "Bark": ("Wood", (86, 64, 54), 0),
    "Soil": ("Ground", (58, 46, 40), 0),
    "Rock": ("Rock", (58, 64, 78), 0),
    "RockDark": ("Basalt", (34, 38, 50), 0),
    "Fabric": ("Fabric", (58, 72, 118), 0),
    "WoodTrim": ("WoodPlanks", (122, 90, 64), 0),
}


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def get_material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    rbx_material, rgb, transparency = PALETTE[name]
    mat = bpy.data.materials.new(name)
    mat["rbx_material"] = rbx_material
    mat["rbx_color"] = list(rgb)
    mat["rbx_transparency"] = float(transparency)
    lin = [srgb_to_linear(v) for v in rgb] + [1.0]
    mat.diffuse_color = lin
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = lin
    if rbx_material in ("Metal", "DiamondPlate"):
        bsdf.inputs["Metallic"].default_value = 0.65
        bsdf.inputs["Roughness"].default_value = 0.38
    elif rbx_material == "Marble":
        bsdf.inputs["Roughness"].default_value = 0.2
    else:
        bsdf.inputs["Roughness"].default_value = 0.7
    if rbx_material == "Neon":
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = 7.0
    if rbx_material == "Glass":
        bsdf.inputs["Transmission Weight"].default_value = 0.9
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Alpha"].default_value = max(0.15, 1 - transparency)
    return mat


def to_blender(pos):
    x, y, z = pos
    return Vector((x, -z, y))


def angles(rx=0.0, ry=0.0, rz=0.0):
    """Roblox CFrame.Angles(rx, ry, rz) in degrees -> 3x3 matrix."""
    return (
        Matrix.Rotation(math.radians(rx), 3, "X")
        @ Matrix.Rotation(math.radians(ry), 3, "Y")
        @ Matrix.Rotation(math.radians(rz), 3, "Z")
    )


_unit_meshes = {}


def _unit_mesh(kind):
    mesh = _unit_meshes.get(kind)
    if mesh and mesh.name in bpy.data.meshes:
        return mesh
    if kind == "Block":
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.5, depth=1)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.5)
    obj = bpy.context.active_object
    mesh = obj.data
    mesh.name = "RBX_Unit" + kind
    if kind != "Block":
        for poly in mesh.polygons:
            poly.use_smooth = True
    bpy.data.objects.remove(obj)
    _unit_meshes[kind] = mesh
    return mesh


class Builder:
    """Creates Roblox-ready primitives inside a Blender collection."""

    def __init__(self, root_name, origin=(0, 0, 0)):
        self.root = bpy.data.collections.get(root_name) or bpy.data.collections.new(root_name)
        if self.root.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(self.root)
        self.origin = Vector(origin)
        self.folder = self.root
        self.count = 0

    def use_folder(self, name):
        full = self.root.name + "/" + name
        col = bpy.data.collections.get(full)
        if not col:
            col = bpy.data.collections.new(full)
            self.root.children.link(col)
        col["rbx_folder"] = name
        self.folder = col
        return col

    def _finish(self, obj, name, material, props):
        obj["rbx_name"] = name
        obj.data.materials.clear()
        obj.data.materials.append(get_material(material))
        obj.active_material = get_material(material)
        for key, value in props.items():
            if value is not None:
                obj["rbx_" + key] = value
        self.folder.objects.link(obj)
        self.count += 1
        return obj

    def _object(self, kind, name):
        mesh = _unit_mesh(kind).copy()
        mesh.materials.clear()
        obj = bpy.data.objects.new(name, mesh)
        obj["rbx_shape"] = kind
        return obj

    def block(self, name, size, pos, material, rot=None, **props):
        """size/pos are Roblox studs; rot is a Roblox rotation matrix (see angles())."""
        rot = rot or Matrix.Identity(3)
        obj = self._object("Block", name)
        world = Vector(pos) + self.origin
        rb = CT @ rot @ C
        obj.matrix_world = (
            Matrix.Translation(to_blender(world))
            @ rb.to_4x4()
            @ Matrix.Diagonal((size[0], size[2], size[1], 1))
        )
        return self._finish(obj, name, material, props)

    def cylinder(self, name, length, diameter, pos, material, axis="Y", rot=None, **props):
        """Cylinder whose axis follows the given Roblox axis (or rot's local X)."""
        if rot is None:
            rot = {"X": Matrix.Identity(3), "Y": angles(0, 0, 90), "Z": angles(0, -90, 0)}[axis]
        obj = self._object("Cylinder", name)
        world = Vector(pos) + self.origin
        rb = CT @ rot @ CYL_Q.transposed() @ C
        obj.matrix_world = (
            Matrix.Translation(to_blender(world))
            @ rb.to_4x4()
            @ Matrix.Diagonal((diameter, diameter, length, 1))
        )
        return self._finish(obj, name, material, props)

    def ball(self, name, diameter, pos, material, **props):
        obj = self._object("Ball", name)
        world = Vector(pos) + self.origin
        obj.matrix_world = Matrix.Translation(to_blender(world)) @ Matrix.Diagonal(
            (diameter, diameter, diameter, 1)
        )
        return self._finish(obj, name, material, props)

    # Composite helpers -------------------------------------------------

    def ring(self, name, center, radius, segments, thickness, height, material, y_rot=0.0, **props):
        """Horizontal ring made from short tangent blocks."""
        seg_len = 2 * math.pi * radius / segments * 1.04
        for i in range(segments):
            a = y_rot + 360.0 * i / segments
            ar = math.radians(a)
            p = (
                center[0] + math.cos(ar) * radius,
                center[1],
                center[2] - math.sin(ar) * radius,
            )
            self.block(name, (thickness, height, seg_len), p, material, rot=angles(0, a, 0), **props)

    def segment(self, name, a, b, width, height, material, y=None, **props):
        """Horizontal block running from Roblox XZ point a to b."""
        ax, az = a
        bx, bz = b
        length = math.hypot(bx - ax, bz - az)
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        mid = ((ax + bx) / 2, y if y is not None else height / 2, (az + bz) / 2)
        return self.block(name, (length, height, width), mid, material, rot=angles(0, yaw, 0), **props)
