return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- Remove root detection from lualine to prevent errors
      if opts.sections and opts.sections.lualine_c then
        opts.sections.lualine_c = vim.tbl_filter(function(component)
          return type(component) ~= "table" or component[1] ~= "root_dir"
        end, opts.sections.lualine_c)
      end
      return opts
    end,
  },
}
