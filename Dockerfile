# Build/run image for the dmd simulator and its tests.
# The official erlang image bundles rebar3.
FROM erlang:25

WORKDIR /app

# Copy sources and compile (BEAM is cached in the image).
COPY . .
RUN rebar3 compile

# Default: run the full test suite. The 10000-device scale run needs a raised
# file-descriptor limit, so launch the container with:
#   docker run --ulimit nofile=1048576:1048576 ...
# (see scripts/docker_test.sh and scripts/docker_scale.sh).
CMD ["rebar3", "do", "eunit, ct"]
