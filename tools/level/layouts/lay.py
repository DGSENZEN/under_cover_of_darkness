"""Helpers for writing a layout (tools/level/layouts/<level>.py): runs of
wall with openings, floors filled with tiles, flights of stairs, markers.
Everything in Godot's axes (x east, y up, z south), metres.

A Layout collects pieces and markers; layout() returns layout.data().
"""

import math

import geo
import kit_recipes as kit


class Layout:
    def __init__(self, level):
        self.level = level
        self.pieces = []
        self.markers = []
        self.ground = []
        self._count = {}

    # Pieces

    def put(self, piece, at, yaw=0.0, sector="courtyard", pitch=0.0, roll=0.0, name=None, climbs=False, loose=0.0):
        """A piece; with `climbs`, a ladder marker for each of its recipe's
        climbs (a ship's shrouds, a scaffold's ladders), named after it;
        `loose` (kg), a loose thing: a "loose" marker naming it, so it is a
        body of that weight in the game, picked up and thrown (its colliders
        its own, not the level's)."""
        if piece not in kit.PIECES:
            raise KeyError("no kit piece " + piece)

        n = self._count.get(piece, 0) + 1
        self._count[piece] = n
        name = name or "%s.%03d" % (piece, n)
        basis = geo.rotation(yaw, pitch, roll)
        self.pieces.append({"name": name, "piece": piece, "sector": sector,
                            "position": [float(at[0]), float(at[1]), float(at[2])], "basis": basis})

        for i, c in enumerate(kit.PIECES[piece].get("climbs", []) if climbs else []):
            where = geo.add([float(v) for v in at], geo.apply(basis, c[0:3]))
            self.mark("%s_climb_%d" % (name.replace(".", "_"), i + 1), "ladder", where, yaw + c[6], sector, size=c[3:6])

        if loose > 0.0:
            self.mark("%s_loose" % name.replace(".", "_"), "loose", at, yaw, sector, piece=name, mass=float(loose))

        return name

    def ship(self, piece, at, yaw=0.0, sector="ships", name=None):
        """A ship (or anything with climbs) and its climbs."""
        return self.put(piece, at, yaw, sector, name=name, climbs=True)

    def wall(self, a, b, material="ashlar", y=0.0, sector="courtyard", thin=False, storeys=1, openings=None, face=1):
        """A straight wall from a to b (x, z) along x or z, `storeys` high from
        y. `openings`: {distance from a to the opening's middle: "door" |
        "window" | "arch" | "slit" | "lancet"} (lancet makes a tall wall).
        `face` +1 or -1 turns its pieces round (which way their front goes)."""
        ax, az = a
        bx, bz = b
        along_x = abs(bx - ax) >= abs(bz - az)
        length = abs(bx - ax) if along_x else abs(bz - az)
        step = 1.0 if (bx - ax if along_x else bz - az) >= 0 else -1.0
        yaw = (0.0 if along_x else 90.0) + (0.0 if face > 0 else 180.0)
        suffix = "_thin" if thin else ""
        openings = dict(openings or {})
        widths = {"door": 2.0, "window": 2.0, "arch": 2.4, "slit": 1.0, "lancet": 2.0}
        spans = []

        for at, kind in sorted(openings.items()):
            w = widths[kind]
            spans.append((at - w / 2.0, at + w / 2.0, kind))

        cursor = 0.0
        pieces = []

        for start, end, kind in spans + [(length, length, None)]:
            gap = start - cursor

            while gap > 1e-6:
                for size in (4, 2, 1):
                    if gap >= size - 1e-6:
                        pieces.append((cursor + size / 2.0, "len", size))
                        cursor += size
                        gap -= size
                        break
                else:
                    pieces.append((cursor + gap / 2.0, "len", 1))
                    cursor += gap
                    gap = 0.0

            if kind is not None:
                pieces.append(((start + end) / 2.0, kind, end - start))
                cursor = end

        fills = {1.0: "1", 2.0: "2", 2.4: "2p4", 4.0: "4"}

        for middle, kind, size in pieces:
            px = ax + step * middle if along_x else ax
            pz = az if along_x else az + step * middle

            for storey in range(storeys):
                py = y + storey * kit.STOREY

                if kind == "len":
                    name = "wall_%s%s_%s" % (material, suffix, fills[round(size, 1)])
                elif kind == "lancet":
                    # Two storeys a lancet; a last storey alone is plain wall.
                    if storey % 2 == 1:
                        continue
                    name = "wall_%s_tall_lancet" % material if storey + 1 < storeys else "wall_%s%s_2" % (material, suffix)
                elif storey == 0:
                    name = "wall_%s_slit" % material if kind == "slit" else "wall_%s%s_%s" % (material, suffix, kind)
                else:
                    # Above an opening, the next storey is plain wall of its width.
                    name = "wall_%s%s_%s" % (material, suffix, fills[round(size, 1)])

                self.put(name, (px, py, pz), yaw, sector)

    def floor(self, x0, z0, x1, z1, kind="cobble", y=0.0, sector="courtyard"):
        """Tiles over the rectangle (x0, z0)-(x1, z1), top at y: 4 m tiles, 2 m
        at the edges where 4 m do not fit."""
        x = x0

        while x < x1 - 1e-6:
            sx = 4 if x1 - x >= 4 - 1e-6 else 2
            z = z0

            while z < z1 - 1e-6:
                sz = 4 if z1 - z >= 4 - 1e-6 and sx == 4 else 2
                size = min(sx, sz)
                # Fill a 4 m column with 2 m tiles where needed.
                if size == 2 and sx == 4:
                    for dx in (1, 3):
                        self.put("floor_%s_2" % kind, (x + dx, y, z + 1), 0.0, sector)
                else:
                    self.put("floor_%s_%d" % (kind, size), (x + size / 2.0, y, z + size / 2.0), 0.0, sector)
                z += size
            x += sx

    def stairs(self, foot, yaw=0.0, piece="stair_straight", sector="courtyard"):
        """A flight from its foot (the middle of its bottom step's front edge)
        going away along its yaw."""
        self.put(piece, foot, yaw, sector)

    # Markers

    def mark(self, name, ucd, at, yaw=0.0, sector="courtyard", size=None, pitch=0.0, roll=0.0, **props):
        self.markers.append({"name": name, "ucd": ucd, "sector": sector, "position": [float(v) for v in at],
                             "basis": geo.rotation(yaw, pitch, roll), "size": [float(v) for v in size] if size else None,
                             "props": props})

    def route(self, name, points, sector="courtyard", wait=0.0):
        """A route and its waypoints [(x, y, z, yaw), ...] in order."""
        first = points[0]
        self.mark(name, "route", first[:3], sector=sector)

        for i, p in enumerate(points):
            self.mark("%s_%d" % (name, i + 1), "waypoint", p[:3], yaw=p[3] if len(p) > 3 else 0.0, sector=sector,
                      route=name, order=i + 1, wait=wait)

    # Ground

    def terrain(self, t):
        """A terrain (terrain.py's grid, cliff or tunnel) into the level."""
        self.ground.append(t)

    def data(self):
        return {"level": self.level, "pieces": self.pieces, "markers": self.markers, "terrain": self.ground}


def facing(frm, to):
    """The yaw (degrees) that faces from `frm` toward `to` (a marker's -Z)."""
    dx = to[0] - frm[0]
    dz = to[2] - frm[2]
    return math.degrees(math.atan2(-dx, -dz))
