# HogSim: headless WoW: Forever UI simulator. Build: docker build -t hogsim .
# Run:   docker run --rm -v hogsim-cache:/hogsim/cache -v hogsim-extracts:/hogsim/extracts -v $PWD:/addon hogsim run --addon /addon/MyAddon
FROM debian:bookworm-slim AS build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    build-essential cmake ninja-build pkg-config git curl ca-certificates unzip zip ruby python3 \
    lua5.1 liblua5.1-0-dev luarocks libexpat1-dev libmagickwand-dev libreadline-dev libssl-dev \
    libyaml-dev libzip-dev libsqlite3-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /hogsim
COPY wowless-scm-0.rockspec ./
RUN luarocks config lua_version 5.1 \
    && luarocks build --deps-only wowless-scm-0.rockspec \
    && luarocks install luacasc 1.19
COPY . .
# the community listfile is published as release assets, not in the submodule
RUN curl -sL -o vendor/listfile/community-listfile.csv \
      https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv \
    && curl -sL -o vendor/listfile/community-listfile-withcapitals.csv \
      https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile-withcapitals.csv
# elune (WoW-flavoured Lua 5.1) and the ninja graph; product data is fetched at run time into the cache volume
RUN cd vendor/elune && cmake --preset linux > /dev/null && cmake --build --preset linux > /dev/null \
    && cd /hogsim && lua tools/mkninja.lua
RUN chmod +x bin/hogsim
VOLUME ["/hogsim/cache", "/hogsim/extracts", "/hogsim/out"]
ENTRYPOINT ["/hogsim/bin/hogsim"]
CMD ["help"]
