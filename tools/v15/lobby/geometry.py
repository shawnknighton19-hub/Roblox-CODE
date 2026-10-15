"""Geometry analysis helpers for the builder's deterministic Instance export.

These reconstruct analytic part geometry, not Roblox physics or rendering.
"""
import json
import math
from pathlib import Path
import numpy as np

PART_CLASSES = {"Part", "WedgePart", "CornerWedgePart", "SpawnLocation", "MeshPart"}


def walk(node, prefix=""):
    name = node.get("props", {}).get("Name", node.get("class", "?"))
    path = f"{prefix}/{name}" if prefix else name
    yield node, path
    for child in node.get("children", []):
        yield from walk(child, path)


def load_maps(path):
    doc = json.loads(Path(path).read_text())
    models = {}
    for root in doc["instances"]:
        for node, location in walk(root):
            if node.get("class") == "Model" and any(c.get("props", {}).get("Name") == "Floor" for c in node.get("children", [])):
                models[node["props"]["Name"]] = node
    return doc, models


def vec(value, default=(0, 0, 0)):
    if value is None:
        return np.array(default, dtype=float)
    if isinstance(value, list):
        return np.array(value, dtype=float)
    return np.array([value.get(a, default[i]) for i, a in enumerate("XYZ")], dtype=float)


def color(value):
    if not value:
        return (0.6, 0.6, 0.6)
    return tuple(value[c] for c in "RGB")


def frame(props):
    cf = props.get("CFrame", {})
    pos = vec(cf.get("p", props.get("Position")))
    rotation = np.array(cf.get("m", [1,0,0,0,1,0,0,0,1]), dtype=float).reshape(3, 3)
    return pos, rotation


class Part:
    def __init__(self, node, path=""):
        self.node = node
        self.props = node["props"]
        self.name = self.props.get("Name", "?")
        self.path = path
        self.pos, self.rot = frame(self.props)
        self.size = vec(self.props.get("Size"), (4, 1.2, 2))
        self.half = self.size / 2
        self.attrs = node.get("attributes", {})
        self.kind = self.props.get("Shape", {}).get("Name", "Block")
        if node["class"] == "WedgePart":
            self.kind = "Wedge"
        self.collide = self.props.get("CanCollide", True)
        self.query = self.props.get("CanQuery", True)
        self.transparency = self.props.get("Transparency", 0)
        self.corners = np.array([self.pos + self.rot @ np.array([x,y,z]) for x in (-self.half[0], self.half[0]) for y in (-self.half[1], self.half[1]) for z in (-self.half[2], self.half[2])])
        self.minimum, self.maximum = self.corners.min(axis=0), self.corners.max(axis=0)

    def to_local(self, point):
        return self.rot.T @ (np.asarray(point) - self.pos)

    def planes(self):
        """Convex local solid, including the actual wedge incline."""
        planes = [(np.array(v), h) for v, h in [((1,0,0), self.half[0]), ((-1,0,0), self.half[0]), ((0,1,0),self.half[1]), ((0,-1,0),self.half[1]), ((0,0,1),self.half[2]), ((0,0,-1),self.half[2])]]
        if self.kind == "Wedge":
            planes.append((np.array((0, 1, -self.size[1]/self.size[2])), 0.0))
        return planes

    def ray(self, origin, direction, limit=math.inf):
        """Ray/solid interval. Cylinders and ellipsoids use analytic surfaces."""
        o, d = self.to_local(origin), self.rot.T @ np.asarray(direction)
        if self.kind == "Ball":
            oo, dd = o/self.half, d/self.half
            a, b, c = dd@dd, 2*(oo@dd), oo@oo-1
            disc = b*b - 4*a*c
            if disc < 0 or a < 1e-12:
                return None
            roots = sorted(((-b-math.sqrt(disc))/(2*a), (-b+math.sqrt(disc))/(2*a)))
            result = max(roots[0], 0)
            return result if roots[1] >= 0 and result <= limit else None
        if self.kind == "Cylinder":
            lo, hi = 0.0, limit
            if abs(d[0]) < 1e-10:
                if abs(o[0]) > self.half[0]:
                    return None
            else:
                aa, bb = sorted(((-self.half[0]-o[0])/d[0], (self.half[0]-o[0])/d[0]))
                lo, hi = max(lo,aa), min(hi,bb)
            oo, dd = o[1:]/self.half[1:], d[1:]/self.half[1:]
            a, b, c = dd@dd, 2*(oo@dd), oo@oo-1
            if a < 1e-12:
                return lo if c<=0 and lo<=hi else None
            disc = b*b-4*a*c
            if disc < 0:
                return None
            aa, bb = sorted(((-b-math.sqrt(disc))/(2*a),(-b+math.sqrt(disc))/(2*a)))
            lo, hi = max(lo,aa), min(hi,bb)
            return lo if lo<=hi else None
        lo, hi = 0.0, limit
        for normal, distance in self.planes():
            denom, numer = normal@d, distance-normal@o
            if abs(denom)<1e-10:
                if numer < -1e-8:
                    return None
            elif denom < 0:
                lo = max(lo,numer/denom)
            else:
                hi = min(hi,numer/denom)
            if lo > hi+1e-8:
                return None
        return lo if hi>=0 and lo<=limit else None


def parts(model):
    return [Part(node,path) for node,path in walk(model) if node.get("class") in PART_CLASSES]


def vertical_hit(parts_, x, z, top, bottom, query=True):
    candidates=[]
    for p in parts_:
        if (query and not p.query) or (not query and not p.collide):
            continue
        if p.minimum[0]-1e-7<=x<=p.maximum[0]+1e-7 and p.minimum[2]-1e-7<=z<=p.maximum[2]+1e-7:
            hit=p.ray((x,top,z),(0,-1,0),top-bottom)
            if hit is not None:
                candidates.append((hit,p))
    if not candidates:
        return None
    distance,p=min(candidates,key=lambda item:item[0])
    return top-distance,p
