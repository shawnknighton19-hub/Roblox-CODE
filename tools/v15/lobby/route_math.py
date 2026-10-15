"""Check exported V4 geometry for Bomb Tag's run/sprint/dodge-only movement.

Analytic solid intersections and sampled ground navigation are deliberately not
presented as Roblox physics or PathfindingService/Studio playtesting.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np

from geometry import parts, vertical_hit


def ray_heights(part, xs, zs, top, bottom):
    """Vectorized counterpart of Part.ray for a vertical ray segment."""
    count = len(xs)
    origin = np.column_stack((xs, np.full(count, top), zs))
    local = (origin - part.pos) @ part.rot
    direction = part.rot.T @ np.array((0.0, -1.0, 0.0))
    low = np.zeros(count)
    high = np.full(count, top - bottom)
    valid = np.ones(count, dtype=bool)
    if part.kind == "Ball":
        o, d = local / part.half, direction / part.half
        a = d @ d
        b = 2 * (o @ d)
        c = np.sum(o * o, axis=1) - 1
        disc = b * b - 4 * a * c
        valid &= disc >= 0
        root = np.sqrt(np.maximum(disc, 0))
        low = np.maximum(low, (-b - root) / (2 * a))
        high = np.minimum(high, (-b + root) / (2 * a))
    elif part.kind == "Cylinder":
        if abs(direction[0]) < 1e-10:
            valid &= np.abs(local[:, 0]) <= part.half[0] + 1e-8
        else:
            aa = (-part.half[0] - local[:, 0]) / direction[0]
            bb = (part.half[0] - local[:, 0]) / direction[0]
            low = np.maximum(low, np.minimum(aa, bb))
            high = np.minimum(high, np.maximum(aa, bb))
        o, d = local[:, 1:] / part.half[1:], direction[1:] / part.half[1:]
        a = d @ d
        b = 2 * (o @ d)
        c = np.sum(o * o, axis=1) - 1
        if a < 1e-12:
            valid &= c <= 1e-8
        else:
            disc = b * b - 4 * a * c
            valid &= disc >= 0
            root = np.sqrt(np.maximum(disc, 0))
            low = np.maximum(low, (-b - root) / (2 * a))
            high = np.minimum(high, (-b + root) / (2 * a))
    else:
        for normal, distance in part.planes():
            denom = normal @ direction
            numer = distance - local @ normal
            if abs(denom) < 1e-10:
                valid &= numer >= -1e-8
            elif denom < 0:
                low = np.maximum(low, numer / denom)
            else:
                high = np.minimum(high, numer / denom)
    valid &= low <= high + 1e-8
    return valid, top - low


def circle_offsets(radius, samples=12):
    return [(0.0, 0.0)] + [
        (radius * math.cos(t), radius * math.sin(t))
        for t in np.linspace(0, 2 * math.pi, samples, endpoint=False)
    ]


def ground_grid(collision, radius, step=2.0, level=0.0):
    """Actual collider/ground sampled with a swept standing circle footprint.

    Elevated surfaces intentionally are not ground navigation: ramps and decks
    have their own slope, headroom and connection checks below. At ground level,
    each footprint sample requires support near Y=0 and an unobstructed standing
    envelope from Y=.4 through 6.4. Floor references cannot create fake support.
    """
    ground = [p for p in collision if p.minimum[1] < level + .25 and p.maximum[1] > level - .65]
    if not ground:
        raise ValueError("No ground support geometry")
    xmin = math.floor(min(p.minimum[0] for p in ground) / step) * step
    xmax = math.ceil(max(p.maximum[0] for p in ground) / step) * step
    zmin = math.floor(min(p.minimum[2] for p in ground) / step) * step
    zmax = math.ceil(max(p.maximum[2] for p in ground) / step) * step
    xx, zz = np.meshgrid(np.arange(xmin, xmax + step, step), np.arange(zmin, zmax + step, step))
    centerx, centerz = xx.ravel(), zz.ravel()
    walkable = np.ones(len(centerx), dtype=bool)
    blockers = [p for p in collision if p.maximum[1] > level + .4 and p.minimum[1] < level + 6.4]
    for dx, dz in circle_offsets(radius):
        xs, zs = centerx + dx, centerz + dz
        supported = np.zeros(len(xs), dtype=bool)
        blocked = np.zeros(len(xs), dtype=bool)
        for p in ground:
            idx = np.flatnonzero(walkable & ~supported & (xs >= p.minimum[0] - 1e-7) &
                                 (xs <= p.maximum[0] + 1e-7) & (zs >= p.minimum[2] - 1e-7) &
                                 (zs <= p.maximum[2] + 1e-7))
            if len(idx):
                hit, heights = ray_heights(p, xs[idx], zs[idx], level + .3, level - .6)
                supported[idx] |= hit & (np.abs(heights - level) <= .3)
        for p in blockers:
            idx = np.flatnonzero(walkable & ~blocked & (xs >= p.minimum[0] - 1e-7) &
                                 (xs <= p.maximum[0] + 1e-7) & (zs >= p.minimum[2] - 1e-7) &
                                 (zs <= p.maximum[2] + 1e-7))
            if len(idx):
                hit, _ = ray_heights(p, xs[idx], zs[idx], level + 6.4, level + .4)
                blocked[idx] |= hit
        walkable &= supported & ~blocked
    return walkable.reshape(xx.shape), xx, zz


def components(walkable):
    """Four-neighbor connections avoid counting diagonal corner-cutting."""
    labels = np.full(walkable.shape, -1, dtype=int)
    sizes = []
    for row, col in zip(*np.where(walkable)):
        if labels[row, col] != -1:
            continue
        label = len(sizes)
        labels[row, col] = label
        todo = deque([(row, col)])
        size = 0
        while todo:
            r, c = todo.popleft()
            size += 1
            for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if (0 <= nr < walkable.shape[0] and 0 <= nc < walkable.shape[1]
                        and walkable[nr, nc] and labels[nr, nc] == -1):
                    labels[nr, nc] = label
                    todo.append((nr, nc))
        sizes.append(size)
    return labels, sizes


def nearest_label(labels, xx, zz, x, z, max_distance=6):
    distance = (xx - x) ** 2 + (zz - z) ** 2
    distance[labels < 0] = np.inf
    index = np.unravel_index(np.argmin(distance), distance.shape)
    if distance[index] > max_distance ** 2:
        return None
    return int(labels[index])

