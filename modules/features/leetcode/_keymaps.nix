# LeetCode keymaps (kawre/leetcode.nvim). Auth is upstream `:Leet cookie
# update` (paste the browser Cookie header at runtime); nothing secret lives
# in the store.
{
  keymaps = [
    {
      key = "<leader>lm";
      mode = "n";
      action = "<cmd>Leet<CR>";
      silent = true;
      desc = "LeetCode: menu";
    }
    {
      key = "<leader>ll";
      mode = "n";
      action = "<cmd>Leet cookie update<CR>";
      silent = true;
      desc = "LeetCode: login (paste cookie)";
    }
    {
      key = "<leader>ld";
      mode = "n";
      action = "<cmd>Leet daily<CR>";
      silent = true;
      desc = "LeetCode: daily problem";
    }
    {
      key = "<leader>lr";
      mode = "n";
      action = "<cmd>Leet random<CR>";
      silent = true;
      desc = "LeetCode: random problem";
    }
    {
      key = "<leader>ls";
      mode = "n";
      action = "<cmd>Leet list<CR>";
      silent = true;
      desc = "LeetCode: list problems";
    }
  ];
}
