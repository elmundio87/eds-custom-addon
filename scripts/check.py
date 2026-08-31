"""Lint and offline-test Eds Custom Addon (Lua 5.1 / WotLK, no client)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOC_NAME = "Eds Custom Addon.toc"

BANNED = [
    (r"\bIsInGroup\s*\(", "IsInGroup is MoP+; use GetNumPartyMembers/GetNumRaidMembers"),
    (r"\bIsInRaid\s*\(", "IsInRaid is MoP+; use GetNumRaidMembers"),
    (r"\bGetNumGroupMembers\s*\(", "GetNumGroupMembers is MoP+"),
    (r"\bGROUP_ROSTER_UPDATE\b", "GROUP_ROSTER_UPDATE is MoP+"),
    (r"\bC_Timer\.", "C_Timer is not in 3.3.5"),
    (r'SendChatMessage\s*\(\s*"/xp', "Server XP commands use a dot prefix, not /xp"),
]

def lua_file(rel: str) -> Path:
    return ROOT.joinpath(*rel.replace("\\", "/").split("/"))


def posix(path: Path) -> str:
    return path.resolve().as_posix()


failures = 0


def fail(msg: str) -> None:
    global failures
    failures += 1
    print(f"  FAIL  {msg}")


def ok(msg: str) -> None:
    print(f"  PASS  {msg}")


def toc_lua_files() -> list[str]:
    toc = ROOT / TOC_NAME
    if not toc.exists():
        fail(f"missing {TOC_NAME}")
        return []
    files = []
    for line in toc.read_text(encoding="utf-8").splitlines():
        raw = line.strip()
        if raw.lower().endswith(".lua") and not raw.startswith("#"):
            files.append(raw.replace("\\", "/"))
    return files


def lint_toc() -> None:
    print("lint: toc")
    toc = ROOT / TOC_NAME
    text = toc.read_text(encoding="utf-8")
    if "## Interface: 30300" in text:
        ok("Interface 30300")
    else:
        fail("TOC must declare ## Interface: 30300")
    if "SavedVariablesPerCharacter: EdsCustomAddonDB" in text:
        ok("SavedVariablesPerCharacter declared")
    else:
        fail("missing SavedVariablesPerCharacter")

    files = toc_lua_files()
    expected = [
        "Core/Util.lua",
        "Core/Config.lua",
        "Core/Core.lua",
        "Core/UI.lua",
        "Modules/PartyXP/PartyXP.lua",
    ]
    if files == expected:
        ok("TOC load order")
    else:
        fail(f"TOC load order {files} != {expected}")

    for rel in files:
        path = lua_file(rel)
        if path.exists():
            ok(f"exists {rel}")
        else:
            fail(f"missing {rel}")


def lint_lua_static() -> None:
    print("lint: static")
    for rel in toc_lua_files():
        path = lua_file(rel)
        text = path.read_text(encoding="utf-8")
        if "\t" in text:
            fail(f"{rel} contains tabs")
        else:
            ok(f"{rel} no tabs")
        for i, line in enumerate(text.splitlines(), 1):
            stripped = line.split("--", 1)[0]
            for pattern, reason in BANNED:
                if re.search(pattern, stripped):
                    fail(f"{rel}:{i}: {reason}")
    ui = (ROOT / "Core" / "UI.lua").read_text(encoding="utf-8")
    if "RegisterModule" in ui:
        fail("Core/UI.lua must not RegisterModule (panel is not a feature module)")
    else:
        ok("UI.lua is not a feature module")
    party = (ROOT / "Modules" / "PartyXP" / "PartyXP.lua").read_text(encoding="utf-8")
    if "RegisterModule" in party:
        ok("PartyXP registers itself")
    else:
        fail("PartyXP.lua does not call RegisterModule")


def lint_syntax(lua) -> None:
    print("lint: syntax")
    for rel in toc_lua_files():
        path = posix(lua_file(rel))
        try:
            lua.execute(f'assert(loadfile("{path}"))')
            ok(f"syntax {rel}")
        except Exception as exc:
            fail(f"syntax {rel}: {exc}")


def load_addon(lua, env_path: Path) -> None:
    lua.eval("dofile")(posix(env_path))
    for rel in toc_lua_files():
        lua.eval("dofile")(posix(lua_file(rel)))


def fire_loaded(lua) -> None:
    addon = lua.eval("EdsCustomAddon")
    addon.OnEvent(addon, "ADDON_LOADED", "Eds Custom Addon")


def last_sent(lua) -> list[str]:
    sent = lua.eval("wow.sent")
    return [sent[i] for i in range(1, len(sent) + 1)]


def last_prints(lua) -> list[str]:
    prints = lua.eval("wow.prints")
    return [prints[i] for i in range(1, len(prints) + 1)]


def test_addon(lua) -> None:
    print("test: load + behavior")
    addon = lua.eval("EdsCustomAddon")
    wow = lua.eval("wow")

    fire_loaded(lua)
    if addon.loaded:
        ok("ADDON_LOADED initializes addon")
    else:
        fail("ADDON_LOADED did not set loaded")

    party = addon.GetModule(addon, "PartyXP")
    if party is None:
        fail("PartyXP not registered")
        return
    ok("PartyXP registered")

    if party.enabled:
        ok("PartyXP enabled by default")
    else:
        fail("PartyXP should default to enabled")

    if addon.ui is None:
        fail("CreateUI did not run")
    else:
        ok("ECA_Panel created")
        if addon.ui.shown:
            fail("panel should start hidden")
        else:
            ok("panel starts hidden")

    wow.resetChat()
    wow.setSolo()
    wow.state.xpDisabled = False
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == [".xp off"]:
        ok("solo sends .xp off")
    else:
        fail(f"solo sent {sent}, expected ['.xp off']")

    wow.resetChat()
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == []:
        ok("solo idempotent (no second .xp off)")
    else:
        fail(f"solo second sync sent {sent}")

    wow.resetChat()
    wow.setParty(True)
    wow.state.xpDisabled = True
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == [".xp on"]:
        ok("online party member sends .xp on")
    else:
        fail(f"online party sent {sent}, expected ['.xp on']")

    wow.resetChat()
    wow.setParty(False)
    wow.state.xpDisabled = False
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == [".xp off"]:
        ok("offline-only party sends .xp off")
    else:
        fail(f"offline party sent {sent}, expected ['.xp off']")

    wow.resetChat()
    wow.setRaidSelfOnly()
    wow.state.xpDisabled = False
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == [".xp off"]:
        ok("raid of self only sends .xp off")
    else:
        fail(f"raid-self sent {sent}, expected ['.xp off']")

    wow.resetChat()
    wow.setRaidWithPartner(True)
    wow.state.xpDisabled = True
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == [".xp on"]:
        ok("raid with online partner sends .xp on")
    else:
        fail(f"raid-partner sent {sent}, expected ['.xp on']")

    wow.resetChat()
    wow.setRaidWithPartner(False)
    wow.state.xpDisabled = False
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == [".xp off"]:
        ok("raid partner offline sends .xp off")
    else:
        fail(f"raid-offline-partner sent {sent}, expected ['.xp off']")

    addon.DisableModule(addon, "PartyXP")
    if not party.enabled:
        ok("DisableModule turns PartyXP off")
    else:
        fail("DisableModule left PartyXP enabled")
    wow.resetChat()
    wow.setParty(True)
    wow.state.xpDisabled = True
    party.SyncXP(party)
    sent = last_sent(lua)
    if sent == []:
        ok("disabled module does not send .xp")
    else:
        fail(f"disabled module sent {sent}")

    addon.EnableModule(addon, "partyxp")
    if party.enabled:
        ok("EnableModule is case-insensitive")
    else:
        fail("GetModule/EnableModule failed for 'partyxp'")

    wow.resetChat()
    wow.setSolo()
    wow.state.xpDisabled = False
    party.RequestSync(party)
    sent = last_sent(lua)
    if sent == []:
        ok("RequestSync is debounced (no immediate send)")
    else:
        fail(f"debounced sync sent immediately: {sent}")
    wow.flushDebounce()
    sent = last_sent(lua)
    if sent == [".xp off"]:
        ok("debounce fires after 0.2s")
    else:
        fail(f"after tick sent {sent}, expected ['.xp off']")

    wow.resetChat()
    wow.setSolo()
    wow.state.xpDisabled = False
    party.RequestSync(party)
    party.RequestSync(party)
    wow.flushDebounce()
    sent = last_sent(lua)
    if sent == [".xp off"]:
        ok("burst RequestSync sends once")
    else:
        fail(f"burst debounce sent {sent}")

    db = lua.eval("EdsCustomAddonDB")
    if db.modules.PartyXP.enabled:
        ok("enabled state persisted to SavedVariables")
    else:
        fail("db.modules.PartyXP.enabled not true after EnableModule")

    addon.SlashHandler(addon, "debug")
    if addon.db.debug:
        ok("slash debug enables db.debug")
    else:
        fail("slash debug did not toggle on")

    shown_before = bool(addon.ui.shown)
    addon.SlashHandler(addon, "ui")
    if bool(addon.ui.shown) != shown_before:
        ok("slash ui toggles panel")
    else:
        fail("slash ui did not toggle panel visibility")
    addon.SlashHandler(addon, "ui")
    if bool(addon.ui.shown) == shown_before:
        ok("slash ui toggles panel back")
    else:
        fail("slash ui second toggle did not restore visibility")

    wow.resetChat()
    addon.SlashHandler(addon, "partyxp status")
    prints = last_prints(lua)
    if prints and "PartyXP" in prints[-1]:
        ok("slash partyxp status prints")
    else:
        fail(f"status prints {prints}")

    wow.resetChat()
    addon.SlashHandler(addon, "nope")
    prints = last_prints(lua)
    if prints and "unknown command" in prints[-1]:
        ok("unknown slash is reported")
    else:
        fail(f"unknown command prints {prints}")

    # Wrong ADDON_LOADED name is ignored after first load (already loaded).
    # Fresh check: config merge keeps user debug=true and fills ui defaults.
    lua.execute("EdsCustomAddonDB = { debug = true, modules = { PartyXP = { enabled = false } } }")
    lua.execute("EdsCustomAddon.loaded = false")
    lua.execute("EdsCustomAddon.ui = nil")
    lua.execute("EdsCustomAddon.modules = {}")
    lua.execute("EdsCustomAddon.moduleOrder = {}")
    # Re-register by reloading PartyXP only would duplicate; instead call LoadConfig.
    addon.LoadConfig(addon)
    db = lua.eval("EdsCustomAddonDB")
    if db.debug:
        ok("config merge keeps existing debug=true")
    else:
        fail("config merge overwrote debug")
    if db.ui is not None and db.ui.point == "CENTER":
        ok("config merge fills missing ui defaults")
    else:
        fail("config merge did not add ui defaults")
    if not db.modules.PartyXP.enabled:
        ok("config merge keeps PartyXP.enabled=false")
    else:
        fail("config merge overwrote PartyXP.enabled")


def main() -> int:
    try:
        from lupa import LuaRuntime
    except ImportError:
        print("lupa is required: pip install lupa")
        return 2

    print(f"root: {ROOT}")
    lint_toc()
    lint_lua_static()

    lua = LuaRuntime()
    lint_syntax(lua)
    load_addon(lua, ROOT / "scripts" / "wow_env.lua")
    test_addon(lua)

    print()
    if failures:
        print(f"{failures} failure(s)")
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
