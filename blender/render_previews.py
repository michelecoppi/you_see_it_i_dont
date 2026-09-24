"""Render preview images of blender/maps.blend with Cycles (CPU, works headless).

Usage:
    blender -b blender/maps.blend -P blender/render_previews.py
    python3 blender/render_previews.py [--quick]
Images are written to docs/images/blender/.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rbx import to_blender  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLEND = os.path.join(HERE, "maps.blend")
OUT = os.path.join(ROOT, "docs", "images", "blender")
QUICK = "--quick" in sys.argv

# name: (camera position, look-at target, lens mm, hide roofs)  -- Roblox coordinates
VIEWS = {
    "lobby_overview": ((100 + 70, 95, 80), (100, 0, 2), 28, True),
    "lobby_interior": ((100, 7, 44), (100, 8, -30), 18, False),
    "lobby_portals": ((100 + 22, 6, 6), (100 - 6, 7, -38), 20, False),
    "expedition_overview": ((95, 110, -30), (0, 0, 10), 30, True),
    "expedition_interior": ((0, 6, -64), (0, 7, 20), 18, False),
    "expedition_extraction": ((-20, 9, 48), (4, 5, 78), 20, False),
}
ROOF_NAMES = {
    "LobbyCeiling", "LanternGlass", "LanternRoof", "LanternPost", "LanternRib", "CeilingBeam",
    "Ceiling", "CeilingTruss", "CeilingRail", "CeilingStrip", "LobbyWallAccent",
    "BackWallWindow", "FrontWallWindow", "LeftWallWindow", "RightWallWindow", "CornerWallWindow",
    "BackWallCornice", "FrontWallCornice", "LeftWallCornice", "RightWallCornice", "CornerWallCornice",
    "LeftWallTop", "RightWallTop", "WindowMullion", "Ledge", "LedgeRail", "PrismMount",
    "ColumnCapital", "ColumnUplight", "CeilingLightStrip", "HaloCable",
}


def setup_world(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16 if QUICK else 96
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x = 960 if QUICK else 1600
    scene.render.resolution_y = 540 if QUICK else 900
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("RBX_Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.11, 0.17, 0.27, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("RBX_Sun", bpy.data.lights.new("RBX_Sun", "SUN"))
    sun.data.energy = 2.2
    sun.data.color = (0.85, 0.92, 1.0)
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)


def add_game_lights(scene):
    """Mirror Roblox PointLights/SurfaceLights as Blender lamps so previews match the lighting."""
    for obj in list(scene.objects):
        spec = obj.get("rbx_light")
        if not spec or obj.type != "MESH":
            continue
        kind, rng, brightness = spec.split(":")[:3]
        color = obj.active_material.diffuse_color[:3] if obj.active_material else (1, 1, 1)
        lamp = bpy.data.lights.new("RBX_Lamp", "AREA" if kind == "Surface" else "POINT")
        lamp.color = color
        lamp.energy = float(brightness) * float(rng) * (22 if kind == "Surface" else 45)
        if kind == "Surface":
            lamp.size = max(obj.dimensions.x, 1)
            lamp.size_y = max(obj.dimensions.y, 1)
            lamp.shape = "RECTANGLE"
        lamp_obj = bpy.data.objects.new("RBX_Lamp", lamp)
        lamp_obj.matrix_world = obj.matrix_world.normalized()
        lamp_obj.location = obj.matrix_world.translation + Vector((0, 0, -0.3 if kind == "Surface" else 0))
        if kind != "Surface":
            lamp_obj.rotation_euler = (0, 0, 0)
        else:
            lamp_obj.rotation_euler = (math.pi, 0, obj.matrix_world.to_euler().z)
        scene.collection.objects.link(lamp_obj)


def aim(cam, target):
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render():
    if not bpy.data.filepath and os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    setup_world(scene)
    add_game_lights(scene)
    cam = bpy.data.objects.new("RBX_Camera", bpy.data.cameras.new("RBX_Camera"))
    cam.data.clip_end = 2000
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(OUT, exist_ok=True)
    only = [a for a in sys.argv if a in VIEWS]
    for name, (position, target, lens, hide_roof) in VIEWS.items():
        if only and name not in only:
            continue
        for obj in scene.objects:
            if obj.type == "MESH":
                hidden = hide_roof and obj.get("rbx_name") in ROOF_NAMES
                obj.hide_render = hidden
        cam.location = to_blender(position)
        cam.data.lens = lens
        aim(cam, to_blender(target))
        scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("[render]", os.path.relpath(scene.render.filepath, ROOT))


if __name__ == "__main__":
    render()
