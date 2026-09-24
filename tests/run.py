"""Run the CurseBody framework headless under the Roblox mock and render what it builds.

    python3 tests/run.py            # tests + previews/curse/*.png
    python3 tests/run.py --no-render
    python3 tests/run.py --only CrimsonHusk,Behemoth

Needs the `luau` CLI on PATH (or LUAU=/path/to/luau) plus numpy + Pillow for renders.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src", "shared", "CurseBody")
BUILD = os.path.join(ROOT, "tests", ".build")


def lua_tree(path, name):
    """Instance tree literal for a Rojo folder (init.lua = the folder's own module)."""
    children, fn = [], None
    if os.path.isdir(path):
        init = os.path.join(path, "init.lua")
        if os.path.exists(init):
            fn = open(init).read()
        for entry in sorted(os.listdir(path)):
            full = os.path.join(path, entry)
            if entry == "init.lua":
                continue
            if os.path.isdir(full):
                children.append(lua_tree(full, entry))
            elif entry.endswith(".lua"):
                children.append(lua_tree(full, entry[:-4]))
    else:
        fn = open(path).read()
    parts = [f'name = "{name}"']
    if fn is not None:
        parts.append("fn = function(script, require)\n" + fn + "\nend")
    if children:
        parts.append("children = {\n" + ",\n".join(children) + "\n}")
    return "{" + ",\n".join(parts) + "}"


def bundle():
    os.makedirs(BUILD, exist_ok=True)
    mock = open(os.path.join(ROOT, "tests", "mock", "roblox.luau")).read()
    tests = open(os.path.join(ROOT, "tests", "test_main.luau")).read()
    out = ("MOCK = (function()\n" + mock + "\nend)()\n"
           + "BUNDLE_TREE = " + lua_tree(SRC, "CurseBody") + "\n"
           + tests)
    path = os.path.join(BUILD, "run.luau")
    open(path, "w").write(out)
    return path


def main():
    luau = os.environ.get("LUAU", "luau")
    path = bundle()
    proc = subprocess.run([luau, path], capture_output=True, text=True)
    dumps, failed, result = {}, False, None
    for line in proc.stdout.splitlines():
        kind, _, rest = line.partition("\t")
        if kind == "DUMP":
            name, _, payload = rest.partition("\t")
            dumps[name] = json.loads(payload)
        elif kind in ("FAIL", "INFO"):
            print(line)
            failed |= kind == "FAIL"
        elif kind == "RESULT":
            result = rest
        else:
            print(line)
    if proc.returncode != 0 or result is None:
        print(proc.stderr)
        print("luau run crashed")
        sys.exit(1)
    print("RESULT", result)
    if "--no-render" not in sys.argv:
        sys.path.insert(0, os.path.join(ROOT, "tests"))
        from render import render_all
        if "--only" in sys.argv:
            keep = sys.argv[sys.argv.index("--only") + 1].split(",")
            dumps = {k: v for k, v in dumps.items() if k.split("_")[0] in keep}
        render_all(dumps, os.path.join(ROOT, "previews", "curse"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
