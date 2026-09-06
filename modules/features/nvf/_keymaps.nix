{
  keymaps = [
    #fzf commands
    {
      key = "<leader>ff";
      mode = "n";
      action = "<cmd>FzfLua files<CR>";
      silent = true;
      desc = "Find files";
    }
    {
      key = "<leader>fd";
      mode = "n";
      action = "<cmd>FzfLua diagnostics_document<CR>";
      silent = true;
      desc = "Search diagnostics";
    }
    {
      key = "<leader>fg";
      mode = "n";
      action = "<cmd>FzfLua lgrep_curbuf<CR>";
      silent = true;
      desc = "Find text in buffer";
    }
    {
      key = "<leader>fd";
      mode = "n";
      action = "<cmd>FzfLua diagnostics_document<CR>";
      silent = true;
      desc = "grep through errors in buffer";
    }
    {
      key = "<leader>fb";
      mode = "n";
      action = "<cmd>FzfLua buffers<CR>";
      silent = true;
      desc = "grep through open buffers";
    }
    {
      key = "<leader>fp";
      mode = "n";
      action = "<cmd> FzfLua live_grep_native<CR>";
      silent = true;
      desc = "Find text in project";
    }
    {
      key = "<leader>e";
      mode = "n";
      action = "<cmd>Neotree toggle<CR>";
      silent = true;
      desc = "Toggle file explorer";
    }
    {
      key = "<C-h>";
      mode = "n";
      action = "<C-w>h";
      silent = true;
      desc = "Move to left window";
    }
    {
      key = "<C-j>";
      mode = "n";
      action = "<C-w>j";
      silent = true;
      desc = "Move to bottom window";
    }
    {
      key = "<C-k>";
      mode = "n";
      action = "<C-w>k";
      silent = true;
      desc = "Move to top window";
    }
    {
      key = "<C-l>";
      mode = "n";
      action = "<C-w>l";
      silent = true;
      desc = "Move to right window";
    }

    {
      key = "<S-h>";
      mode = "n";
      action = ":bprevious<CR>";
      silent = true;
      desc = "Previous buffer";
    }
    {
      key = "<S-l>";
      mode = "n";
      action = ":bnext<CR>";
      silent = true;
      desc = "Next buffer";
    }
    {
      key = "<leader>bd";
      mode = "n";
      action = ":bdelete<CR>";
      silent = true;
      desc = "delete buffer";
    }
    {
      key = "<Space>q";
      mode = "v";
      action = "<cmd>CopilotChat<CR>";
      silent = true;
      desc = "󰚩 CopilotChat";
    }
    {
      key = "<Space>qc";
      mode = "n";
      action = "<cmd>CopilotChatModels<CR>";
      silent = true;
      desc = "󰚩 Change Model";
    }
    {
      key = "<Space>qe";
      mode = "n";
      action = "<cmd>CopilotChatToggle<CR>";
      silent = true;
      desc = "󰚩 Toggle Copilot Chat";
    }
    # LeetCode (kawre/leetcode.nvim + dendritic self-contained login)
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
      action = "<cmd>DendriticLeetLogin<CR>";
      silent = true;
      desc = "LeetCode: self-contained login";
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
