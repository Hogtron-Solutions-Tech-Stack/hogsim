# HogSim

**Headless WoW: Forever UI simulator by HogTron.** Runs Blizzard's real Forever interface code plus your addon
outside the game, reports every Lua error with a stack, and renders frames to PNG — no client, no login, no
loading screens. Built for CI: test a Forever addon on every push.

Status: **pre-alpha spike** (2026-10-31). The engine loads 203 Blizzard addons from the live Forever build and
all 15 HogTron UI modules; the API surface is still being filled in from the client's own API documentation.
Read the honest numbers in `docs/SPIKE-2026-10-30-wowf-go-no-go.md`.

HogSim is based on [wowless](https://github.com/ferronn-dev/wowless) by Ferronn (MIT) — a headless WoW client
Lua and FrameXML interpreter — extended for the WoW: Forever client (product `wowf`). See `NOTICE`.

## What it does today

- Fetches the Forever build's interface code and client databases straight from Blizzard's CDN (CASC), the
  way the game client does. Nothing from Blizzard is redistributed; `extracts/` and `cache/` never enter git.
- Understands the modern Blizzard TOC conventions this client ships: `## Dep:` lines with
  `[AllowLoadGameType …]`, `[Family]`/`[Game]` path prefixes, `[AllowLoad Glue]`, `## LoadFirst`.
- Loads Blizzard's UI, then your addon folders (`--addondir`), fires the login event sequence, and logs every
  error with a traceback.
- Dumps the frame tree with computed geometry (`--frame0`) and renders it to PNG.

## Quick start (Linux or WSL2 Ubuntu 24.04)

```bash
sudo apt-get install build-essential cmake ninja-build lua5.1 liblua5.1-0-dev luarocks libexpat1-dev \
  libmagickwand-dev libreadline-dev libssl-dev libyaml-dev libzip-dev libsqlite3-dev zlib1g-dev ruby
git clone --recurse-submodules https://github.com/Hogtron-Solutions-Tech-Stack/hogsim.git && cd hogsim
# the listfile is published as release assets, not in the submodule
curl -L -o vendor/listfile/community-listfile.csv \
  https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv
curl -L -o vendor/listfile/community-listfile-withcapitals.csv \
  https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile-withcapitals.csv
luarocks config lua_version 5.1 && luarocks build --deps-only wowless-scm-0.rockspec && luarocks install luacasc 1.19
lua tools/mkninja.lua && ninja wowf            # first run fetches the build from the CDN (~20 min, cached after)
vendor/elune/build/linux/bin/Release/lua5.1 wowless.lua -p wowf -e 100000000 -a /path/to/YourAddon > out/wowf/run.log
ninja out/wowf/frame0.png
```

Windows: run it inside WSL. A Windows checkout is CRLF and will not run under Linux.

## Roadmap

1. API surface from `Blizzard_APIDocumentationGenerated` (285 `C_*` namespaces, 1,816 events, 900 enums).
2. Remaining engine builtins, `UIParent`, Blizzard load order.
3. Scenario presets: solo, 5-player dungeon in combat, 20-player raid.
4. Textures and fonts in renders.
5. Docker image + GitHub Action: "test your Forever addon in CI".

## License

MIT. HogSim is an unofficial fan project and is not affiliated with or endorsed by Blizzard Entertainment.
World of Warcraft is a trademark of Blizzard Entertainment, Inc.

Built by [HogTron Solutions](https://hogtron-solutions.com) · Relentless Effort. Automated Precision.
