#!/usr/bin/env bash
# Museum desktop-tile tests (PLAN 5.1-5.4).
#
# The Luau CLI gives every required module its own environment, so a module
# that calls the host globals (`ui`, `noctalia`, `desktopWidget`) cannot be
# tested with a plain `require`. This script concatenates the stub host, the
# component libraries, the driver and the three desktop entry scripts into one
# chunk, then runs it:
#
#   modules/features/noctalia/tests/run-desktop-tests.sh
#
# The plugin directory itself stays Luau + TOML only (the module contract).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
plugin="$here/plugins/museum"
tests="$plugin/tests"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

chunk="$work/desktop.luau"
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
  # The stub predates the desktop tiles; the host namespace is the same
  # three-call surface the runtime exposes.
  cat <<'LUAU'
desktopWidget = {
  render = function(tree)
    stub.rec.rendered = tree
  end,
  setWantsSecondTicks = function(value)
    stub.rec.secondTicks = value
  end,
  setNeedsFrameTick = function(value)
    stub.rec.frameTick = value
  end,
}
LUAU

  echo 'local function __museum()'
  cat "$plugin/lib/museum.luau"
  echo 'end'
  echo 'local museum = __museum()'

  echo 'local function __desktop()'
  sed -e 's|^local museum = require("./museum.luau")$||' "$plugin/lib/desktop.luau"
  echo 'end'
  echo 'local desktop = __desktop()'

  cat "$tests/driver-desktop.luau"

  # The entry scripts are not modules: they define the host-called globals and
  # render through `desktopWidget`. Strip their one require, because the module
  # is already in this chunk.
  for entry in desktop-board desktop-clock desktop-month; do
    echo
    echo "-- ── $entry.luau ──"
    sed -e 's|^local desktop = require("./lib/desktop.luau")$||' "$plugin/$entry.luau"
  done

  cat <<'LUAU'

-- The last render is the month entry's, which follows the board and clock.
assert(stub.rec.rendered ~= nil, "an entry rendered")
assert(stub.find(stub.rec.rendered, function(node)
  return node.props ~= nil and node.props.key == "month-plate"
end) ~= nil, "the month entry renders the plate")
assert(stub.rec.secondTicks == true, "the clock asks for second ticks")
assert(stub.rec.watchers.stats ~= nil, "the board watches the telemetry feed")
assert(stub.rec.interval == 60000, "the month entry polls once a minute")
print("desktop.luau: ok (board, placard, month plate)")
LUAU
} > "$chunk"

nix shell nixpkgs#luau --command luau "$chunk"
