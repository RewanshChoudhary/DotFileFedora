local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "kristijanhusak/vim-dadbod-completion",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = sql_ft,
        callback = function()
          if vim.bo.omnifunc == "sqlcomplete#Complete" and vim.fn.exists("*sqlcomplete#Complete") == 0 then
            vim.bo.omnifunc = ""
          end

          if not LazyVim.has_extra("coding.nvim-cmp") then
            return
          end

          local ok, cmp = pcall(require, "cmp")
          if not ok then
            return
          end

          local config = cmp.get_config and cmp.get_config() or {}
          local base_sources = type(config.sources) == "table" and config.sources or {}
          local sources = vim.tbl_map(function(source)
            return { name = source.name }
          end, base_sources)

          local has_dadbod = false
          for _, source in ipairs(sources) do
            if source.name == "vim-dadbod-completion" then
              has_dadbod = true
              break
            end
          end

          if not has_dadbod then
            table.insert(sources, { name = "vim-dadbod-completion" })
          end

          cmp.setup.buffer({ sources = sources })
        end,
      })
    end,
  },
}
