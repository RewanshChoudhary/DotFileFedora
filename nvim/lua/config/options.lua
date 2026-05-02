-- Ensure files open as modifiable by default
vim.opt.modifiable = true
vim.opt.readonly = false
--
-- -- Also ensure write permission is enabled
vim.opt.write = true

-- Keep key sequences active long enough for leader discovery menus.
vim.opt.timeout = true
vim.opt.timeoutlen = 500

vim.g.root_spec = { "lsp", ".git", "cwd" }

-- Pin LazyVim completion backend to nvim-cmp.
vim.g.lazyvim_cmp = "nvim-cmp"

-- SQL ftplugin maps call sqlcomplete#DrillIntoTable(), but LazyVim SQL extra
-- disables sqlcomplete; disable those default maps to avoid E117 notifications.
vim.g.omni_sql_no_default_maps = 1
