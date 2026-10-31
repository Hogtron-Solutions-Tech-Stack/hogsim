#!/bin/bash
# tools/regen_stubs.sh <product>: regenerate the API stubs that came from the client's API documentation.
# Only yamls carrying the generated marker are removed; hand-written implementations are never touched.
set -e
product=${1:?usage: tools/regen_stubs.sh <product>}
marker='comment: generated from Blizzard_APIDocumentationGenerated'
n=$(grep -l -F "$marker" data/api/*.yaml 2>/dev/null | wc -l)
echo "removing $n generated stubs"
grep -l -F "$marker" data/api/*.yaml 2>/dev/null | xargs -r rm -f
lua tools/apidoc2yaml.lua "$product"
lua tools/synth_globals.lua "$product"
echo "regenerated; review git status before committing"
