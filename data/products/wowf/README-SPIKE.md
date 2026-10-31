# wowf = WoW: Forever (live client; product code wowf on us.patch.battle.net:1119).
SPIKE SCAFFOLD 2026-10-30: apis/cvars/events/globals.yaml are COPIES of data/products/wow (Mainline 10.0.0, 2022),
chosen because Forever reports WOW_PROJECT_ID=1 and a Midnight-style C_* surface. Seed, not truth: refine by running
addon/Wowless in the real Forever client and feeding WowlessLastTestFailures through tools/errsv.lua.
flavor: provisional until tools/probe_wowf.lua shows which Blizzard_*_<Flavor>.toc names the build ships.
