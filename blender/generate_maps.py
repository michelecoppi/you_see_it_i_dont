"""Procedurally author the lobby and expedition lab in Blender and save blender/maps.blend.

Usage (either works):
    blender -b -P blender/generate_maps.py
    python3 blender/generate_maps.py            # with the `bpy` pip module

After running it you can open blender/maps.blend, move/add/remove objects by hand and run
blender/export_roblox.py to regenerate src/server/MapLayouts. Re-running this script
overwrites maps.blend, so commit manual edits before regenerating.

All coordinates below are Roblox studs (x, y, z); see rbx.py for the axis conversion.
Gameplay parts that need scripts (portals, consoles, boards, spawns, puzzle rooms) stay in
Luau. This scene only owns architecture, lighting fixtures and decoration, and it respects
the footprints used by RoomGenerator so the geometry validation keeps passing.
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbx  # noqa: E402
from rbx import Builder, angles  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BLEND = os.path.join(HERE, "maps.blend")

LOBBY_ORIGIN = (100, 0, 0)

# Shared with RoomGenerator.luau: keep in sync.
ROOM_CENTERS = (-45, -4, 37)
ROOM_ENDS = (-24, 17, 58)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rbx._unit_meshes.clear()


def point(range_, brightness):
    return f"Point:{range_}:{brightness}"


def surface(range_, brightness, face="Bottom", angle=90):
    return f"Surface:{range_}:{brightness}:{face}:{angle}"


# ---------------------------------------------------------------------------
# Lobby: Reality Expedition Hub
# ---------------------------------------------------------------------------

LW, LL, LH = 108, 94, 26  # interior width (x), length (z), wall height
HX, HZ = LW / 2, LL / 2  # 54, 47
CH = 10  # corner chamfer
HUB_Z = 18


def lobby_structure(b):
    b.use_folder("Structure")
    b.block("LobbyFloor", (LW + 4, 1, LL + 4), (0, 0, 0), "FloorSlate")

    # Main walls: solid lower wall, clerestory glass band, cornice.
    def wall(name, a, c, facing):
        length = math.hypot(c[0] - a[0], c[1] - a[1])
        b.segment(name, a, c, 1.2, 17, "WallPanel", y=8.5)
        b.segment(name + "Window", a, c, 0.6, 7, "Glass", y=20.5)
        b.segment(name + "Cornice", a, c, 1.4, 2, "WallDark", y=25)
        b.segment("LobbyWallBase", a, c, 1.6, 1.2, "TrimDark", y=0.9, collide=False)
        return length

    wall("BackWall", (-HX + CH, -HZ), (HX - CH, -HZ), 1)
    wall("FrontWall", (-HX + CH, HZ), (HX - CH, HZ), -1)
    wall("LeftWall", (-HX, -HZ + CH), (-HX, HZ - CH), 1)
    wall("RightWall", (HX, -HZ + CH), (HX, HZ - CH), -1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            wall("CornerWall", (sx * (HX - CH), sz * HZ), (sx * HX, sz * (HZ - CH)), 1)

    # Window mullions every ~9 studs around the clerestory.
    def mullions(a, c, count):
        for i in range(count + 1):
            t = i / count
            x = a[0] + (c[0] - a[0]) * t
            z = a[1] + (c[1] - a[1]) * t
            b.block("WindowMullion", (0.9, 7, 0.9), (x, 20.5, z), "Trim", collide=False)

    mullions((-HX + CH, -HZ), (HX - CH, -HZ), 10)
    mullions((-HX + CH, HZ), (HX - CH, HZ), 10)
    mullions((-HX, -HZ + CH), (-HX, HZ - CH), 8)
    mullions((HX, -HZ + CH), (HX, HZ - CH), 8)

    # Ceiling with a raised glass lantern above the hub core.
    top = LH + 0.5
    open_w, open_front, open_back = 30, HUB_Z + 14, HUB_Z - 14
    b.block("LobbyCeiling", (LW + 2, 1, open_back + HZ + 1), (0, top, (open_back - HZ - 1) / 2), "Ceiling")
    b.block("LobbyCeiling", (LW + 2, 1, HZ + 1 - open_front), (0, top, (open_front + HZ + 1) / 2), "Ceiling")
    side_w = (LW + 2 - open_w) / 2
    for sx in (-1, 1):
        b.block(
            "LobbyCeiling",
            (side_w, 1, open_front - open_back),
            (sx * (open_w / 2 + side_w / 2), top, HUB_Z),
            "Ceiling",
        )
    lantern_h = 6
    for sx in (-1, 1):
        b.block("LanternGlass", (0.5, lantern_h, 28), (sx * 15, top + lantern_h / 2, HUB_Z), "Glass")
        b.block("LanternGlass", (30, lantern_h, 0.5), (0, top + lantern_h / 2, HUB_Z + sx * 14), "Glass")
    b.block("LanternRoof", (31, 0.6, 29), (0, top + lantern_h + 0.3, HUB_Z), "GlassTint")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.block("LanternPost", (1, lantern_h + 1, 1), (sx * 15, top + lantern_h / 2, HUB_Z + sz * 14), "Trim")
    for i in range(-2, 3):
        b.block("LanternRib", (0.6, 0.6, 29), (i * 6, top + lantern_h, HUB_Z), "Trim", collide=False)

    # Coffered ceiling beams and pilasters give the hall a readable rhythm.
    b.use_folder("Detail")
    for x in (-42, -30, 30, 42):
        b.block("CeilingBeam", (1.4, 1.6, LL - 2), (x, LH - 0.8, 0), "WallDark", collide=False)
    for z in (-36, -24, -12, 36):
        b.block("CeilingBeam", (LW - 2, 1.6, 1.4), (0, LH - 0.8, z), "WallDark", collide=False)

    for x in (-42, -30, 30, 42):
        for sz in (-1, 1):
            z = sz * (HZ - 0.9)
            b.block("Pilaster", (2.2, 17, 1.2), (x, 8.5, z), "Trim")
            b.block("PilasterCap", (2.8, 0.6, 1.6), (x, 17.2, z), "WallDark", collide=False)
    for sx in (-1, 1):
        for z in (9, 21, 33):
            x = sx * (HX - 0.9)
            b.block("Pilaster", (1.2, 17, 2.2), (x, 8.5, z), "Trim")
            b.block("PilasterCap", (1.6, 0.6, 2.8), (x, 17.2, z), "WallDark", collide=False)

    # Mezzanine ledge that wraps the hall under the windows.
    for sx in (-1, 1):
        b.block("Ledge", (3, 0.7, LL - 2 * CH), (sx * (HX - 1.5), 17.35, 0), "WallDark", collide=False)
        b.block("LedgeRail", (0.3, 1.2, LL - 2 * CH), (sx * (HX - 3), 18.3, 0), "Trim", collide=False)
    for sz in (-1, 1):
        b.block("Ledge", (LW - 2 * CH, 0.7, 3), (0, 17.35, sz * (HZ - 1.5)), "WallDark", collide=False)
        b.block("LedgeRail", (LW - 2 * CH, 1.2, 0.3), (0, 18.3, sz * (HZ - 3)), "Trim", collide=False)

    # Wall accents recoloured at runtime by the Reality Mixer (name must stay LobbyWallAccent).
    for sx in (-1, 1):
        b.block(
            "LobbyWallAccent", (0.2, 0.35, LL - 2 * CH), (sx * (HX - 0.7), 16.7, 0), "NeonCyan", collide=False
        )
    for sz in (-1, 1):
        b.block(
            "LobbyWallAccent", (LW - 2 * CH, 0.35, 0.2), (0, 16.7, sz * (HZ - 0.7)), "NeonViolet", collide=False
        )


def lobby_floor(b):
    b.use_folder("Floor")
    # Promenade from the spawn to the portals.
    b.block("Promenade", (30, 0.1, 76), (0, 0.55, 2), "FloorTile", collide=False)
    for sx in (-1, 1):
        b.block("PromenadeEdge", (0.4, 0.12, 76), (sx * 15.2, 0.57, 2), "NeonMint", collide=False)
        b.block("PromenadeKerb", (1.2, 0.14, 76), (sx * 16.2, 0.56, 2), "TrimDark", collide=False)
    for z in range(-34, 40, 6):
        b.block("PromenadeSeam", (29.6, 0.12, 0.18), (0, 0.56, z), "FloorSeam", collide=False)

    # Floor seams across the rest of the hall.
    for x in (-42, -30, 30, 42):
        b.block("FloorSeam", (0.25, 0.08, LL - 4), (x, 0.53, 0), "FloorSeam", collide=False)
    for z in (-36, -24, -12, 0, 12, 24, 36):
        for sx in (-1, 1):
            b.block("FloorSeam", (35, 0.08, 0.25), (sx * 34.5, 0.53, z), "FloorSeam", collide=False)

    # Hub plaza: marble disc with a glowing ring around the hub core.
    b.cylinder("HubPlaza", 0.12, 31, (0, 0.58, HUB_Z), "Marble", axis="Y", collide=False)
    b.cylinder("HubPlazaInner", 0.14, 14, (0, 0.6, HUB_Z), "FloorPlate", axis="Y", collide=False)
    b.ring("FloorRing", (0, 0.66, HUB_Z), 15.3, 40, 0.45, 0.1, "NeonCyan", collide=False)
    b.ring("FloorRing", (0, 0.68, HUB_Z), 7.4, 24, 0.3, 0.1, "NeonViolet", collide=False)
    for i in range(8):
        a = i * 45 + 22.5
        ar = math.radians(a)
        p = (math.cos(ar) * 11.3, 0.67, HUB_Z - math.sin(ar) * 11.3)
        b.block("PlazaSpoke", (7, 0.08, 0.3), p, "FloorSeam", rot=angles(0, a, 0), collide=False)

    # Guides from the plaza to the two portals.
    for sx in (-1, 1):
        mat = "NeonMint" if sx < 0 else "NeonBlue"
        b.block("PortalRoute", (0.3, 0.08, 26), (sx * 17, 0.58, -10), mat, collide=False)
        for z in (-20, -12, -4, 4):
            b.block("RouteMarker", (3.2, 0.08, 0.26), (sx * 17, 0.59, z), mat, collide=False)

    # Spawn apron.
    b.block("SpawnApron", (16, 0.12, 12), (0, 0.6, 38), "FloorPlate", collide=False)
    b.block("SpawnApronEdge", (16.6, 0.1, 12.6), (0, 0.57, 38), "NeonMint", collide=False)


def lobby_columns(b):
    b.use_folder("Columns")
    for sx in (-1, 1):
        for z in (0, 36):
            x = sx * 24
            b.block("ColumnBase", (4.4, 1.2, 4.4), (x, 1.1, z), "WallDark")
            b.block("SupportColumn", (2.8, LH - 1.5, 2.8), (x, (LH - 1.5) / 2 + 1, z), "Trim")
            b.block("ColumnCapital", (4, 1, 4), (x, LH - 1, z), "WallDark", collide=False)
            for y in (6, 12.5):
                b.block("ColumnGlow", (3.05, 0.35, 3.05), (x, y, z), "NeonViolet", collide=False)
            b.block(
                "ColumnUplight",
                (2, 0.2, 2),
                (x, LH - 1.6, z),
                "NeonWhite",
                collide=False,
                light=point(20, 0.9),
            )


def lobby_lights(b):
    b.use_folder("Lighting")
    # Runtime-recoloured strips (name must stay CeilingLightStrip).
    for sx in (-1, 1):
        for z0, z1 in ((-44, -14), (-10, 4), (34, 44)):
            length = z1 - z0
            b.block(
                "CeilingLightStrip",
                (3, 0.25, length),
                (sx * 36, LH - 0.2, (z0 + z1) / 2),
                "NeonBlue",
                collide=False,
                light=surface(28, 1.1, "Bottom", 100),
            )
    # Frame of light around the lantern opening.
    for sx in (-1, 1):
        b.block("CeilingLightStrip", (0.8, 0.25, 29.6), (sx * 15.8, LH - 0.1, HUB_Z), "NeonCyan", collide=False)
        b.block("CeilingLightStrip", (32.4, 0.25, 0.8), (0, LH - 0.1, HUB_Z + sx * 14.8), "NeonCyan", collide=False)
    for z in (-38, -26, -14):
        b.block(
            "CeilingLightStrip",
            (20, 0.25, 1.4),
            (0, LH - 0.2, z),
            "NeonCyan",
            collide=False,
            light=surface(26, 1, "Bottom", 110),
        )
    # Soft fill lights so the hall does not depend on bloom alone.
    for x in (-40, 40):
        for z in (-30, 0, 30):
            b.block(
                "FillLight",
                (0.8, 0.8, 0.8),
                (x, 14, z),
                "NeonWhite",
                collide=False,
                transparency=1,
                light=point(32, 0.7),
            )


def lobby_centerpiece(b):
    b.use_folder("RealityPrism")
    y = 17.5
    b.cylinder("PrismMount", 6, 0.35, (0, LH - 3, HUB_Z), "Trim", axis="Y", collide=False)
    b.ring("PrismHalo", (0, y, HUB_Z), 6.2, 28, 0.35, 0.35, "NeonViolet", collide=False)
    b.ring("PrismHalo", (0, y - 0.9, HUB_Z), 4.7, 24, 0.3, 0.3, "NeonCyan", collide=False, y_rot=7)
    b.block(
        "RealityPrism",
        (3, 3, 3),
        (0, y, HUB_Z),
        "GlassTint",
        rot=angles(45, 35, 0),
        collide=False,
        light=point(24, 1.6),
    )
    b.block("RealityPrismCore", (1.6, 1.6, 1.6), (0, y, HUB_Z), "NeonCyan", rot=angles(20, 0, 45), collide=False)
    for i in range(6):
        a = i * 60
        ar = math.radians(a)
        p = (math.cos(ar) * 3.4, y + (0.9 if i % 2 else -0.9), HUB_Z - math.sin(ar) * 3.4)
        b.block("PrismShard", (0.5, 1.4, 0.5), p, "NeonViolet" if i % 2 else "NeonMint", rot=angles(20, a, 30), collide=False)


def lobby_backdrop(b):
    b.use_folder("RiftMural")
    # Monumental frame between the two expedition portals.
    z = -HZ + 0.9
    b.block("RiftFrame", (14, 20, 1), (0, 10.5, z), "WallDark")
    b.block("RiftPanel", (11, 16.5, 0.3), (0, 10.5, z + 0.6), "GlassTint", collide=False)
    for i, (dx, height, mat) in enumerate(((-3, 12, "NeonViolet"), (0, 15, "NeonCyan"), (3, 11, "NeonMint"))):
        b.block("RiftLine", (0.35, height, 0.2), (dx, 10.5, z + 0.8), mat, rot=angles(0, 0, 18 - i * 18), collide=False)
    b.block("RiftCrown", (16, 1, 1.6), (0, 21, z + 0.2), "Trim", collide=False)
    b.block("RiftGlow", (14, 0.3, 0.3), (0, 20.3, z + 0.9), "NeonViolet", collide=False, light=point(18, 1.2))
    # Frames behind the portals so they read as gates set into the wall.
    for sx in (-1, 1):
        x = sx * 17
        b.block("PortalBackdrop", (18, 18, 0.6), (x, 9.5, z + 0.3), "WallDark", collide=False)
        b.block("PortalBackdropTrim", (18.6, 0.4, 0.4), (x, 18.7, z + 0.6), "NeonBlue" if sx > 0 else "NeonMint", collide=False)


def lobby_entrance(b):
    b.use_folder("Entrance")
    z = HZ - 0.8
    # Stays below LobbyBuilder's header sign (y = 8..15).
    b.block("EntranceFrame", (16, 7.4, 1.2), (0, 4.2, z), "WallDark")
    b.block("EntranceDoor", (6.6, 6.2, 0.4), (-3.4, 3.7, z - 0.7), "GlassTint")
    b.block("EntranceDoor", (6.6, 6.2, 0.4), (3.4, 3.7, z - 0.7), "GlassTint")
    b.block("EntranceGlow", (14, 0.3, 0.3), (0, 7.3, z - 0.9), "NeonMint", collide=False, light=point(16, 1))


def tree(b, x, z, scale=1.0, tint="Foliage"):
    b.cylinder("PlanterTrunk", 7 * scale, 0.9 * scale, (x, 1.6 + 3.5 * scale, z), "Bark", axis="Y")
    b.ball("PlanterFoliage", 5.5 * scale, (x, 1.6 + 7.6 * scale, z), tint, collide=False)
    b.ball("PlanterFoliage", 4 * scale, (x + 1.8 * scale, 1.6 + 6.3 * scale, z + 0.8 * scale), "FoliageDeep", collide=False)
    b.ball("PlanterFoliage", 3.6 * scale, (x - 1.6 * scale, 1.6 + 6.8 * scale, z - 1.2 * scale), tint, collide=False)
    b.ball("PlanterBloom", 0.7, (x + 0.6, 1.6 + 9.4 * scale, z + 1.4), "NeonPink", collide=False)
    b.ball("PlanterBloom", 0.6, (x - 1.9, 1.6 + 7.9 * scale, z - 0.3), "NeonMint", collide=False)


def lobby_decor(b):
    b.use_folder("Planters")
    for sx in (-1, 1):
        for z in (-36, 36):
            x = sx * 40
            b.block("PlanterBox", (8, 1.6, 8), (x, 1.3, z), "WallDark")
            b.block("PlanterRim", (8.6, 0.3, 8.6), (x, 2.2, z), "Trim", collide=False)
            b.block("PlanterSoil", (7.2, 0.2, 7.2), (x, 2.15, z), "Grass", collide=False)
            tree(b, x, z, 1.0 if z < 0 else 0.85, "Foliage" if sx < 0 else "FoliageDeep")

    b.use_folder("Seating")
    for sx in (-1, 1):
        for z in (12, 24):
            x = sx * 29
            yaw = 90 if sx < 0 else -90
            rot = angles(0, yaw, 0)
            b.block("BenchSeat", (6, 0.5, 2), (x, 1.6, z), "Fabric", rot=rot)
            b.block("BenchFrame", (6.2, 0.3, 2.2), (x, 1.25, z), "TrimDark", rot=rot)
            for dz in (-2.4, 2.4):
                b.block("BenchLeg", (0.4, 1, 1.8), (x, 0.9, z + dz), "TrimDark")
            back_x = x + (-0.9 if sx < 0 else 0.9)
            b.block("BenchBack", (6, 1.4, 0.35), (back_x, 2.5, z), "Fabric", rot=rot)
            b.block("BenchGlow", (5.6, 0.12, 0.12), (x, 1.1, z), "NeonCyan", rot=rot, collide=False)

    b.use_folder("Crates")
    for x, z, s, yaw in ((47, 40, 2.6, 12), (44.2, 41.5, 2, -8), (47.5, -40, 2.4, 25), (45, 28, 1.8, 0)):
        b.block("SupplyCrate", (s, s, s), (x, 0.5 + s / 2, z), "WoodTrim", rot=angles(0, yaw, 0))
        b.block("CrateBand", (s + 0.08, 0.25, s + 0.08), (x, 0.5 + s * 0.7, z), "TrimDark", rot=angles(0, yaw, 0), collide=False)


def lobby_exterior(b):
    b.use_folder("Exterior")
    # Distant facility towers seen through the clerestory windows. Kept beyond x=165 / |z|>70
    # so they never overlap the expedition lab.
    towers = (
        (190, -40, 70, 18),
        (215, 20, 95, 22),
        (185, 60, 55, 14),
        (60, -120, 80, 20),
        (140, -130, 60, 16),
        (40, 125, 75, 18),
        (160, 120, 88, 20),
        (235, -95, 110, 26),
    )
    for x, z, h, w in towers:
        lx, lz = x - LOBBY_ORIGIN[0], z
        b.block("ExteriorTower", (w, h, w), (lx, h / 2 - 20, lz), "RockDark", collide=False)
        b.block("ExteriorTowerCap", (w + 2, 2, w + 2), (lx, h - 19, lz), "WallDark", collide=False)
        b.block("ExteriorBeacon", (w * 0.6, 0.5, 0.5), (lx, h - 17.6, lz), "NeonViolet", collide=False)
        for i in range(3):
            y = 5 + i * (h - 30) / 3
            b.block("ExteriorWindowBand", (w + 0.2, 0.8, w + 0.2), (lx, y, lz), "NeonBlue", collide=False, transparency=0.2)
    for i, (x, z, s) in enumerate(((200, -10, 14), (175, 95, 10), (95, -150, 12), (230, 60, 9))):
        lx = x - LOBBY_ORIGIN[0]
        b.block("FloatingRock", (s, s * 0.6, s * 0.8), (lx, 38 + i * 6, z), "Rock", rot=angles(8, i * 37, 12), collide=False)
        b.block("FloatingRockGlow", (s * 0.5, 0.3, s * 0.4), (lx, 38 + i * 6 - s * 0.32, z), "NeonCyan", rot=angles(8, i * 37, 12), collide=False)


def build_lobby():
    b = Builder("Lobby", origin=LOBBY_ORIGIN)
    lobby_structure(b)
    lobby_floor(b)
    lobby_columns(b)
    lobby_lights(b)
    lobby_centerpiece(b)
    lobby_backdrop(b)
    lobby_entrance(b)
    lobby_decor(b)
    lobby_exterior(b)
    return b.count


# ---------------------------------------------------------------------------
# Expedition lab
# ---------------------------------------------------------------------------

EW, EL = 68, 150
EZ0, EZ1 = -68, 82  # interior z range
ECZ = 7
EH = 18
# Wall ribs/trusses avoid the wall displays and ceiling projectors RoomGenerator adds per chamber.
RIB_Z = (-66, -41, -33, -25.5, 0, 8, 15.5, 41, 49, 56.5, 62, 70, 78)


def expedition_structure(b):
    b.use_folder("Shell")
    # Same collision footprint as the original shell: RoomGenerator gates depend on it.
    b.block("Floor", (EW, 1, EL), (0, 0, ECZ), "FloorSlate", role="Support")
    for sx, name in ((-1, "LeftWall"), (1, "RightWall")):
        x = sx * 34.5
        b.block(name, (1, 13.5, EL), (x, 6.75, ECZ), "WallPanel")
        b.block(name + "Window", (1, 3, EL), (x, 15, ECZ), "Glass")
        b.block(name + "Top", (1, 1.5, EL), (x, 17.25, ECZ), "WallDark")
    b.block("BackWall", (EW, 18, 1), (0, 9, -68.5), "WallPanel")
    b.block("FrontWall", (EW, 18, 1), (0, 9, 82.5), "WallPanel")
    b.block("Ceiling", (EW, 1, EL), (0, 18, ECZ), "Ceiling")

    b.use_folder("Walls")
    for sx in (-1, 1):
        x = sx * 33.85
        b.block("WallKick", (0.3, 2.4, EL - 0.2), (x, 1.7, ECZ), "WallDark", collide=False)
        b.block("WallAccent", (0.16, 0.3, EL - 0.2), (sx * 33.92, 13.3, ECZ), "NeonCyan", collide=False)
        b.block("WallAccent", (0.16, 0.22, EL - 0.2), (sx * 33.92, 2.95, ECZ), "NeonViolet", collide=False)
        for z in RIB_Z:
            b.block("WallRib", (0.5, 16.5, 1.4), (sx * 33.75, 8.75, z), "Trim", collide=False)
            b.block("WallRibLight", (0.12, 3, 0.4), (sx * 33.46, 9.5, z), "NeonWhite", collide=False)
        # Window mullions every 6 studs.
        for z in range(EZ0 + 3, EZ1, 6):
            b.block("WindowMullion", (1.3, 3, 0.5), (sx * 34.5, 15, z), "Trim", collide=False)

    b.use_folder("Ceiling")
    for z in RIB_Z:
        b.block("CeilingTruss", (EW - 0.2, 0.8, 1), (0, 17.1, z), "WallDark", collide=False)
    for sx in (-1, 1):
        b.block("CeilingRail", (1.2, 0.6, EL - 0.4), (sx * 26, 17.2, ECZ), "WallDark", collide=False)
        b.block("CeilingRail", (0.8, 0.5, EL - 0.4), (sx * 13, 17.25, ECZ), "TrimDark", collide=False)


def expedition_lights(b):
    b.use_folder("Lighting")
    # Ceiling light coves between trusses, alternating cyan/violet per chamber.
    stops = sorted(set(RIB_Z) | {EZ0, EZ1})
    for i in range(len(stops) - 1):
        z0, z1 = stops[i] + 0.7, stops[i + 1] - 0.7
        if z1 - z0 < 2:
            continue
        mat = "NeonCyan" if i % 2 == 0 else "NeonViolet"
        for sx in (-1, 1):
            b.block(
                "CeilingStrip",
                (0.7, 0.2, z1 - z0),
                (sx * 26, 16.82, (z0 + z1) / 2),
                mat,
                collide=False,
                light=surface(24, 1.05, "Bottom", 85),
            )
    for z in (-54, -12, 29, 70):
        b.block(
            "CeilingFill",
            (0.6, 0.6, 0.6),
            (0, 15.5, z),
            "NeonWhite",
            collide=False,
            transparency=1,
            light=point(30, 0.55),
        )


def expedition_airlock(b):
    b.use_folder("Airlock")
    # Sits behind MapBuilder's InstructionBoard (z = -67.8) so the board stays readable.
    b.block("AirlockFrame", (24, 12, 0.2), (0, 7.4, -67.9), "WallDark", collide=False)
    b.block("AirlockFrameTrim", (24.6, 0.35, 0.3), (0, 13.5, -67.45), "NeonMint", collide=False)
    for sx in (-1, 1):
        b.block("AirlockPillar", (1.6, 16, 1.6), (sx * 13.5, 8.5, -67.1), "Trim", collide=False)
        b.block(
            "AirlockPillarGlow",
            (0.3, 12, 0.3),
            (sx * 13.5, 8.5, -66.25),
            "NeonMint",
            collide=False,
            light=point(14, 0.9),
        )
        b.block("AirlockHazard", (5, 0.08, 1.2), (sx * 7, 0.54, -66.5), "NeonOrange", collide=False)
    b.block("AirlockFloorTrim", (20, 0.08, 0.4), (0, 0.54, -67.4), "NeonMint", collide=False)


def expedition_gates(b):
    b.use_folder("GateFrames")
    # Decorative lintels above each chamber gate (the collidable gate walls come from RoomGenerator).
    for i, z in enumerate(ROOM_ENDS):
        mat = "NeonViolet" if (i + 1) % 2 == 1 else "NeonBlue"
        for dz in (-0.95, 0.95):
            b.block("GateLintel", (20, 1, 0.5), (0, 16.9, z + dz), "WallDark", collide=False)
            b.block("GateLintelGlow", (18, 0.2, 0.12), (0, 16.3, z + dz * 1.32), mat, collide=False)
        for dz in (-3.5, 3.5):
            b.block("GateFloorStripe", (18, 0.06, 0.35), (0, 0.53, z + dz), mat, collide=False)


def expedition_extraction(b):
    b.use_folder("ExtractionBay")
    cz = 71
    b.ring("ExtractionRing", (0, 0.53, cz), 12.5, 36, 0.5, 0.06, "NeonCyan", collide=False)
    b.ring("ExtractionHalo", (0, 15.2, cz), 9.5, 32, 0.45, 0.45, "NeonCyan", collide=False)
    b.ring("ExtractionHalo", (0, 14.2, cz), 7, 28, 0.35, 0.35, "NeonMint", collide=False, y_rot=5)
    for sx in (-1, 1):
        for dz in (-8, 8):
            x, z = sx * 14.5, cz + dz
            b.block("ExtractionPylon", (1.6, 12, 1.6), (x, 6.5, z), "Trim")
            b.block("ExtractionPylonCap", (2.2, 0.6, 2.2), (x, 12.8, z), "WallDark", collide=False)
            b.block("ExtractionPylonGlow", (0.3, 9, 0.3), (x - sx * 0.85, 6.5, z), "NeonCyan", collide=False)
    for i in range(4):
        a = 45 + i * 90
        ar = math.radians(a)
        x, z = math.cos(ar) * 9.5, cz - math.sin(ar) * 9.5
        b.block("HaloCable", (0.12, 2.8, 0.12), (x, 16.6, z), "TrimDark", collide=False)
    b.block("ExtractionBeam", (0.8, 0.8, 0.8), (0, 13.5, cz), "NeonWhite", collide=False, transparency=1, light=point(26, 1.4))
    # Exit window above the final wall.
    b.block("ExitWindowFrame", (30, 7, 0.4), (0, 11.5, 81.8), "WallDark", collide=False)
    b.block("ExitWindow", (27, 5, 0.2), (0, 11.5, 81.55), "GlassTint", collide=False)
    b.block("ExitWindowGlow", (27, 0.25, 0.2), (0, 8.8, 81.5), "NeonCyan", collide=False)


def expedition_exterior(b):
    b.use_folder("Exterior")
    # Only on the -X side so the lobby (x = 46..154) never overlaps the lab's surroundings.
    for i, (x, z, h, w) in enumerate(
        ((-70, -40, 60, 16), (-95, 10, 85, 22), (-65, 55, 50, 14), (-120, -70, 100, 24), (-110, 90, 70, 18))
    ):
        b.block("ExteriorTower", (w, h, w), (x, h / 2 - 20, z), "RockDark", collide=False)
        b.block("ExteriorTowerCap", (w + 2, 2, w + 2), (x, h - 19, z), "WallDark", collide=False)
        b.block("ExteriorBeacon", (0.5, 0.5, w * 0.6), (x + w / 2 + 0.1, h - 17.6, z), "NeonCyan", collide=False)
        for j in range(3):
            y = 5 + j * (h - 30) / 3
            b.block("ExteriorWindowBand", (w + 0.2, 0.8, w + 0.2), (x, y, z), "NeonViolet" if i % 2 else "NeonBlue", collide=False, transparency=0.2)
    b.block("ExteriorWalkway", (10, 1, 180), (-46, -0.5, 7), "WallDark", collide=False)
    b.block("ExteriorWalkwayGlow", (0.3, 0.2, 180), (-41.2, 0.1, 7), "NeonViolet", collide=False)


def build_expedition():
    b = Builder("Expedition")
    expedition_structure(b)
    expedition_lights(b)
    expedition_airlock(b)
    expedition_gates(b)
    expedition_extraction(b)
    expedition_exterior(b)
    return b.count


# ---------------------------------------------------------------------------
# Reference proxies for parts built in Luau (never exported, see rbx_skip)
# ---------------------------------------------------------------------------


def build_reference():
    """Ghost boxes showing where scripted gameplay parts sit, so manual edits avoid them."""
    b = Builder("Reference (code-built, not exported)")
    lobby = [
        ("SoloPortal", (14, 12, 2), (-17, 6, -31), "NeonMint"),
        ("GroupPortal", (14, 12, 2), (17, 6, -31), "NeonBlue"),
        ("PortalPads", (13, 0.5, 8), (-17, 0.5, -28), "NeonMint"),
        ("PortalPads", (13, 0.5, 8), (17, 0.5, -28), "NeonBlue"),
        ("PortalSigns", (12, 3.8, 0.4), (-17, 14, -31), "WallLight"),
        ("PortalSigns", (12, 3.8, 0.4), (17, 14, -31), "WallLight"),
        ("GroupQueueBoard", (17, 5, 0.5), (17, 7.5, -18), "WallLight"),
        ("QueueSpots", (11, 0.2, 15), (17, 0.84, -16), "NeonBlue"),
        ("SuccessfulEscapesBoard", (1.2, 15.5, 44), (-53.8, 8.7, -15), "WallLight"),
        ("FailedEscapesBoard", (1.2, 15.5, 44), (53.8, 8.7, -15), "WallLight"),
        ("DailyReactor", (9, 9, 7), (-42, 4.5, 24), "NeonOrange"),
        ("RealityMixer", (13, 7, 7), (-42, 3.5, 2), "WallLight"),
        ("BriefingTerminal", (11, 8, 7), (42, 4, 2), "NeonBlue"),
        ("HubCore", (9, 1, 9), (0, 1.12, 18), "NeonCyan"),
        ("LobbySpawn", (10, 1, 10), (0, 1, 38), "NeonMint"),
        ("LobbyHeader", (48, 7, 0.6), (0, 11.5, 46.4), "WallLight"),
    ]
    for name, size, pos, mat in lobby:
        p = (pos[0] + LOBBY_ORIGIN[0], pos[1], pos[2])
        obj = b.block(name, size, p, mat, skip=True)
        obj.display_type = "WIRE"
    for i, cz in enumerate(ROOM_CENTERS):
        obj = b.block("ChamberDeck_" + str(i + 1), (61, 0.16, 36), (0, 0.59, cz), "FloorPlate", skip=True)
        obj.display_type = "WIRE"
        obj = b.block("PuzzleConsoles", (40, 5, 8), (0, 2.5, cz + 8), "WallLight", skip=True)
        obj.display_type = "WIRE"
    for z in ROOM_ENDS:
        obj = b.block("GateWalls", (68, 18, 1.2), (0, 9, z), "WallLight", skip=True)
        obj.display_type = "WIRE"
    for name, size, pos in (
        ("ExtractionPad", (18, 1, 16), (0, 1, 71)),
        ("RoundSpawn", (8, 1, 8), (0, 1, -63)),
        ("InstructionBoard", (18, 8, 0.5), (0, 7, -67.8)),
    ):
        obj = b.block(name, size, pos, "NeonCyan", skip=True)
        obj.display_type = "WIRE"
    b.root.hide_render = True
    return b.count


def main():
    reset_scene()
    lobby_count = build_lobby()
    expedition_count = build_expedition()
    build_reference()
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    print(f"[generate] lobby={lobby_count} parts, expedition={expedition_count} parts -> {BLEND}")


if __name__ == "__main__":
    main()
