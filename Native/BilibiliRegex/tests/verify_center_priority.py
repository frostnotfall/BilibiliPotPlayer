"""Check center-first top placement against an exhaustive pixel oracle.

Optional --reference compares timings with a saved DLL using the old policy;
coordinates and retention counts can differ intentionally between policies.
"""
import argparse
import random
import statistics
from pathlib import Path

from verify_layout_optimization import REPO, bind, run


def decode(code):
    assert code and code != (1 << 64) - 1
    return (code - 1) >> 32, (code - 1) & 0xFFFFFFFF


def nearest(events, start, width, height, area, duration, include_moving):
    """Enumerate every screen pixel, independently of native boundary search."""
    if height > area:
        return None
    obstacles = []
    for event in events:
        t, mode, w, h, x, y = event
        begin, end = max(start, t), min(start + duration, t + duration)
        if begin >= end or (not include_moving and mode in (1, 6)):
            continue
        def left(time):
            if mode not in (1, 6):
                return x
            travel = (1920.0 + w) * (time - t) / duration
            return -w + travel if mode == 6 else 1920.0 - travel
        l0, l1 = left(begin), left(end)
        obstacles.append((y, y + h, min(l0, l1) - width - 2, max(l0, l1) + w + 2))
    obstacles.sort()
    for x in sorted(range(1921 - width), key=lambda x: (abs(2*x + width - 1920), x)):
        y = 0
        for low, high, left, right in obstacles:
            if high <= y or not left < x < right:
                continue
            if y + height <= low:
                break
            y = high
            if y + height > area:
                break
        if y + height <= area:
            return x + width // 2, y
    return None


def verify(dll):
    h = dll.Create(30000)
    try:
        # Equal side gaps must pack next to the central text, not screen edges.
        for width, expected in [(500, (458, 0)), (501, (1462, 0)), (1, (962, 0))]:
            assert dll.LayoutInit(h, 25, 1, 15000) == 0
            assert decode(dll.Place(h, 1000, 5, width, 25)) == (959 if width % 2 else 960, 0)
            assert decode(dll.Place(h, 1000, 5, width, 25)) == expected

        # A lower gap closer to center beats a higher gap nearer an edge.
        assert dll.LayoutInit(h, 50, 1, 15000) == 0
        assert dll.Place(h, 1000, 5, 1000, 25)
        assert dll.Place(h, 1000, 5, 200, 25)
        code = dll.Place(h, 1000, 5, 200, 25)
        assert decode(code) == (758, 25)

        # Later moving reservations push overflow down, preserving center bias.
        assert dll.LayoutInit(h, 100, 1, 15000) == 0
        for _ in range(4):
            assert dll.Place(h, 1000, 5, 500, 25)
        code = dll.Place(h, 1000, 5, 500, 25)
        assert decode(code) == (458, 0)
        for _ in range(2):
            assert dll.Place(h, 1000, 1, 500, 25)
        assert decode(dll.RefineTop(h, 1000, *decode(code))) == (458, 50)
        for _ in range(2):
            assert dll.Place(h, 1000, 1, 500, 25)
        assert decode(dll.RefineTop(h, 1000, 458, 50)) == (458, 50)

        rng = random.Random(20375)
        placed = refined = 0
        for trial in range(80):
            area, duration = rng.choice([25, 50, 100, 144, 1080]), rng.choice([1, 7, 1000, 15000])
            assert dll.LayoutInit(h, area, 1, duration) == 0
            events = []
            for _ in range(24):
                start = (0xFFFF0000 if trial % 2 else 0) + rng.randrange(2*duration)
                mode = rng.choice([1, 4, 5, 5, 5, 6])
                width = rng.choice([1, 2, 17, 200, 501, 1000, 1919, 1920, 2400])
                height = rng.choice([17, 25, 36, 47])
                expected = nearest(events, start, min(width, 1920), height, area, duration, False) if mode == 5 else None
                code = dll.Place(h, start, mode, width, height)
                assert code != (1 << 64) - 1
                if mode == 5:
                    assert (decode(code) if code else None) == expected, ("place", trial, start, width, height, expected, code)
                    placed += 1
                if not code:
                    continue
                cx, y = decode(code)
                w = width if mode in (1, 6) else min(width, 1920)
                x = cx - w // 2 if mode == 5 else (0 if mode in (1, 6) else (1920 - w) // 2)
                events.append((start, mode, w, height, x, 1080-y-height if mode == 4 else y))
            for index, event in enumerate(events):
                start, mode, width, height, x, y = event
                if mode != 5:
                    continue
                expected = (x + width // 2, y)
                if x != (1920 - width) // 2:
                    expected = nearest(events[:index] + events[index+1:], start, width, height, area, duration, True) or expected
                actual = decode(dll.RefineTop(h, start, x + width // 2, y))
                assert actual == expected, ("refine", trial, event, expected, actual)
                events[index] = (start, mode, width, height, actual[0] - width // 2, actual[1])
                refined += 1
        print(f"PASS center priority: directed cases and exhaustive pixel oracle, {placed} placements, {refined} refinements", flush=True)
    finally:
        dll.Free(h)


def benchmark(current, previous, rounds):
    rng = random.Random(20374)
    cases = [
        ("mixed", 10000, 864, 25, [1, 1, 5]),
        ("top-flood", 4000, 864, 2, [5]),
        ("long-top-mixed", 35000, 864, 45, [1, 5, 5, 5]),
        ("uniform-top-rows", 10000, 864, 45, [1, 5, 5, 5]),
    ]
    for name, count, area, step, modes in cases:
        events = [(i*step, modes[i % len(modes)], rng.randrange(40, 2400), rng.choice([20, 28, 36, 47, 68])) for i in range(count)]
        if name == "uniform-top-rows":
            events = [(i*step, modes[i % len(modes)], rng.randrange(80, 800), 36) for i in range(count)]
        order = list(range(count))
        timings = [[], [], [], []]
        for round_index in range(rounds):
            # Alternate order to reduce systematic warm-cache bias.
            if round_index % 2:
                new, old = run(current, events, order, area, 15000), run(previous, events, order, area, 15000)
            else:
                old, new = run(previous, events, order, area, 15000), run(current, events, order, area, 15000)
            for values, elapsed in zip(timings, [old[2], new[2], old[3], new[3]]):
                values.append(elapsed)
        op, np, of, nf = map(statistics.median, timings)
        print(f"BENCH {name}: {count} candidates; retained {sum(bool(x) for x in old[1])}->{sum(bool(x) for x in new[1])}; "
              f"place {op:.1f}->{np:.1f} ms; refine {of:.1f}->{nf:.1f} ms; total {op+of:.1f}->{np+nf:.1f} ms", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--rounds", type=int, default=3)
    args = parser.parse_args()
    assert args.rounds > 0
    current = bind(REPO / "Extension/Lib/BilibiliRegex.dll")
    verify(current)
    if args.reference:
        previous = bind(args.reference)
        assert previous._handle != current._handle
        benchmark(current, previous, args.rounds)


if __name__ == "__main__":
    main()
