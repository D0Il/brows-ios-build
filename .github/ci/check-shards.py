#!/usr/bin/env python3
"""The shard plan must be a partition of the real test methods.

A subset typo would silently drop a test from CI — the one failure mode
sharding introduces. This compares the plan against the methods the test
class actually declares, so a run fails before any shard starts.
"""
import json
import os
import re
import sys

ROOT = os.environ.get("GITHUB_WORKSPACE") or os.getcwd()
source = open(os.path.join(ROOT, "ios/Brows/BrowsUITests/BrowsUITests.swift"), encoding="utf-8").read()
declared = set(re.findall(r"func (test[A-Za-z_0-9]+)\(", source))

with open(os.path.join(ROOT, ".github/ci/shards.json"), encoding="utf-8") as handle:
    plan = json.load(handle)

flat = [name for shard in plan.values() for name in shard]
duplicates = sorted({n for n in flat if flat.count(n) > 1})
missing = sorted(declared - set(flat))
extra = sorted(set(flat) - declared)

print(f"{len(declared)} methods declared; {len(flat)} planned across {len(plan)} shards")
for shard, names in sorted(plan.items()):
    print(f"  shard {shard}: {len(names)}")
if not all(plan.values()):
    print("an empty shard would leave a runner with nothing to run")
if duplicates or missing or extra:
    print(f"duplicates={duplicates} missing={missing} unknown={extra}")
    sys.exit(1)
print("plan covers every method exactly once")
