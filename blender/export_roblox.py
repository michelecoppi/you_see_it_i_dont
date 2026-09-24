"""Export the Roblox map collections of blender/maps.blend to Luau layout modules.

Usage (either works):
    blender -b blender/maps.blend -P blender/export_roblox.py
    python3 blender/export_roblox.py            # with the `bpy` pip module

Each top-level collection listed in EXPORTS becomes a module in
src/server/MapLayouts. Objects need a mesh; their bounding box, transform,
material and ``rbx_*`` custom properties are converted to Roblox parts.
Supported custom properties on objects:
    rbx_name (str)          Roblox part name (defaults to the object name without .001 suffixes)
    rbx_shape (str)         Block | Cylinder | Ball (defaults to Block)
    rbx_collide (bool)      CanCollide, default True
    rbx_query (bool)        CanQuery/CanTouch for non-colliding parts, default False
    rbx_transparency (float)
    rbx_shadow (bool)       CastShadow, default: not Neon
    rbx_role (str)          GeometryRole attribute used by RoomGenerator validation
    rbx_light (str)         "Point:range:brightness" or "Surface:range:brightness:Face:angle"
    rbx_skip (bool)         Do not export (preview-only helpers)
Materials carry rbx_material (Enum.Material name), rbx_color ([r, g, b]) and rbx_transparency.
"""

import os
import re
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLEND = os.path.join(HERE, "maps.blend")
OUT_DIR = os.path.join(ROOT, "src", "server", "MapLayouts")
EXPORTS = {"Lobby": "LobbyLayout", "Expedition": "ExpeditionLayout"}

C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
CT = C.transposed()
CYL_Q = Matrix(((0, 1, 0), (1, 0, 0), (0, 0, -1)))


def fmt(value, digits=3):
    text = f"{value:.{digits}f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def clean_name(obj):
    if "rbx_name" in obj:
        return str(obj["rbx_name"])
    return re.sub(r"\.\d{3}$", "", obj.name)


def guess_shape(obj):
    if "rbx_shape" in obj:
        return str(obj["rbx_shape"])
    lowered = obj.name.lower()
    if "cylinder" in lowered:
        return "Cylinder"
    if "sphere" in lowered or "ball" in lowered:
        return "Ball"
    return "Block"


def object_folder(obj, root):
    for col in obj.users_collection:
        if col == root:
            return None
        if "rbx_folder" in col:
            return str(col["rbx_folder"])
        return col.name.split("/")[-1]
    return None


def walk(collection):
    for obj in collection.objects:
        yield obj
    for child in collection.children:
        yield from walk(child)


def export_part(obj, root, materials):
    if obj.type != "MESH" or obj.get("rbx_skip"):
        return None
    shape = guess_shape(obj)
    bb = [Vector(corner) for corner in obj.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    local_center = (lo + hi) / 2
    local_size = hi - lo

    world = obj.matrix_world
    loc, quat, scale = world.decompose()
    size_b = Vector((local_size.x * abs(scale.x), local_size.y * abs(scale.y), local_size.z * abs(scale.z)))
    center_b = world @ local_center
    pos = C @ center_b
    rot = C @ quat.to_matrix() @ CT
    if shape == "Cylinder":
        rot = rot @ CYL_Q
        size = (size_b.z, size_b.x, size_b.y)
    elif shape == "Ball":
        d = max(size_b)
        size = (d, d, d)
    else:
        size = (size_b.x, size_b.z, size_b.y)

    mat = obj.active_material
    key = mat.name if mat else "__default"
    if key not in materials:
        if mat and "rbx_material" in mat:
            materials[key] = (
                len(materials) + 1,
                str(mat["rbx_material"]),
                [int(v) for v in mat["rbx_color"]],
                float(mat.get("rbx_transparency", 0)),
            )
        else:
            rgb = [int(round(c * 255)) for c in (mat.diffuse_color[:3] if mat else (0.6, 0.6, 0.6))]
            materials[key] = (len(materials) + 1, "SmoothPlastic", rgb, 0.0)
    mat_index, rbx_material, _, mat_transparency = materials[key]

    fields = [f'N = "{clean_name(obj)}"']
    if shape != "Block":
        fields.append(f'S = "{shape}"')
    fields.append(f"M = {mat_index}")
    fields.append("Z = { " + ", ".join(fmt(v) for v in size) + " }")
    fields.append("P = { " + ", ".join(fmt(v) for v in pos) + " }")
    identity = all(abs(rot[i][j] - (1 if i == j else 0)) < 1e-6 for i in range(3) for j in range(3))
    if not identity:
        fields.append("R = { " + ", ".join(fmt(rot[i][j], 5) for i in range(3) for j in range(3)) + " }")
    if "rbx_collide" in obj and not obj["rbx_collide"]:
        fields.append("C = false")
        if obj.get("rbx_query"):
            fields.append("Q = true")
    transparency = float(obj.get("rbx_transparency", mat_transparency))
    if abs(transparency - mat_transparency) > 1e-6:
        fields.append(f"T = {fmt(transparency)}")
    if "rbx_shadow" in obj:
        default_shadow = rbx_material != "Neon"
        if bool(obj["rbx_shadow"]) != default_shadow:
            fields.append("D = " + ("true" if obj["rbx_shadow"] else "false"))
    if "rbx_role" in obj:
        fields.append(f'G = "{obj["rbx_role"]}"')
    if "rbx_light" in obj:
        fields.append(f'L = "{obj["rbx_light"]}"')
    folder = object_folder(obj, root)
    if folder:
        fields.append(f'F = "{folder}"')
    return "\t\t{ " + ", ".join(fields) + " },"


def export_collection(root_name, module_name):
    root = bpy.data.collections.get(root_name)
    if not root:
        print(f"[export] collection {root_name} not found, skipped")
        return
    materials = {}
    lines = []
    for obj in walk(root):
        line = export_part(obj, root, materials)
        if line:
            lines.append(line)

    out = [
        "-- stylua: ignore start",
        "-- AUTO-GENERATED by blender/export_roblox.py from blender/maps.blend. Do not edit by hand:",
        "-- change the Blender scene (or blender/generate_maps.py) and export again.",
        "-- N name, S shape, M material index, Z size, P position, R rotation matrix (row-major),",
        "-- C CanCollide, Q CanQuery/CanTouch, T transparency, D CastShadow, G GeometryRole, L light, F folder.",
        "return {",
        "\tMaterials = {",
    ]
    for _, (index, rbx_material, rgb, transparency) in sorted(materials.items(), key=lambda kv: kv[1][0]):
        out.append(
            f'\t\t{{ Material = "{rbx_material}", Color = {{ {rgb[0]}, {rgb[1]}, {rgb[2]} }}, '
            f"Transparency = {fmt(transparency)} }}, -- {index}"
        )
    out.append("\t},")
    out.append("\tParts = {")
    out.extend(lines)
    out.append("\t},")
    out.append("}")
    out.append("-- stylua: ignore end")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, module_name + ".luau")
    with open(path, "w", newline="\n") as handle:
        handle.write("\n".join(out) + "\n")
    print(f"[export] {root_name}: {len(lines)} parts, {len(materials)} materials -> {os.path.relpath(path, ROOT)}")


def main():
    if not bpy.data.filepath and os.path.exists(BLEND) and "--no-load" not in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    for root_name, module_name in EXPORTS.items():
        export_collection(root_name, module_name)


if __name__ == "__main__":
    main()
