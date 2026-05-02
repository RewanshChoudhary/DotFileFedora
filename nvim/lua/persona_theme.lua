local M = {}

local function clamp(value)
  return math.max(0, math.min(255, math.floor(value + 0.5)))
end

local function hex_to_rgb(hex)
  local value = hex:gsub("#", "")
  return tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
end

local function mix(fg, bg, alpha)
  local fr, fg_green, fb = hex_to_rgb(fg)
  local br, bg_green, bb = hex_to_rgb(bg)
  return rgb_to_hex(
    br + (fr - br) * alpha,
    bg_green + (fg_green - bg_green) * alpha,
    bb + (fb - bb) * alpha
  )
end

local function set_highlights(groups)
  for group, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

function M.apply(spec)
  local c = vim.tbl_extend("force", {}, spec.colors)

  c.surface = c.surface or mix(c.secondary, c.bg, 0.18)
  c.surface_hi = c.surface_hi or mix(c.secondary, c.bg, 0.28)
  c.panel = c.panel or mix(c.secondary, c.bg, 0.10)
  c.border = c.border or mix(c.secondary, c.fg, 0.14)
  c.subtle = c.subtle or mix(c.fg, c.bg, 0.48)
  c.comment = c.comment or mix(c.secondary, c.fg, 0.24)
  c.cursorline = c.cursorline or mix(c.bg_alt or c.secondary, c.bg, 0.16)
  c.visual = c.visual or mix(c.accent_alt or c.accent, c.bg, 0.18)
  c.search = c.search or mix(c.accent, c.bg, 0.26)
  c.incsearch = c.incsearch or mix(c.accent_alt or c.accent, c.bg, 0.28)
  c.error = c.error or c.accent
  c.warning = c.warning or c.accent_alt or c.secondary
  c.info = c.info or c.accent
  c.hint = c.hint or c.secondary
  c.success = c.success or c.accent
  c.string = c.string or c.fg
  c.number = c.number or c.accent_alt or c.accent
  c.constant = c.constant or c.number
  c.keyword = c.keyword or c.accent
  c.func = c.func or c.fg
  c.type = c.type or c.accent_alt or c.secondary
  c.property = c.property or c.fg
  c.operator = c.operator or c.accent
  c.special = c.special or c.accent_alt or c.accent
  c.match = c.match or mix(c.accent, c.bg, 0.18)
  c.selection_text = c.selection_text or c.fg
  c.diff_add = c.diff_add or mix(c.success, c.bg, 0.18)
  c.diff_change = c.diff_change or mix(c.warning, c.bg, 0.18)
  c.diff_delete = c.diff_delete or mix(c.error, c.bg, 0.18)
  c.diff_text = c.diff_text or mix(c.accent, c.bg, 0.24)

  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  vim.o.background = "dark"
  vim.o.termguicolors = true
  vim.g.colors_name = spec.name

  set_highlights({
    Normal = { fg = c.fg, bg = c.bg },
    NormalNC = { fg = c.fg, bg = c.bg },
    NormalFloat = { fg = c.fg, bg = c.panel },
    FloatBorder = { fg = c.border, bg = c.panel },
    FloatTitle = { fg = c.accent_alt or c.accent, bg = c.panel, bold = true },
    SignColumn = { fg = c.fg, bg = c.bg },
    FoldColumn = { fg = c.comment, bg = c.bg },
    LineNr = { fg = c.comment, bg = c.bg },
    CursorLineNr = { fg = c.accent, bg = c.bg, bold = true },
    CursorLine = { bg = c.cursorline },
    CursorColumn = { bg = c.cursorline },
    ColorColumn = { bg = c.cursorline },
    Cursor = { fg = c.bg, bg = c.fg },
    lCursor = { fg = c.bg, bg = c.fg },
    Visual = { fg = c.selection_text, bg = c.visual },
    VisualNOS = { fg = c.selection_text, bg = c.visual },
    Search = { fg = c.fg, bg = c.search, bold = true },
    IncSearch = { fg = c.fg, bg = c.incsearch, bold = true },
    CurSearch = { fg = c.fg, bg = c.incsearch, bold = true },
    MatchParen = { fg = c.accent, bg = c.match, bold = true },
    StatusLine = { fg = c.fg, bg = c.surface_hi, bold = true },
    StatusLineNC = { fg = c.subtle, bg = c.surface },
    WinSeparator = { fg = c.border, bg = c.bg },
    VertSplit = { fg = c.border, bg = c.bg },
    Pmenu = { fg = c.fg, bg = c.panel },
    PmenuSel = { fg = c.fg, bg = c.surface_hi, bold = true },
    PmenuSbar = { bg = c.surface },
    PmenuThumb = { bg = c.accent_alt or c.accent },
    TabLine = { fg = c.subtle, bg = c.surface },
    TabLineFill = { bg = c.bg },
    TabLineSel = { fg = c.accent, bg = c.surface_hi, bold = true },
    Directory = { fg = c.accent_alt or c.accent, bold = true },
    NonText = { fg = c.surface_hi },
    EndOfBuffer = { fg = c.bg },
    Conceal = { fg = c.subtle },
    Folded = { fg = c.subtle, bg = c.surface },
    Question = { fg = c.success, bold = true },
    Title = { fg = c.accent_alt or c.accent, bold = true },
    ErrorMsg = { fg = c.error, bold = true },
    WarningMsg = { fg = c.warning, bold = true },
    ModeMsg = { fg = c.accent, bold = true },
    MoreMsg = { fg = c.success, bold = true },
    Comment = { fg = c.comment, italic = false },
    Constant = { fg = c.constant },
    String = { fg = c.string },
    Character = { fg = c.string },
    Number = { fg = c.number },
    Boolean = { fg = c.number, bold = true },
    Float = { fg = c.number },
    Identifier = { fg = c.property },
    Function = { fg = c.func, bold = true },
    Statement = { fg = c.keyword },
    Conditional = { fg = c.keyword },
    Repeat = { fg = c.keyword },
    Label = { fg = c.special },
    Operator = { fg = c.operator },
    Keyword = { fg = c.keyword },
    Exception = { fg = c.error },
    PreProc = { fg = c.special },
    Include = { fg = c.special },
    Define = { fg = c.special },
    Macro = { fg = c.special },
    PreCondit = { fg = c.special },
    Type = { fg = c.type },
    StorageClass = { fg = c.type },
    Structure = { fg = c.type },
    Typedef = { fg = c.type },
    Special = { fg = c.special },
    SpecialChar = { fg = c.special },
    Tag = { fg = c.special },
    Delimiter = { fg = c.subtle },
    SpecialComment = { fg = c.comment, italic = true },
    Debug = { fg = c.error },
    Underlined = { fg = c.accent, underline = true },
    Ignore = { fg = c.comment },
    Todo = { fg = c.fg, bg = mix(c.warning, c.bg, 0.32), bold = true },
    Error = { fg = c.error, bold = true },
    DiffAdd = { bg = c.diff_add },
    DiffChange = { bg = c.diff_change },
    DiffDelete = { bg = c.diff_delete },
    DiffText = { bg = c.diff_text, bold = true },
    LspReferenceRead = { bg = c.surface_hi },
    LspReferenceText = { bg = c.surface_hi },
    LspReferenceWrite = { bg = c.surface_hi },

    DiagnosticError = { fg = c.error },
    DiagnosticWarn = { fg = c.warning },
    DiagnosticInfo = { fg = c.info },
    DiagnosticHint = { fg = c.hint },
    DiagnosticOk = { fg = c.success },
    DiagnosticSignError = { fg = c.error, bg = c.bg },
    DiagnosticSignWarn = { fg = c.warning, bg = c.bg },
    DiagnosticSignInfo = { fg = c.info, bg = c.bg },
    DiagnosticSignHint = { fg = c.hint, bg = c.bg },
    DiagnosticVirtualTextError = { fg = c.error, bg = c.diff_delete },
    DiagnosticVirtualTextWarn = { fg = c.warning, bg = c.diff_change },
    DiagnosticVirtualTextInfo = { fg = c.info, bg = c.diff_text },
    DiagnosticVirtualTextHint = { fg = c.hint, bg = c.surface },
    DiagnosticUnderlineError = { undercurl = true, sp = c.error },
    DiagnosticUnderlineWarn = { undercurl = true, sp = c.warning },
    DiagnosticUnderlineInfo = { undercurl = true, sp = c.info },
    DiagnosticUnderlineHint = { undercurl = true, sp = c.hint },

    GitSignsAdd = { fg = c.success },
    GitSignsChange = { fg = c.warning },
    GitSignsDelete = { fg = c.error },
    DiffAdded = { fg = c.success },
    DiffRemoved = { fg = c.error },
    diffAdded = { fg = c.success },
    diffRemoved = { fg = c.error },

    TelescopeNormal = { fg = c.fg, bg = c.bg },
    TelescopeBorder = { fg = c.border, bg = c.bg },
    TelescopePromptBorder = { fg = c.accent, bg = c.bg },
    TelescopeResultsBorder = { fg = c.border, bg = c.bg },
    TelescopePreviewBorder = { fg = c.border, bg = c.bg },
    TelescopeTitle = { fg = c.accent_alt or c.accent, bold = true },
    TelescopeSelection = { fg = c.fg, bg = c.surface_hi, bold = true },
    TelescopeSelectionCaret = { fg = c.accent },
    TelescopeMatching = { fg = c.accent, bold = true },

    NvimTreeNormal = { fg = c.fg, bg = c.bg },
    NvimTreeNormalNC = { fg = c.fg, bg = c.bg },
    NvimTreeFolderName = { fg = c.accent_alt or c.accent },
    NvimTreeRootFolder = { fg = c.accent, bold = true },
    NvimTreeOpenedFolderName = { fg = c.accent, bold = true },
    NeoTreeNormal = { fg = c.fg, bg = c.bg },
    NeoTreeNormalNC = { fg = c.fg, bg = c.bg },
    NeoTreeDirectoryName = { fg = c.accent_alt or c.accent },
    NeoTreeDirectoryIcon = { fg = c.accent },

    CmpItemAbbr = { fg = c.fg },
    CmpItemAbbrMatch = { fg = c.accent, bold = true },
    CmpItemAbbrMatchFuzzy = { fg = c.accent_alt or c.accent, bold = true },
    CmpItemMenu = { fg = c.comment },
    CmpItemKindFunction = { fg = c.func },
    CmpItemKindMethod = { fg = c.func },
    CmpItemKindVariable = { fg = c.property },
    CmpItemKindKeyword = { fg = c.keyword },
    CmpItemKindClass = { fg = c.type },
    CmpItemKindModule = { fg = c.special },
    CmpItemKindText = { fg = c.string },

    ["@comment"] = { link = "Comment" },
    ["@string"] = { fg = c.string },
    ["@string.escape"] = { fg = c.special },
    ["@character"] = { fg = c.string },
    ["@number"] = { fg = c.number },
    ["@boolean"] = { fg = c.number, bold = true },
    ["@constant"] = { fg = c.constant },
    ["@constant.builtin"] = { fg = c.special },
    ["@variable"] = { fg = c.property },
    ["@variable.builtin"] = { fg = c.special },
    ["@property"] = { fg = c.property },
    ["@field"] = { fg = c.property },
    ["@parameter"] = { fg = c.fg },
    ["@function"] = { fg = c.func, bold = true },
    ["@function.call"] = { fg = c.func },
    ["@method"] = { fg = c.func },
    ["@method.call"] = { fg = c.func },
    ["@constructor"] = { fg = c.type, bold = true },
    ["@keyword"] = { fg = c.keyword },
    ["@keyword.return"] = { fg = c.keyword },
    ["@keyword.function"] = { fg = c.keyword },
    ["@operator"] = { fg = c.operator },
    ["@punctuation.delimiter"] = { fg = c.subtle },
    ["@punctuation.bracket"] = { fg = c.special },
    ["@punctuation.special"] = { fg = c.special },
    ["@type"] = { fg = c.type },
    ["@type.builtin"] = { fg = c.type, italic = true },
    ["@tag"] = { fg = c.special },
    ["@tag.attribute"] = { fg = c.property },
    ["@module"] = { fg = c.special },
    ["@namespace"] = { fg = c.special },
  })

  if spec.highlights then
    set_highlights(spec.highlights(c, mix))
  end

  vim.g.terminal_color_0 = c.bg
  vim.g.terminal_color_1 = c.error
  vim.g.terminal_color_2 = c.success
  vim.g.terminal_color_3 = c.warning
  vim.g.terminal_color_4 = c.info
  vim.g.terminal_color_5 = c.accent_alt or c.accent
  vim.g.terminal_color_6 = c.accent
  vim.g.terminal_color_7 = c.fg
  vim.g.terminal_color_8 = c.surface_hi
  vim.g.terminal_color_9 = c.error
  vim.g.terminal_color_10 = c.success
  vim.g.terminal_color_11 = c.warning
  vim.g.terminal_color_12 = c.info
  vim.g.terminal_color_13 = c.accent_alt or c.accent
  vim.g.terminal_color_14 = c.accent
  vim.g.terminal_color_15 = c.fg
end

return M
