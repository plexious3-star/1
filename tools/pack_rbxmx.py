"""Pack src/ into Roblox model files you can drag into Studio (no Rojo needed).

    python3 tools/pack_rbxmx.py   ->  build/CurseBody.rbxmx      (ModuleScript tree → ReplicatedStorage)
                                      build/CurseService.rbxmx   (Script → ServerScriptService)
                                      build/CurseClient.rbxmx    (LocalScript → StarterPlayer.StarterPlayerScripts)
"""
import itertools
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build")
_ref = itertools.count()


def cdata(text):
    # "]]>" cannot appear inside CDATA: split it across two sections
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, source=None, children=()):
    props = [f'<string name="Name">{name}</string>']
    if source is not None:
        props.append(f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    body = "".join(children)
    return f'<Item class="{cls}" referent="RBX{next(_ref)}"><Properties>{"".join(props)}</Properties>{body}</Item>'


def tree(path, name):
    if os.path.isdir(path):
        init = os.path.join(path, "init.lua")
        kids = []
        for entry in sorted(os.listdir(path)):
            full = os.path.join(path, entry)
            if entry == "init.lua":
                continue
            if os.path.isdir(full):
                kids.append(tree(full, entry))
            elif entry.endswith(".lua"):
                kids.append(tree(full, entry[:-4]))
        if os.path.exists(init):
            return item("ModuleScript", name, open(init).read(), kids)
        return item("Folder", name, None, kids)
    return item("ModuleScript", name, open(path).read())


def write(filename, xml):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, filename)
    with open(path, "w") as f:
        f.write('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">' + xml + "</roblox>")
    return path


if __name__ == "__main__":
    print(write("CurseBody.rbxmx", tree(os.path.join(ROOT, "src", "shared", "CurseBody"), "CurseBody")))
    print(write("CurseService.rbxmx", item("Script", "CurseService", open(os.path.join(ROOT, "src", "server", "CurseService.server.lua")).read())))
    print(write("CurseClient.rbxmx", item("LocalScript", "CurseClient", open(os.path.join(ROOT, "src", "client", "CurseClient.client.lua")).read())))
