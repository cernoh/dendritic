#!/usr/bin/env bash
# Museum plugin tests (PLAN 2.7).
#
# The Luau CLI gives every required module its own environment, so a module
# that calls the host globals (`ui`, `noctalia`, `barWidget`) cannot be tested
# with a plain `require`. This script concatenates the stub host, the library
# modules and one driver into a single chunk, then runs it:
#
#   modules/features/noctalia/tests/run-museum-tests.sh
#
# The plugin directory itself stays Luau + TOML only (the module contract).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
plugin="$here/plugins/museum"
tests="$plugin/tests"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

assemble() {
  local driver=$1 out=$2
  {
    echo 'local function __stub()'
    cat "$tests/stub.luau"
    echo 'end'
    echo 'local stub = __stub()'
    echo 'noctalia = stub.noctalia'
    echo 'ui = stub.ui'
    echo 'barWidget = stub.barWidget'
    echo 'panel = stub.panel'
    echo 'shortcut = stub.shortcut'

    echo 'local function __museum()'
    cat "$plugin/lib/museum.luau"
    echo 'end'
    echo 'local museum = __museum()'

    echo 'local function __mango()'
    cat "$plugin/lib/mango.luau"
    echo 'end'
    echo 'local mango = __mango()'

    echo 'local function __bar()'
    sed -e 's|^local museum = require("./museum.luau")$||' \
        -e 's|^local mango = require("./mango.luau")$||' \
        "$plugin/lib/bar.luau"
    echo 'end'
    echo 'local bar = __bar()'

    echo 'local function __drawer()'
    sed -e 's|^local museum = require("./museum.luau")$||' \
        "$plugin/lib/drawer.luau"
    echo 'end'
    echo 'local drawer = __drawer()'

    # panel.luau is an entry script, not a module: it defines the host-called
    # globals (onOpen/onClose/update) and renders through `panel`. Only its two
    # require lines are stripped, because the modules above are already in the
    # chunk.
    sed -e 's|^local museum = require("./lib/museum.luau")$||' \
        -e 's|^local drawer = require("./lib/drawer.luau")$||' \
        "$plugin/panel.luau"

    # A driver may read the plugin's own data files (translations, settings);
    # Luau has no io library, so the runner pastes the bytes in as literals.
    printf 'local __pluginDir = [==[%s]==]\n' "$plugin"
    printf 'local __translationsJson = [==[%s]==]\n' "$(cat "$plugin/translations/en.json")"

    # The catalogue service is only needed by its own driver: it polls at load.
    if [ "$driver" = "driver-catalogue.luau" ]; then
      cat "$plugin/catalogue.luau"
    fi

    cat "$tests/$driver"
  } > "$out"
}

run() {
  local driver=$1
  local out="$work/${driver%.luau}.combined.luau"
  assemble "$driver" "$out"
  echo "── $driver"
  nix shell nixpkgs#luau --command luau "$out"
}

# One optional argument filters by driver name, for iterating on one driver:
#   run-museum-tests.sh museum
filter=${1:-}
ran=0
for driver in \
  driver-museum.luau \
  driver-mango.luau \
  driver-bar.luau \
  driver-panel.luau \
  driver-bodies.luau \
  driver-catalogue.luau; do
  if [ -z "$filter" ] || [[ "$driver" == *"$filter"* ]]; then
    run "$driver"
    ran=$((ran + 1))
  fi
done

if [ "$ran" -eq 0 ]; then
  echo "run-museum-tests.sh: no driver matches '$filter'" >&2
  exit 1
fi
echo "museum suite: ok ($ran drivers)"
