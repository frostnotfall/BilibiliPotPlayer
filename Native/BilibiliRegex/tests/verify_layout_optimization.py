"""Differential layout/performance check against a saved pre-optimization DLL.

python Native/BilibiliRegex/tests/verify_layout_optimization.py --reference PATH
Both reservation results and final top coordinates must match exactly.
"""
import argparse
import ctypes as C
from pathlib import Path
import random
import statistics
import time

REPO = Path(__file__).resolve().parents[3]


def bind(path):
    dll = C.CDLL(str(path.resolve()))
    signatures = {
        "Create": ([C.c_uint32], C.c_size_t),
        "Free": ([C.c_size_t], C.c_int),
        "LayoutInit": ([C.c_size_t] + [C.c_uint32] * 3, C.c_int),
        "Place": ([C.c_size_t] + [C.c_uint32] * 4, C.c_size_t),
        "RefineTop": ([C.c_size_t] + [C.c_uint32] * 3, C.c_size_t),
    }
    for name, (args, result) in signatures.items():
        proc = getattr(dll, "BiliDanmaku" + name)
        proc.argtypes, proc.restype = args, result
        setattr(dll, name, proc)
    return dll


def run(dll, events, order, area, duration):
    handle = dll.Create(30000)
    assert handle and dll.LayoutInit(handle, area, 1, duration) == 0
    try:
        start = time.perf_counter()
        positions = [0] * len(events)
        for index in order:
            positions[index] = dll.Place(handle, *events[index])
            assert positions[index] != C.c_size_t(-1).value
        reserved = positions.copy()
        placed = time.perf_counter()
        for index in order:
            code = positions[index] - 1
            if code >= 0 and events[index][1] == 5:
                positions[index] = dll.RefineTop(handle, events[index][0], code >> 32, code & 0xFFFFFFFF)
                assert positions[index] != C.c_size_t(-1).value
        finished = time.perf_counter()
        return reserved, positions, (placed-start)*1000, (finished-placed)*1000
    finally:
        dll.Free(handle)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=1)
    args = parser.parse_args()
    assert args.rounds > 0
    previous = bind(args.reference)
    current = bind(REPO / "Extension/Lib/BilibiliRegex.dll")
    assert previous._handle != current._handle, "comparison requires two separate DLLs"
    rng = random.Random(20374)
    cases = [
        ("mixed", 10000, 864, 15000, 25, [1, 1, 5]),
        ("top-flood", 4000, 864, 15000, 2, [5]),
        ("same-time", 1000, 144, 15000, 0, [1, 5, 5, 6, 4]),
        ("small-region", 2000, 36, 1000, 10, [5, 1, 6, 4]),
        ("priority", 4000, 1080, 5000, 20, [1, 5, 5, 6, 4]),
        ("long-top-mixed", 35000, 864, 15000, 45, [1, 5, 5, 5]),
        ("uniform-top-rows", 10000, 864, 15000, 45, [1, 5, 5, 5]),
    ]
    for name, count, area, duration, step, modes in cases:
        events = [(i*step, modes[i % len(modes)], rng.randrange(40, 2400), rng.choice([20, 28, 36, 47, 68])) for i in range(count)]
        if name == "uniform-top-rows":
            events = [(i*step, modes[i % len(modes)], rng.randrange(80, 800), 36) for i in range(count)]
        order = list(range(count))
        if name == "priority":
            ranks = [(rng.randrange(8), rng.randrange(12), -i) for i in order]
            order.sort(key=lambda i: ranks[i], reverse=True)
        timings = [[], [], [], []]
        for _ in range(args.rounds):
            old = run(previous, events, order, area, duration)
            new = run(current, events, order, area, duration)
            for phase in [0, 1]:
                for index, (a, b) in enumerate(zip(old[phase], new[phase])):
                    assert a == b, (name, "reservation" if phase == 0 else "refinement", index, events[index], a, b)
            for values, elapsed in zip(timings, [old[2], new[2], old[3], new[3]]):
                values.append(elapsed)
        old_place, new_place, old_refine, new_refine = map(statistics.median, timings)
        print(f"PASS {name}: {count} candidates, {sum(bool(x) for x in new[1])} retained; "
              f"place {old_place:.1f}->{new_place:.1f} ms; refine {old_refine:.1f}->{new_refine:.1f} ms", flush=True)
    for trial in range(200):
        count = rng.randrange(20, 160)
        area, duration = rng.choice([36, 72, 144, 864]), rng.choice([1, 3, 7, 1000, 15000])
        offset = 0 if trial % 2 else 0xffff0000
        events = [(offset+rng.randrange(duration*2), rng.choice([1, 4, 5, 5, 6]),
                   rng.choice([1, 2, 17, 1919, 1920, 2400, rng.randrange(20, 800)]),
                   rng.choice([20, 36, 36, 47])) for _ in range(count)]
        order = list(range(count))
        rng.shuffle(order)
        old = run(previous, events, order, area, duration)
        new = run(current, events, order, area, duration)
        assert old[:2] == new[:2], ("randomized interval boundaries", trial)
    print("PASS 200 randomized boundary/priority cases: all reservations and final coordinates unchanged")


if __name__ == "__main__":
    main()
