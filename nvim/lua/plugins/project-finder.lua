return {
  dir = vim.fn.stdpath("config") .. "/lua/project-finder",
  name = "project-finder.nvim",
  dev = true,

  cmd = { "ProjectPick", "ProjectPickPrompt", "ProjectScan" },
  keys = {
    { "P", "<cmd>ProjectPickPrompt<cr>", desc = "Search Projects" },
  },

  opts = {
    scan_paths = { "~", "~/projects", "~/work" },
    max_depth = 4,
    exclude_dirs = {
      "node_modules",
      ".git",
      "target",
      "dist",
      "build",
      ".next",
      ".nuxt",
    },
  },

  config = function(_, opts)
    require("project-finder").setup(opts)
  end,
}
