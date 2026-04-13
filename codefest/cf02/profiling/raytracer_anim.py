"""
Animated Ray Tracer — ECE 510 HW4AI Project Baseline
Supports: sphere, plane, box, cylinder, disk
Renders N frames with a moving camera orbiting the scene.

Usage:
    python raytracer_anim.py scene.json
    python raytracer_anim.py scene.json --frames 30 --outdir frames/
"""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import json, os, argparse, time

# ── math helpers ──────────────────────────────────────────────────────────────

def normalize(x):
    n = np.linalg.norm(x)
    return x if n < 1e-12 else x / n

def dot(a, b):
    return float(np.dot(a, b))

# ── intersection routines ─────────────────────────────────────────────────────

def intersect_sphere(O, D, obj):
    """
    Ray-sphere intersection via quadratic formula.
    FLOPs: 3 dots + sqrt + misc = ~23
    """
    S    = np.array(obj['position'])
    R    = float(obj['radius'])
    OS   = O - S
    a    = dot(D, D)
    b    = 2.0 * dot(D, OS)
    c    = dot(OS, OS) - R * R
    disc = b * b - 4.0 * a * c
    if disc <= 0:
        return np.inf, None
    sq     = np.sqrt(disc)
    q      = (-b - sq) / 2.0 if b < 0 else (-b + sq) / 2.0
    t0, t1 = q / a, c / q
    t0, t1 = min(t0, t1), max(t0, t1)
    if t1 < 0:
        return np.inf, None
    t = t1 if t0 < 0 else t0
    M = O + D * t
    N = normalize(M - S)
    return t, N


def intersect_plane(O, D, obj):
    """
    Ray-plane intersection.
    FLOPs: 2 dots + div = ~8
    """
    P     = np.array(obj['position'])
    N     = normalize(np.array(obj['normal']))
    denom = dot(D, N)
    if abs(denom) < 1e-6:
        return np.inf, None
    d = dot(P - O, N) / denom
    if d < 0:
        return np.inf, None
    return d, N


def intersect_box(O, D, obj):
    """
    Ray-AABB intersection using the slab method.
    Box defined by 'center' and 'half_size' [hx, hy, hz].
    FLOPs: 3 pairs of slab tests = ~36
    """
    C  = np.array(obj['center'])
    hs = np.array(obj['half_size'])
    lo = C - hs
    hi = C + hs

    tmin = -np.inf
    tmax =  np.inf
    normal_min = None

    axes = [np.array([1,0,0]), np.array([0,1,0]), np.array([0,0,1])]

    for i, ax in enumerate(axes):
        d_i = D[i]
        if abs(d_i) < 1e-8:
            if O[i] < lo[i] or O[i] > hi[i]:
                return np.inf, None
        else:
            t1 = (lo[i] - O[i]) / d_i
            t2 = (hi[i] - O[i]) / d_i
            if t1 > t2:
                t1, t2 = t2, t1
                sign = 1.0
            else:
                sign = -1.0
            if t1 > tmin:
                tmin = t1
                normal_min = sign * ax
            tmax = min(tmax, t2)

    if tmin > tmax or tmax < 0:
        return np.inf, None
    t = tmin if tmin >= 0 else tmax
    if t < 0:
        return np.inf, None
    return t, normal_min.astype(float)


def intersect_cylinder(O, D, obj):
    """
    Ray-finite cylinder intersection (axis-aligned along Y).
    Center at 'position', radius 'radius', half-height 'half_height'.
    FLOPs: 2 dots + sqrt + cap tests = ~28
    """
    C   = np.array(obj['position'])
    R   = float(obj['radius'])
    hh  = float(obj['half_height'])

    # work in cylinder-local coords (translate only, Y-axis aligned)
    oc  = O - C
    # project onto XZ plane
    dx, dz = D[0], D[2]
    ox, oz = oc[0], oc[2]

    a = dx*dx + dz*dz
    if abs(a) < 1e-8:
        return np.inf, None   # ray parallel to axis

    b    = 2.0 * (ox*dx + oz*dz)
    c    = ox*ox + oz*oz - R*R
    disc = b*b - 4*a*c
    if disc < 0:
        return np.inf, None

    sq     = np.sqrt(disc)
    t1     = (-b - sq) / (2*a)
    t2     = (-b + sq) / (2*a)

    best_t = np.inf
    best_N = None

    for t in (t1, t2):
        if t < 1e-4:
            continue
        hit = O + D * t
        y   = hit[1] - C[1]
        if -hh <= y <= hh:
            if t < best_t:
                best_t = t
                nx = (hit[0] - C[0]) / R
                nz = (hit[2] - C[2]) / R
                best_N = np.array([nx, 0.0, nz])

    # test caps (y = C[1] ± hh)
    if abs(D[1]) > 1e-8:
        for cap_y, cap_sign in [(C[1] + hh, 1.0), (C[1] - hh, -1.0)]:
            t = (cap_y - O[1]) / D[1]
            if t < 1e-4:
                continue
            hit = O + D * t
            dx2 = hit[0] - C[0]
            dz2 = hit[2] - C[2]
            if dx2*dx2 + dz2*dz2 <= R*R:
                if t < best_t:
                    best_t = t
                    best_N = np.array([0.0, cap_sign, 0.0])

    return best_t, best_N


def intersect_disk(O, D, obj):
    """
    Ray-disk intersection: a plane with a radius limit.
    FLOPs: plane test + distance check = ~14
    """
    C      = np.array(obj['center'])
    N_disk = normalize(np.array(obj['normal']))
    R      = float(obj['radius'])

    denom = dot(D, N_disk)
    if abs(denom) < 1e-6:
        return np.inf, None
    t = dot(C - O, N_disk) / denom
    if t < 1e-4:
        return np.inf, None
    hit  = O + D * t
    diff = hit - C
    if dot(diff, diff) > R * R:
        return np.inf, None
    N_out = N_disk if denom < 0 else -N_disk
    return t, N_out


def intersect(O, D, obj):
    """Dispatch to the correct intersection routine."""
    t = obj['type']
    if   t == 'sphere':   return intersect_sphere(O, D, obj)
    elif t == 'plane':    return intersect_plane(O, D, obj)
    elif t == 'box':      return intersect_box(O, D, obj)
    elif t == 'cylinder': return intersect_cylinder(O, D, obj)
    elif t == 'disk':     return intersect_disk(O, D, obj)
    return np.inf, None

# ── color helpers ─────────────────────────────────────────────────────────────

def checkerboard(M, c0, c1, scale=2.0):
    return np.array(c0) \
        if (int(M[0]*scale) % 2) == (int(M[2]*scale) % 2) \
        else np.array(c1)

def stripe(M, c0, c1, axis=0, scale=2.0):
    """Alternating stripes along one axis."""
    return np.array(c0) if int(M[axis]*scale) % 2 == 0 else np.array(c1)

def get_color(obj, M):
    c = obj.get('color')
    if c is None:
        return np.array([0.8, 0.8, 0.8])
    if callable(c):
        return c(M)
    return np.array(c)

# ── per-ray trace ─────────────────────────────────────────────────────────────

def trace_ray(rayO, rayD, scene, light_pos, light_col,
              ambient, diffuse_c, specular_c, specular_k):
    t_min   = np.inf
    obj_hit = None
    N_hit   = None

    for obj in scene:
        t, N = intersect(rayO, rayD, obj)
        if t < t_min:
            t_min, obj_hit, N_hit = t, obj, N

    if obj_hit is None or N_hit is None:
        return None

    M   = rayO + rayD * t_min
    N   = normalize(N_hit)
    col = get_color(obj_hit, M)
    toL = normalize(light_pos - M)
    toO = normalize(rayO - M)

    # shadow test
    in_shadow = False
    for obj in scene:
        if obj is obj_hit:
            continue
        t_s, _ = intersect(M + N * 1e-4, toL, obj)
        if t_s < np.inf:
            in_shadow = True
            break

    if in_shadow:
        return None

    col_ray  = ambient
    col_ray += obj_hit.get('diffuse_c',  diffuse_c)  \
               * max(dot(N, toL), 0) * col
    col_ray += obj_hit.get('specular_c', specular_c) \
               * max(dot(N, normalize(toL + toO)), 0) ** specular_k \
               * light_col
    return obj_hit, M, N, col_ray

# ── render one frame ──────────────────────────────────────────────────────────

def render_frame(scene, camera, light, render_cfg):
    w, h       = camera['width'], camera['height']
    depth_max  = render_cfg['depth_max']
    ambient    = render_cfg['ambient']
    diffuse_c  = render_cfg['diffuse_c']
    specular_c = render_cfg['specular_c']
    specular_k = render_cfg['specular_k']
    O          = np.array(camera['position'])
    Q          = np.array(camera['look_at'])
    light_pos  = np.array(light['position'])
    light_col  = np.array(light['color'])
    img        = np.zeros((h, w, 3))
    r          = float(w) / h
    S          = (-1., -1./r + .25, 1., 1./r + .25)

    for i, x in enumerate(np.linspace(S[0], S[2], w)):
        for j, y in enumerate(np.linspace(S[1], S[3], h)):
            col        = np.zeros(3)
            Q_px       = np.array([x, y, Q[2]])
            D          = normalize(Q_px - O)
            rayO, rayD = O.copy(), D.copy()
            reflection = 1.0

            for _ in range(depth_max):
                hit = trace_ray(rayO, rayD, scene, light_pos, light_col,
                                ambient, diffuse_c, specular_c, specular_k)
                if hit is None:
                    break
                obj, M, N, col_ray = hit
                rayO       = M + N * 1e-4
                rayD       = normalize(rayD - 2 * dot(rayD, N) * N)
                col       += reflection * col_ray
                reflection *= obj.get('reflection', 1.0)

            img[h - j - 1, i] = np.clip(col, 0, 1)
    return img

# ── camera orbit ──────────────────────────────────────────────────────────────

def orbit_camera(base_camera, frame_idx, num_frames,
                 radius=4.0, height=0.8):
    angle = 2 * np.pi * frame_idx / num_frames
    cam   = dict(base_camera)
    cam['position'] = [
        radius * np.sin(angle),
        height,
        -radius * np.cos(angle)
    ]
    return cam

# ── scene loader ──────────────────────────────────────────────────────────────

def load_scene(path):
    with open(path) as f:
        data = json.load(f)

    scene = []
    for obj in data['objects']:
        o = dict(obj)
        # resolve procedural colors
        pat = o.pop('pattern', None)
        if pat == 'checkerboard':
            c0 = o.pop('color_0', [1.,1.,1.])
            c1 = o.pop('color_1', [0.,0.,0.])
            sc = o.pop('scale', 2.0)
            o['color'] = lambda M, c0=c0, c1=c1, sc=sc: \
                         checkerboard(M, c0, c1, sc)
        elif pat == 'stripe':
            c0   = o.pop('color_0', [1.,1.,1.])
            c1   = o.pop('color_1', [0.,0.,0.])
            axis = o.pop('axis', 0)
            sc   = o.pop('scale', 2.0)
            o['color'] = lambda M, c0=c0, c1=c1, ax=axis, sc=sc: \
                         stripe(M, c0, c1, ax, sc)
        scene.append(o)

    return scene, data['camera'], data['lights'][0], data['render']

# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='Animated ray tracer — sphere, plane, box, cylinder, disk')
    parser.add_argument('scene', nargs='?',
                        default='codefest/cf02/profiling/scene.json')
    parser.add_argument('--frames', type=int, default=30)
    parser.add_argument('--outdir',
                        default='codefest/cf02/profiling/frames')
    parser.add_argument('--radius', type=float, default=4.0,
                        help='Camera orbit radius')
    parser.add_argument('--height', type=float, default=0.8,
                        help='Camera orbit height')
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    scene, base_cam, light, render_cfg = load_scene(args.scene)

    obj_types = {}
    for o in scene:
        obj_types[o['type']] = obj_types.get(o['type'], 0) + 1
    print(f"Scene: {obj_types}")
    print(f"Rendering {args.frames} frames  "
          f"({base_cam['width']}x{base_cam['height']} px, "
          f"depth={render_cfg['depth_max']})")

    t0 = time.time()
    for f in range(args.frames):
        cam  = orbit_camera(base_cam, f, args.frames,
                            args.radius, args.height)
        img  = render_frame(scene, cam, light, render_cfg)
        path = os.path.join(args.outdir, f"frame_{f:04d}.png")
        plt.imsave(path, img)
        elapsed = time.time() - t0
        fps     = (f + 1) / elapsed
        eta     = (args.frames - f - 1) / fps if fps > 0 else 0
        print(f"  frame {f+1:3d}/{args.frames}  "
              f"{elapsed:.1f}s elapsed  "
              f"{fps:.3f} fps  "
              f"ETA {eta:.0f}s")

    total = time.time() - t0
    print(f"\nDone. {args.frames} frames in {total:.1f}s  "
          f"({total/args.frames:.2f} s/frame)")
    print(f"Frames saved to {args.outdir}/")

if __name__ == '__main__':
    main()
