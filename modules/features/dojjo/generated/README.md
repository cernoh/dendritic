# Vendored build_runner output for Nix

These `*.freezed.dart` / `*.g.dart` files are the result of:

  cd cli
  dart pub get
  dart run build_runner build --delete-conflicting-outputs

using Nixpkgs Dart 3.13. The upstream `0.2.2` tag checks in files generated
with Dart 3.11, which miss `WorkspaceInfo.changeId` / `copyWith` and fail
`dart compile exe` on 3.13 (`jj.dart:172:42` etc). Regenerating here makes
`buildDartApplication` pure and avoids `__noChroot` network fetches.

To update after a `dojjo` version bump:

  nix shell nixpkgs#dart --command bash -c '
    git clone --depth 1 --branch vX.Y.Z https://github.com/tjarvstrand/dojjo.git /tmp/dojjo
    cd /tmp/dojjo/cli
    dart pub get
    dart run build_runner build --delete-conflicting-outputs
    cp lib/src/jj.freezed.dart lib/src/jj.g.dart \
       lib/src/config.freezed.dart lib/src/config.g.dart \
       /path/to/dendritic/modules/features/dojjo/generated/
    yq eval -o=json pubspec.lock > /path/to/dendritic/modules/features/dojjo/pubspec.lock.json
  '
