# Eds Custom Addon

WotLK 3.3.5a (`Interface: 30300`) addon for a private AzerothCore / ChromieCraft realm. Modular UI and automation; first module auto-toggles XP so you only gain it in a party or raid with at least one other **online** member.

## Commands

| Command | Effect |
|---------|--------|
| `/eca` / `/eca help` | List commands |
| `/eca ui` | Toggle the feature panel |
| `/eca partyxp on` | Enable auto XP toggle (default) |
| `/eca partyxp off` | Stop auto toggling (does not change current XP flag) |
| `/eca partyxp status` | Module on/off, group kind, desired XP vs server flag |
| `/eca windfury test` | Play the Windfury proc sound |
| `/eca windfury on` / `/eca windfury off` | Enable or disable Windfury sound |
| `/eca windfury sound <path>` | Set a custom `.wav`/`.mp3` (addon folder or `Sound\\...`) |
| `/eca debug` | Toggle debug prints |

## Party XP

XP is turned **on** only when you are in a party or raid and at least one other member is online (`UnitIsConnected`). Solo, an empty party shell, or every other member offline → `.xp disable`.

The addon talks to the server with `addon:SendServerCommand` using `.xp enable` / `.xp disable` (`mod-individual-xp` on this realm). `.xp on` / `.xp off` only print usage and do not change XP. Whisper-to-self so it still works as a ghost. It compares against `IsXPUserDisabled()` so it does not resend the same state.

Login already in a party whose members are offline counts as no online partner → XP stays off until someone comes online.

## Windfury sound

The panel has an edit box for the Windfury sound path (Enter or click away to save) and a **Test** button. Drop your own `.wav` or `.mp3` under the addon folder and paste the path there. Extra hits within 0.15s share one sound.

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
