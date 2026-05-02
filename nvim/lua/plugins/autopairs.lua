return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        disable_filetype = { "TelescopePrompt", "vim" },

        -- Enable auto deletion of pairs
        enable_check_bracket_line = false,

        -- Do NOT add extra spaces
        check_ts = true,

        -- Fast wrap disabled (IDE-like, less magic)
        fast_wrap = false,

        -- Enable for all languages
        map_cr = true,
        map_bs = true, -- THIS enables backspace deletion
        map_c_h = true,
        map_c_w = true,
      })
    end,
  },
}
