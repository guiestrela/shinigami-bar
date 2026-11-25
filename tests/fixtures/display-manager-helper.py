#!/usr/bin/env python3
"""Isolated stand-in for the Shinigami display apply/guard helpers.

It implements only the documented controller protocol and keeps all state in a
fixture-private file. Production helpers are never started by this fixture.
"""
import copy
import json
import os
from pathlib import Path
import sys


STATE = Path(os.environ["SHINIGAMI_DISPLAY_FIXTURE_STATE"])
TOKEN = "11111111111111111111111111111111"


def load():
    if not STATE.exists():
        return {
            "monitors": [
                {
                    "name": "eDP-1", "description": "Built-in", "x": 0, "y": 0,
                    "width": 1920, "height": 1080, "scale": 1, "transform": 0,
                    "refreshRate": 60, "focused": True, "disabled": False,
                    "mirrorOf": "none",
                    "availableModes": ["1920x1080@60", "1280x720@60"],
                },
                {
                    "name": "DP-1", "description": "External", "x": 1920, "y": 0,
                    "width": 2560, "height": 1440, "scale": 1.25, "transform": 0,
                    "refreshRate": 60, "focused": False, "disabled": False,
                    "mirrorOf": "none",
                    "availableModes": ["2560x1440@60", "1920x1080@60"],
                },
            ],
            "brightness": {"eDP-1": 64, "DP-1": 70},
            "textSize": 12,
            "bindings": {
                "1": "eDP-1", "2": "DP-1", "3": "eDP-1", "4": "DP-1",
                "5": "eDP-1", "6": "DP-1", "7": "eDP-1", "8": "DP-1",
                "9": "eDP-1", "10": "DP-1",
            },
            "overrides": {"2": "DP-1", "4": "DP-1"},
            "guard": {"token": TOKEN, "status": "idle", "before": []},
            "actions": [],
        }
    return json.loads(STATE.read_text(encoding="utf-8"))


def save(state):
    STATE.write_text(json.dumps(state, separators=(",", ":")), encoding="utf-8")


def apply_layout(state, args):
    action = args[args.index("--action") + 1]
    if action == "brightness":
        name = args[args.index("--monitor") + 1]
        state["brightness"][name] = int(args[args.index("--percent") + 1])
        return "Brightness updated and verified"
    if action == "text-size":
        state["textSize"] = int(args[args.index("--size") + 1])
        return "Text size updated"
    if action == "monitors":
        return json.dumps(state["monitors"], separators=(",", ":"))
    if action == "brightness-state":
        name = args[args.index("--monitor") + 1]
        return json.dumps({"monitor": name, "percent": state["brightness"][name]},
                          separators=(",", ":"))
    if action == "workspace-state":
        return json.dumps({"bindings": state["bindings"], "overrides": state["overrides"]},
                          separators=(",", ":"))
    if action == "preview":
        payload = json.loads(args[args.index("--payload") + 1])
        by_name = {item["name"]: item for item in state["monitors"]}
        for entry in payload["monitors"]:
            item = by_name.get(entry["output"])
            if not item:
                continue
            item["disabled"] = bool(entry.get("disabled", False))
            item["mirrorOf"] = entry.get("mirror") or "none"
            item["scale"] = float(entry["scale"])
            item["transform"] = int(entry["transform"])
            position = str(entry.get("position", "0x0")).split("x")
            item["x"] = int(position[0])
            item["y"] = int(position[1])
            mode = str(entry.get("mode", "")).split("@")
            geometry = mode[0].split("x")
            if len(geometry) == 2 and geometry[0].isdigit() and geometry[1].isdigit():
                item["width"] = int(geometry[0])
                item["height"] = int(geometry[1])
            if len(mode) == 2:
                item["refreshRate"] = float(mode[1])
        return "Display preview applied"
    if action in ("monitor", "disable"):
        name = args[args.index("--monitor") + 1]
        item = next((value for value in state["monitors"] if value["name"] == name), None)
        if not item:
            raise ValueError("Unknown monitor")
        if action == "disable":
            item["disabled"] = True
        else:
            item["disabled"] = False
            item["mirrorOf"] = "none"
            item["scale"] = float(args[args.index("--scale") + 1])
            item["transform"] = int(args[args.index("--transform") + 1])
            item["x"] = int(args[args.index("--x") + 1])
            item["y"] = int(args[args.index("--y") + 1])
            item["mirrorOf"] = args[args.index("--mirror") + 1]
            mode = str(args[args.index("--mode") + 1]).split("@")
            geometry = mode[0].split("x")
            if len(geometry) == 2 and geometry[0].isdigit() and geometry[1].isdigit():
                item["width"] = int(geometry[0])
                item["height"] = int(geometry[1])
            if len(mode) == 2:
                item["refreshRate"] = float(mode[1])
        return "Display action applied"
    if action == "workspaces":
        payload = json.loads(args[args.index("--payload") + 1])
        for entry in payload:
            state["bindings"][str(entry["workspace"])] = entry["monitor"]
        return "Workspace assignments applied and verified"
    if action == "save":
        payload = json.loads(args[args.index("--payload") + 1])
        for entry in payload.get("workspaces", []):
            state["bindings"][str(entry["workspace"])] = entry["monitor"]
        for key in list(state["overrides"]):
            if key not in payload.get("workspaces", []):
                continue
            state["overrides"][key] = next(
                entry["monitor"] for entry in payload["workspaces"]
                if str(entry["workspace"]) == key)
        return "Layout saved"
    raise ValueError("Unsupported fixture action: " + action)


def guard(state, args):
    command = args[0]
    if command == "--apply":
        payload = json.loads(args[1])
        state["actions"].append(payload)
        state["guard"] = {
            "token": TOKEN, "status": "pending", "before": copy.deepcopy(state["monitors"]),
        }
        apply_layout(state, payload)
        save(state)
        return {"token": TOKEN, "status": "pending", "remaining": 15, "error": ""}
    token = args[1]
    if token != TOKEN:
        raise ValueError("Invalid fixture token")
    if command == "--status":
        return {"token": token, "status": state["guard"]["status"], "remaining": 15,
                "error": ""}
    if command == "--confirm":
        state["guard"]["status"] = "confirmed"
    elif command == "--revert":
        state["monitors"] = state["guard"]["before"]
        state["guard"]["status"] = "reverted"
    else:
        raise ValueError("Unsupported fixture guard command")
    save(state)
    return {"token": token, "status": state["guard"]["status"], "remaining": 0,
            "error": ""}


def main():
    state = load()
    args = sys.argv[1:]
    try:
        if args[:1] == ["--action"]:
            print(apply_layout(state, args))
        else:
            print(json.dumps(guard(state, args), separators=(",", ":")))
        save(state)
        return 0
    except Exception as error:
        print("Fixture helper error: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
