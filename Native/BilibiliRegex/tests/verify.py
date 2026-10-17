"""Generate a V8 oracle corpus and run the x64 native DLL test executable.

Usage: python tests/verify.py [--log path-to-diagnostic-log] [--node node.exe]
Build verify.exe with build.ps1 before running this.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]


def corpus():
    texts = ["", "foo", "FOO", "foobar", "barfoo", "foo42", "前123", "前", "中", "中文", "文", "😀",
             "中中", "aaa", "aaab", "abab", "ab", "a", "b", "a\nb", "x\nfoo\ny", "\n", "\r\n",
             "\u2028", "\u2029", "a\0b", "0", "ſ", "K", "Σςσ", "关上世界的大门", "3分钟前", "/foo/u", "/foo/ii"]
    patterns = ["", "foo", "^.$", "^..$", ".*拜年.*", ".*新年.*", ".*元旦.*", ".*2017.*", ".*鬼看条.*",
                ".*进度条.*", ".*大学.*", ".*下雪.*", ".*分钟前", "关上.*的大门", "前[0-9]*$", "[中文]", "[😀]",
                "😀+", "^😀+$", "[^中]", "(?<=foo)bar", "(?<!foo)bar", "foo(?=bar)", "foo(?!bar)",
                r"(中)\1", r"(a|(b))+\2", r"\u4e2d", r"\uD83D\uDE00", r"\u{1F600}",
                r"\p{L}+", r"\w+", r"\s+", r"\bfoo\b", "(?<word>中)\\k<word>", "(?:(a)|(b))+$",
                "a.*b", "a.*?b", "^foo$", "[", "(", "a{2,1}", "(?i)foo", "a\0b", "\\\0", r"\8",
                r"[a-z&&[^aeiou]]", r"[\q{ab|中}]", r"[\p{ASCII}--[A-Z]]"]
    flags = ["", "i", "m", "g", "u", "iu", "s", "y", "d", "v"]
    rows = [dict(mode="pattern", pattern=p, flags=f, text=t)
            for p in patterns for f in flags for t in texts]
    rules = [".*拜年.*", "/foo/", "/foo/i", "/foo/g", "/foo/mig", "/foo/ii", "/foo/u", "/foo/igmi",
             "//", "///", "/[/", "/a/b/i", "/a\nb/i", "/a\u2028b/i", "/foo/i\n", "/foo/i\r\n",
             "(?<=foo)bar", r"(中)\1", "/😀+/g", "/^.$/", "/^foo$/m", "/foo/i\0", "/\0/g"]
    rows.extend(dict(mode="rule", pattern=p, flags="", text=t) for p in rules for t in texts)
    long_text = "另外1743位小伙伴你们好啊" + "←↖↑↗→↘↓↙" * 30
    for p in patterns[4:13]:
        rows.append(dict(mode="rule", pattern=p, flags="", text=long_text))
    for bad_flags in ["ii", "uv", "gg", "z", "imsugydvv"]:
        rows.append(dict(mode="pattern", pattern="foo", flags=bad_flags, text="foo"))
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path)
    parser.add_argument("--node", default=shutil.which("node"))
    args = parser.parse_args()
    if not args.node:
        parser.error("Node.js is needed only to generate the V8 reference results")
    upstream = json.loads((ROOT / "vendor/quickjs-ng/UPSTREAM.json").read_text())
    for name, digest in upstream["sha256"].items():
        assert hashlib.sha256((ROOT / "vendor/quickjs-ng" / name).read_bytes()).hexdigest() == digest, name
    rows = corpus()
    log_count = 0
    if args.log:
        entries = re.findall(r"pattern_begin\n(.*?)\npattern_end\ncontent_begin\n(.*?)\ncontent_end",
                             args.log.read_text(encoding="utf-8-sig"), re.S)
        log_count = len(entries)
        assert log_count, "No diagnostic cases found"
        rows.extend(dict(mode="rule", pattern=p, flags="", text=t) for p, t in entries)
    oracle = subprocess.run([args.node, str(ROOT / "tests/reference.cjs")],
                            input=json.dumps(rows, ensure_ascii=False), text=True, encoding="utf-8",
                            capture_output=True, check=True, timeout=60)
    expected = json.loads(oracle.stdout)
    output = ROOT / "build/v8-vectors.bin"
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as stream:
        stream.write(b"BRX1" + struct.pack("<I", len(rows)))
        for row, result in zip(rows, expected["results"], strict=True):
            parts = [row["pattern"].encode(), row["flags"].encode(), row["text"].encode()]
            stream.write(struct.pack("<IIIIi", row["mode"] == "rule", *(len(x) for x in parts), result))
            for part in parts:
                stream.write(part)
    dll = REPO / "Extension/Lib/BilibiliRegex.dll"
    result = subprocess.run([str(ROOT / "build/x64/verify.exe"), str(dll), str(output)],
                            capture_output=True, text=True, encoding="utf-8", timeout=90)
    print(result.stdout, end="")
    if result.returncode:
        print(result.stderr)
        raise SystemExit(result.returncode)
    report = {"cases": len(rows), "actual_log_cases": log_count, "node": expected["node"],
              "v8": expected["v8"], "upstream": upstream["commit"], "result": "PASS"}
    (ROOT / "build/verification.json").write_text(json.dumps(report, indent=2) + "\n")
    manifest_path = REPO / "Extension/Lib/BilibiliRegex.manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    assert manifest["artifacts"][0]["sha256"] == hashlib.sha256(dll.read_bytes()).hexdigest()
    manifest["verification"] = report
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
