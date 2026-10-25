"""Compare every merge group and representative against a saved DLL.

python Native/BilibiliRegex/tests/verify_merge_optimization.py --reference OLD.dll
Inputs are built before timing; times include the Python/ctypes call boundary.
"""
import argparse
import ctypes as C
import json
from pathlib import Path
import random
import statistics
import time

REPO = Path(__file__).resolve().parents[3]


def bind(path):
    dll = C.CDLL(str(path.resolve()))
    signatures = {
        "Create": ([C.c_uint32], C.c_size_t),
        "Feed": ([C.c_size_t, C.c_char_p, C.c_uint32, C.c_uint32], C.c_int),
        "Text": ([C.c_size_t, C.c_uint32], C.c_char_p),
        "Free": ([C.c_size_t], C.c_int),
    }
    for name, (args, result) in signatures.items():
        proc = getattr(dll, "BiliDanmaku" + name)
        proc.argtypes, proc.restype = args, result
        setattr(dll, name, proc)
    return dll


def run(dll, rows):
    handle = dll.Create(30000)
    assert handle
    groups = []
    started = time.perf_counter()
    try:
        for raw, progress in rows:
            group = dll.Feed(handle, raw, len(raw), progress)
            assert group >= 0
            groups.append(group)
        fed = time.perf_counter()
        representatives = [dll.Text(handle, group) for group in range(max(groups) + 1)]
        assert all(representatives)
        return groups, representatives, (fed - started) * 1000
    finally:
        dll.Free(handle)


def protobuf_fields(data):
    pos = 0

    def varint():
        nonlocal pos
        value = 0
        for shift in range(0, 70, 7):
            assert pos < len(data), "truncated protobuf varint"
            byte = data[pos]
            pos += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value
        raise AssertionError("oversized protobuf varint")

    while pos < len(data):
        tag = varint()
        field, wire = tag >> 3, tag & 7
        assert field
        if wire == 0:
            yield field, varint()
        elif wire == 2:
            length = varint()
            assert length <= len(data) - pos
            value = data[pos:pos + length]
            pos += length
            yield field, value
        elif wire in (1, 5):
            pos += 8 if wire == 1 else 4
            assert pos <= len(data)
        else:
            raise AssertionError(f"unsupported wire type: {wire}")


def segment_rows(folder):
    paths = sorted(folder.glob("segment-*.bin"), key=lambda path: int(path.stem.split("-")[-1]))
    assert paths, f"no segment-*.bin files in {folder}"
    rows = []
    for path in paths:
        for field, value in protobuf_fields(path.read_bytes()):
            if field != 1 or not isinstance(value, bytes):
                continue
            item = dict(protobuf_fields(value))
            text, progress, mode = item.get(7, b""), item.get(2, 0), item.get(3, 1)
            if text and mode in (1, 4, 5, 6):
                rows.append((text, progress))
    rows.sort(key=lambda row: row[1])  # Stable segment/element order for ties.
    assert rows
    return rows


def cases():
    rng = random.Random(1743)
    mixed = []
    for i in range(73250):
        text = "相同弹幕" if i % 2 else "".join(chr(0x4e00 + rng.randrange(1000)) for _ in range(12))
        mixed.append((text.encode(), i * 25))
    yield "mixed-window", mixed
    dense = [("".join(chr(0x4e00 + rng.randrange(1000)) for _ in range(12)).encode(), 1000) for _ in range(8000)]
    yield "distinct-flood", dense
    yield "exact-flood", [("相同弹幕".encode(), 1000)] * 8000
    alphabet = "ABCDEFGabcdefg天地玄黄宇宙洪荒你好世界中文测试弹幕😀😂"
    pool = ["".join(rng.choices(alphabet, k=rng.randint(1, 80))) for _ in range(800)]
    variants = ["你好世界", "你号世界", "测试！！", "测试", "Ｈｅｌｌｏ１２３", "Hello123",
                "233", "2333333", "666", "66666666", "!?!", " ", "\0text", "😀😀",
                "abcdef" * 4, "abcdef" * 8, "ABCD", "ABCC", "ABBB", "中文　　弹幕", "中文弹幕"]
    # Deliberately collide modulo-1007 gram keys without sharing actual characters.
    variants += ["".join(chr(ord(c) + 1007 * j) for c in "abcd") for j in range(4)]
    pool += variants
    rows, progress = [], 0
    for i in range(6000):
        if i % 200 == 0:
            progress += rng.choice([0, 29999, 30000, 30001, 60001])
        else:
            progress += rng.choice([0, 1, 25])
        text = pool[rng.randrange(len(pool))]
        rows.append((text.encode(), progress))
    yield "unicode-lengths-expiry", rows
    yield "normalization-cosine-order", [(text.encode(), i // len(variants)) for i, text in enumerate(variants * 20)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--segments", type=Path, help="Also compare downloaded segment-*.bin protobuf fixtures")
    args = parser.parse_args()
    assert args.rounds > 0
    previous = bind(args.reference)
    current = bind(REPO / "Extension/Lib/BilibiliRegex.dll")
    assert previous._handle != current._handle
    report = []
    workloads = list(cases())
    if args.segments:
        workloads.append(("segment-corpus", segment_rows(args.segments)))
    for name, rows in workloads:
        old_ms, new_ms = [], []
        for _ in range(args.rounds):
            old = run(previous, rows)
            new = run(current, rows)
            assert old[:2] == new[:2], f"{name}: merge groups or representatives changed"
            old_ms.append(old[2])
            new_ms.append(new[2])
        entry = dict(case=name, comments=len(rows), groups=len(new[1]),
                     old_ms=round(statistics.median(old_ms), 2),
                     new_ms=round(statistics.median(new_ms), 2))
        report.append(entry)
        print("PASS", json.dumps(entry), flush=True)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
