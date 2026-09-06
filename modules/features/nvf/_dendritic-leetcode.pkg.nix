# _dendritic-leetcode.pkg.nix
# Builds the local dendritic-leetcode plugin via vimUtils.buildVimPlugin.
# Imported explicitly by modules/features/nvf/default.nix (path contains /_).
{ pkgs }:
pkgs.vimUtils.buildVimPlugin {
  pname = "dendritic-leetcode";
  version = "0.1.0";
  src = ./_dendritic-leetcode;
  meta = {
    description = "Self-contained LeetCode login UI for leetcode.nvim (dendritic)";
    homepage = "https://github.com/kawre/leetcode.nvim";
    license = pkgs.lib.licenses.mit;
  };
}
