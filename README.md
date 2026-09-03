# Eds Custom Addon

WotLK 3.3.5a (`Interface: 30300`) addon for a private AzerothCore / ChromieCraft realm. Modular UI and automation; first module auto-toggles XP so you only gain it in a party or raid with at least one other **online** member.

## Commands

| Command | Effect |
|---------|--------|
| `/eca` / `/eca help` | List commands |
| `/eca ui` | Toggle the feature panel |
| `/eca partyxp on` | Enable auto XP toggle (default) |
| `/eca partyxp off` | Stop auto toggling (does not change current XP flag) |
| `/eca partyxp pause` | Hold XP off regardless of party (macro-friendly) |
| `/eca partyxp unpause` | Release hold; sync XP to party state again |
| `/eca partyxp force` | Force XP on for this session (until `/reload` or unforce) |
| `/eca partyxp unforce` | Release force; sync XP to party state again |
| `/eca partyxp status` | Module on/off, paused, force, group, desired XP vs server flag |
| `/eca windfury test` | Play the Windfury proc sound |
| `/eca windfury on` / `/eca windfury off` | Enable or disable Windfury sound |
| `/eca windfury sound <path>` | Set a custom `.wav`/`.mp3` (addon folder or `Sound\\...`) |
| `/eca debug` | Toggle debug prints |

## Party XP

XP is turned **on** only when you are in a party or raid and at least one other member is online (`UnitIsConnected`). Solo, an empty party shell, or every other member offline → `.xp disable`.

Use `/eca partyxp pause` to force XP off even in a party (persists across `/reload` until `/eca partyxp unpause`). Same toggle is on the `/eca ui` panel: **Hold XP off (ignore party)**.

Use **Force XP on (this session)** on the panel (or `/eca partyxp force`) to turn XP on while solo or with offline party members. It clears after `/reload` or when you uncheck it / run `/eca partyxp unforce`. Pause and force are mutually exclusive.

The addon talks to the server with `addon:SendServerCommand` using `.xp enable` / `.xp disable` (`mod-individual-xp` on this realm). `.xp on` / `.xp off` only print usage and do not change XP. Whisper-to-self so it still works as a ghost. It compares against `IsXPUserDisabled()` so it does not resend the same state.

Login already in a party whose members are offline counts as no online partner → XP stays off until someone comes online.

## Windfury proc

When Windfury Weapon is missing, a **RECAST WINDFURY** badge appears (dual-wield checks both hands; two-handers only main hand; ignored while holding a fishing pole). With Windfury active, scrolling combat text warns **1 minute before expiry**. Enable **Move RECAST WINDFURY badge** on `/eca ui` to drag it; position saves per character. Font size on the panel adjusts badge text (8–32).

The panel has **Test proc** (random shuffle + combat text; pick **Default**, **Low HP**, or **Kill** pool beside the button), a scrollable sound name list (click to select), and **Test sound** to preview the selection. An optional sound path is used only when `Sounds/` has no `.wav`/`.mp3`.

**Sound prefixes** (filename stem, case-insensitive):

- `kill-` — plays only when a Windfury hit gets the killing blow (`overkill > 0` in combat log)
- `lowhp-` — plays when the target is below 20% HP before the hit (**current target only**)
- no prefix — default proc pool

Each pool shuffles independently (queue size is `pool size - 1`, capped at 10). Empty `kill-`/`lowhp-` pools fall back to default. Drop files in `Sounds/` — after adding or removing sounds, run `make lint` to regenerate `Sounds/manifest.lua` (WoW cannot scan folders at runtime). Lint also records each clip’s duration so only one sound plays at a time (new procs skip until the current clip ends); a **kill** sound can override a non-kill clip still playing (the two may overlap). Extra hits within 0.15s share one sound and one floating combat text pop. Procs within 5s of the last one show **WINDFURY x2**, **x3**, and so on (including repeated `/eca windfury test` for preview); each streak update replaces the previous WINDFURY pop instead of stacking. WINDFURY text uses Blizzard's crit zoom-in at a fixed spot above the default anchor (tweak `TEXT_Y_OFFSET` in `Windfury.lua`). Requires Interface → Combat → **Floating Combat Text** enabled. `/eca debug` traces CLEU match, throttle skips, `PlaySoundFile` path, and combat text.

## Panel

`/eca ui` opens a small draggable panel (Esc to close). Each registered module gets a checkbox; **Debug** is on the same panel. Position is saved per character. There is no minimap button yet.

## Layout

```
Eds Custom Addon.toc    # name matches the folder (required by the client)
Core/                   # bootstrap, config, /eca
Modules/PartyXP/        # first feature
docs/api/               # 3.3.5 event/roster/command cache
.cursor/skills/         # project skills for later modules
```

## Make

```
make setup      # pip install lupa + validate TOC
make validate
make lint       # syntax + 3.3.5 API lint + mocked unit tests
make test       # same as lint
make package    # dist/EdsCustomAddon.zip (game files only)
make clean
make run        # print in-game command reminder
```

Without GNU Make:

```
python -m pip install -r scripts/requirements-dev.txt
python scripts/check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tasks.ps1 -Task validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tasks.ps1 -Task package
```

CI runs `python scripts/check.py` on every push/PR to `main` (GitHub Actions). Tests load the real Lua files against a stub 3.3.5 API; they do not need the WoW client.

## In-game checks

1. Solo login → `.xp disable` (status: `wantXP=off`, `serverXP=off`).
2. Join a party with an online member → `.xp enable`.
3. That member goes offline → `.xp disable`.
4. Login already in a party, others offline → `.xp disable` after `PLAYER_ENTERING_WORLD`.
5. Raid with one other online member → `.xp enable`.
6. `/eca partyxp off` → no further auto toggle.
7. `/reload` → no extra `.xp` if the flag already matches.

## Adding a module

See `.cursor/skills/wow-addon-structure/`. Register a table `{ name, title, tooltip, Init, Enable, Disable, OnEvent, Slash }` and append the Lua file to the TOC. It shows up on `/eca ui` automatically.
