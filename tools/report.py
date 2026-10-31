#!/usr/bin/env python3
"""tools/report.py <run.log> <report.md> [addon dir...]: turn an engine run log into a short report.
Errors are grouped by message; errors whose stack passes through one of the given addon folders come first."""
import os, re, sys
from collections import Counter, OrderedDict

log, out = sys.argv[1], sys.argv[2]
addons = [os.path.basename(os.path.normpath(a)) for a in sys.argv[3:]]
lines = open(log, encoding="utf-8", errors="replace").read().splitlines()

ERR = re.compile(r"^\[[0-9.]+\] error: (.*)$")
def norm(msg):
    msg = re.sub(r"^[^:]*\.lua:\d+: ", "", msg)
    return re.sub(r"^\.\.\.[^:]*: ", "", msg)

blocks, cur = [], None
for ln in lines:
    m = ERR.match(ln)
    if m:
        cur = {"msg": m.group(1), "stack": []}
        blocks.append(cur)
    elif cur is not None and ln.startswith((" ", "\t")):
        cur["stack"].append(ln.strip())
    else:
        cur = None

def touches_addon(b):
    hay = b["msg"] + " " + " ".join(b["stack"])
    return any(("\\" + a + "\\") in hay or ("/" + a + "/") in hay for a in addons)

ours = [b for b in blocks if touches_addon(b)] if addons else []
theirs = [b for b in blocks if b not in ours]
loaded = sum(1 for ln in lines if " done loading " in ln)
ours_loaded = [a for a in addons if any(ln.endswith("done loading " + a) for ln in lines)]
failed = [ln.split("loading ", 1)[1].split(" failed", 1)[0] for ln in lines if " failed: " in ln and "loading " in ln]

def table(bs, title, limit):
    c = Counter(norm(b["msg"]) for b in bs)
    rows = [f"| {n} | `{m[:150]}` |" for m, n in c.most_common(limit)]
    return [f"### {title} ({len(bs)} errors, {len(c)} distinct)", "", "| count | message |", "|---|---|"] + rows + [""]

def ours_detail(bs):
    rows = []
    for b in bs:
        where = next((s for s in b["stack"] if any(a in s for a in addons)), "")
        where = re.sub(r"^.*?(" + "|".join(map(re.escape, addons)) + r")", r"\1", where)[:120]
        rows.append((where, norm(b["msg"])))
    c = Counter(rows)
    return [f"| {n} | `{w}` | `{m[:110]}` |" for (w, m), n in c.most_common(40)]

md = ["# HogSim run report", "", f"- addons loaded: {loaded} (yours: {', '.join(ours_loaded) or 'none'})",
      f"- load failures: {', '.join(failed) if failed else 'none'}",
      f"- errors: {len(blocks)} total, {len(set(norm(b['msg']) for b in blocks))} distinct", ""]
if addons:
    md += [f"## Errors touching your addon ({len(ours)})", ""]
    if ours:
        md += ["| count | where (first frame in your code) | message |", "|---|---|---|"] + ours_detail(ours) + [""]
    else:
        md += ["None. Your addon adds no errors to the Blizzard-only run.", ""]
md += ["## Blizzard UI / simulator gaps", ""] + table(theirs, "Not your code", 25)
md += ["_A simulator gap is a Blizzard API or behaviour HogSim does not model yet; it is not a bug in your addon._", ""]
open(out, "w", encoding="utf-8").write("\n".join(md))
print(f"report: {len(blocks)} errors, {len(ours)} touching {addons or 'n/a'}")
