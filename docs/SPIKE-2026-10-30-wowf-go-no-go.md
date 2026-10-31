# Spike: a headless WoW: Forever UI engine on wowless — go/no-go (evening 1, 2026-10-30/31)

**Verdict: GO.** The wowless engine, pointed at the live WoW: Forever build, executes Forever's real Blizzard
UI code and loads all 15 HogTron UI addons on top of it, headless, in under a minute, for $0. What remains is
surface work (API stubs, a dozen engine builtins, load order), not unknowns.

## What was built (branch `spike/wowf`, commits 903c72b, 600e5c9, faad9aa)

- `data/products/wowf/`: the Forever product (build 1.60.1.70707, BuildConfig 7feb61f3…, flavor Mainline,
  game Camelot, family Mainline, gametypes mainline+camelot). API/event/global/cvar yamls are a SEED copied
  from the 2022 Mainline product — not Forever's truth yet (see Next).
- `tools/fetch.lua`: modern TOC conventions (`[Family]`/`[Game]` path prefixes, trailing `[AllowLoadGameType …]`
  groups), Blizzard addon enumeration from the community listfile when the build has no
  ManifestInterfaceTOCData (writes `extracts/<product>/manifest.lua`), Bindings.xml by FDID, missing db2 tolerated.
- `wowless/loader.lua`: multi-line `## Dep:` with conditions, Allow/ExcludeLoadGameType on files and addons,
  `[AllowLoad Glue]` skipped (we simulate the game environment), optional deps, manifest.lua, optional
  FrameXML/Bindings, `## LoadFirst` ordering, unknown named XML colors fall back to white instead of killing
  the template.
- `tools/sqlite.lua`: DBD build ranges, nearest same-version layout, newest-layout fallback, unknown tables and
  missing db2 files are warnings.
- Engine builtins Forever provides C-side: `Mixin`, `CreateFromMixins`, `math.clamp/lerp/normalize/round/
  saturate/sign`, `table.indexof/contains/count/isempty/removeunordered/removevalue/keys/values`,
  `GetCurrentEnvironment`, `SwapToGlobalEnvironment`, `import`, `CreateSecureDelegate`, `GetFrameMetatable`,
  `GetFontStringMetatable`, `issecretvalue`.
- Vendor: wowdbdefs → 12.1.5.70688, elune → HEAD (the pinned commit does not compile on gcc 13),
  wow-listfile → HEAD + release CSVs (154 MB each, not in git), luacasc 1.15 → 1.19 (root format v2).
- `tools/probe{,2,3,4,5}_wowf.lua`: read-only CASC probes; every client fact below came from them.

## Numbers (all from logs under `out/wowf/`, copies in `C:/Users/sbilg/Code/forever-sim/out/`)

| Run | Addons loaded | Errors | Distinct | Wall |
|---|---|---|---|---|
| Blizzard UI, first run | 199 / 347 | 1,294 | – | 5.3 s |
| + builtins batch 1 (Mixin…) | 205 | 874 | – | 5.8 s |
| + batch 2 (math/table/env) | 205 | 772 | – | 6.4 s |
| + Glue skip + color fallback | 205 | 2,634 | – | 43 s |
| **+ HogTron UI (15 folders)** | **220 (203 + 15 ours)** | **2,679** | **348** | **48 s** |

The jump to 2,634 is deeper execution, not regression: 1,445 fonts register instead of dying on an undefined
named color, so templates instantiate and OnLoad handlers run. Raw error count is not the metric; distinct
signatures, addons loaded and errors in OUR files are.

- Errors whose origin is a HogTron UI file: **1** (`LibDBIcon-1.0.lua:55` indexes `UIParent`, which the engine
  has not created yet — a Blizzard-side gap). Our code appears in the stacks of ~150 errors, all of them calls
  into client surface the simulator lacks today: `EditModeManagerFrame:IsEditModeActive` (31),
  `GetAttribute` (21), `C_Glue` (94, Blizzard side), `PlaySound`, `DEFAULT_CHAT_FRAME`, `StaticPopup_Hide`.
- `frame0.png` (1280×720): a wireframe of real Forever frames with computed geometry — `MainActionBar`,
  `MicroMenu`, `MinimapCluster.ZoneTextButton`, `GameTimeFrame`, `ChatFrame1–10Tab`,
  `Boss1–5TargetFrame…HealthBarsContainer.HealthBar.*`, `PlayerPowerBarAlt`, a `BasicMessageDialog`. No
  textures yet (BLP/cascproxy not wired). These include the exact renamed frames (`MainActionBar`,
  `HealthBarsContainer`) that cost HogTron UI in-game landmines earlier.
- Fetch: 347 Blizzard addons + 16 db2 files, 51 MB, 20 min first time (CASC cache 308 MB), GlobalStrings 27,399 rows.

## Facts about the Forever client (CASC build 7feb61f3, not from memory)

- Modern UI layout: no `Interface/FrameXML`; `Blizzard_FrameXML`/`_FrameXMLBase`/`_SharedXML` are addons.
  Plain `Blizzard_X.toc` only (retail ships `_Mainline`/`_Standard` variants too).
- TOC syntax: `## Dep: Name [AllowLoadGameType …]` (repeated), file lines with `[AllowLoadGameType a, b]`,
  `[ExcludeLoadGameType …]`, `[AllowLoad Glue|Game]`, `[AllowLoadEnvironment Global]`,
  `[LoadIntoEnvironment secure]`, prefixes `[Family]\X`, `[Game]\X`; headers `## AllowLoadGameType:`,
  `## LoadFirst: 1`, `## AllowLoad: Both`.
- Game type token is **`camelot`** (the crash-report codename); `[Game]` → `Camelot/`, `[Family]` → `Mainline/`;
  Forever satisfies {mainline, camelot}; retail is {mainline, standard}.
- `ManifestInterfaceTOCData.db2` (fdid 1267335) is absent; `GlobalStrings.db2` = fdid 1394440 (WDC5).
- `Mixin`/`CreateFromMixins` and the `math.*`/`table.*` extensions are engine-provided (`Mixin.lua` begins
  `local PrivateCreateFromMixins = CreateFromMixins`; `MathUtil.lua` has `Clamp = math.clamp`).
- `Blizzard_APIDocumentationGenerated` ships in the build: 642 files, 285 `C_*` namespaces, 6,619 functions,
  1,816 events with typed payloads, 772 structures, 900 enumerations. This is Forever's API surface,
  machine-readable, no in-game dump required.

## Remaining buckets (root causes read from the logs)

1. API surface: the 2022 Mainline seed lacks Forever's `Enum.*`/`Constants` (kills TextureUtil → `TextureKitConstants`,
   ColorConstants → `NORMAL_FONT_COLOR_CODE`), namespaces `C_Glue`, `C_InputInterfaceStyle`, `C_CatalogShop`,
   `C_GameRules`, `C_ColorUtil`, `C_CurveUtil`, `C_RestrictedActions`, `C_StoreSecure`, and events
   (`ACCOUNT_MONEY`, `ACCOUNT_CVARS_LOADED` "cannot register"). Fix: `tools/apidoc2yaml` from the shipped docs.
2. Engine builtins still missing: `AddSourceLocationExclude`, `PlaySound`, `RegionalUniqueNamesEnabled`,
   `GetIconForRole`; methods `FontString:SetTextToFit`, `Frame:IsMouseMotionFocus`, `ModelScene:SetAllowOverlappedModels`,
   `Frame:RegisterForInterfaceTransitions`, `GetAttribute` on a non-frame.
3. Load order: we sort Blizzard addons by TOC FDID because the manifest table is gone; the real client order
   differs (`Blizzard_Colors` loads after `Blizzard_Fonts_Shared` for us). Candidate proxy: retail `wow`'s
   ManifestInterfaceTOCData order for shared addons.
4. `UIParent` is never created (6 + our LibDBIcon error) — find why `Blizzard_UIParent` does not create it.
5. Rendering: textures (BLP via `wowless/blp.lua` + cascproxy) and fonts are not drawn; only rect outlines.

## Next (evening 2 of the spike, in order)

1. `tools/apidoc2yaml.lua`: run the 642 doc files in a sandbox (`APIDocumentation:AddDocumentationTable`) →
   `data/products/wowf/{apis,events,globals}.yaml` + `data/api/C_*.yaml` stubs with typed inputs/outputs.
2. Builtins batch 3 (list above) + create `UIParent`.
3. Load-order proxy from retail's manifest; measure distinct signatures again.
4. Run HogTron UI again; first target: 0 errors originating in our files AND a rendered frame with textures.
5. Package: Dockerfile from the upstream devcontainer + the `wowf` product; GitHub Action "test your Forever
   addon"; public repo under Hogtron-Solutions-Tech-Stack (MIT, Ferronn attribution kept). Name: Sean's call.

## Risks and rules

- wowless is pre-alpha upstream (its own README says most errors are the simulator's); we own the fork.
- Blizzard data: downloaded from Blizzard's CDN at build time like the client does; `extracts/`, `cache/`,
  `build/`, `out/` and the listfile CSVs stay out of git. Never redistribute extracts.
- Forever patches move the build: `build.yaml` hash per build; `sqlite.lua` falls back to the nearest layout.
- Windows checkout is CRLF and must never run under Linux; the engine lives in WSL `~/forever-sim`.
- `-e N` (maxerrors) exits 0 early — census and addon runs use `-e 100000000`.

## Cost

$0. About 3.5 h wall (research 23:00–00:00, engine 00:00–02:30), one person, one evening.
