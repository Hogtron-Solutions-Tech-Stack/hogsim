# Using HogSim

HogSim loads Blizzard's real WoW: Forever interface code and your addon folders into a headless engine, fires the
login event sequence, and tells you what broke — with the errors that touch **your** code listed first.

## 1. GitHub Action (recommended)

```yaml
# .github/workflows/hogsim.yml in your addon repo
name: hogsim
on: [push, pull_request]
jobs:
  sim:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Hogtron-Solutions-Tech-Stack/hogsim@main
        with:
          addon: MyAddon MyAddon_Options     # folders in your repo, space separated
```

The first run fetches the Forever build's interface code from Blizzard's CDN (about 20 minutes); the action caches
it, later runs take a couple of minutes. The report lands in the job summary and as an artifact
(`report.md`, `run.log`, `frame0.png`). The job fails when an error touches your addon.

## 2. Docker

```bash
docker run --rm -v hogsim-cache:/hogsim/cache -v hogsim-extracts:/hogsim/extracts \
  -v "$PWD:/work" ghcr.io/hogtron-solutions-tech-stack/hogsim:latest \
  run --addon /work/MyAddon --report /work/hogsim-report
```

## 3. From a checkout (Linux or WSL2)

See the README quick start for the toolchain, then:

```bash
bin/hogsim fetch                                  # once per client build
bin/hogsim run --addon ../MyAddon --report out/report
```

## Reading the report

- **Errors touching your addon** — each row names the first frame of your code in the stack. These are yours to
  look at; the message usually points at a nil global, a renamed Blizzard frame, a wrong argument, or a template
  that no longer exists in this client.
- **Blizzard UI / simulator gaps** — errors with no frame of yours in the stack. Most are APIs HogSim does not model
  yet; they are not your bugs. The count of these shrinks with every HogSim release.
- `frame0.png` is a wireframe of the frame tree with computed anchors (no textures yet).

## What HogSim does not do (yet)

Textures and fonts in renders, scenarios (party/raid/combat state), secret values, C-side quirks of the live client.
Pass in the real client before a release; HogSim is the fast loop, not the last word.
