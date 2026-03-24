vim.cmd('colorscheme habamax')
vim.cmd('set rnu')
vim.cmd('set nu')
vim.cmd('set tabstop=2')
vim.cmd('set shiftwidth=2')
vim.cmd('set expandtab')
vim.cmd('set nohlsearch')
vim.opt.completeopt = { 'menuone', 'noselect', 'popup' }
vim.o.updatetime = 250

local function pum_visible()
  return vim.fn.pumvisible() == 1
end

local function completion_selected()
  return vim.fn.complete_info({ 'selected' }).selected ~= -1
end

local function completion_next()
  if pum_visible() then
    return '<C-n>'
  end

  vim.lsp.completion.get()
  return ''
end

local function completion_prev()
  if pum_visible() then
    return '<C-p>'
  end

  return ''
end

local function completion_confirm()
  if pum_visible() and completion_selected() then
    return '<C-y>'
  end

  return '<CR>'
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set('v', '<leader>da', ":s/->/./g<CR>", { noremap = true, silent = true })
vim.keymap.set('v', '<leader>ad', ":s/\\./->/g<CR>", { noremap = true, silent = true })
vim.keymap.set('x', '<Tab>', '>gv', { noremap = true, silent = true, desc = 'Indent selection' })
vim.keymap.set('x', '<BS>', '<gv', { noremap = true, silent = true, desc = 'Unindent selection' })
vim.keymap.set('x', 'J', ":move '>+1<CR>gv=gv", { noremap = true, silent = true, desc = 'Move selection down' })
vim.keymap.set('x', 'K', ":move '<-2<CR>gv=gv", { noremap = true, silent = true, desc = 'Move selection up' })

vim.pack.add {
  { src = 'https://github.com/nvim-lua/plenary.nvim' },
  { src = 'https://github.com/ej-shafran/compile-mode.nvim' },
  { src = 'https://github.com/neovim/nvim-lspconfig' },
  { src = 'https://github.com/mason-org/mason.nvim' },
  { src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
  { src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim' },
}

vim.pack.add({
  { src = "https://github.com/rose-pine/neovim", name = "rose-pine" }
})

require("rose-pine").setup({
  variant = "main", -- "main", "moon", or "dawn"
})
vim.cmd("colorscheme rose-pine")

require('mason').setup()
require('mason-lspconfig').setup()
require('mason-tool-installer').setup({
  ensure_installed = {
    "lua-language-server",
    "clangd",
  }
}
)

vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 2,
    source = 'if_many',
    prefix = '●',
  },
  float = {
    border = 'rounded',
    source = 'if_many',
  },
})

vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      diagnostics = {
        globals = {
          'vim',
          'require'
        },
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
      },
      telemetry = {
        enable = false,
      },
    },
  },
})

vim.lsp.enable('lua_ls')
vim.lsp.enable('clangd')

local lsp_group = vim.api.nvim_create_augroup('user-lsp-config', { clear = true })
local lsp_format_group = vim.api.nvim_create_augroup('user-lsp-format', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = lsp_group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    local bufnr = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, {
        buffer = bufnr,
        silent = true,
        desc = desc,
      })
    end
    local map_expr = function(lhs, rhs, desc)
      vim.keymap.set('i', lhs, rhs, {
        buffer = bufnr,
        silent = true,
        expr = true,
        desc = desc,
      })
    end

    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
      vim.api.nvim_create_autocmd('InsertCharPre', {
        group = vim.api.nvim_create_augroup('user-lsp-completion-' .. bufnr, { clear = true }),
        buffer = bufnr,
        callback = function()
          vim.lsp.completion.get()
        end,
        desc = 'LSP completion on every typed character',
      })
      map('i', '<C-Space>', function()
        vim.lsp.completion.get()
      end, 'LSP completion')
      map_expr('<C-n>', completion_next, 'Next completion')
      map_expr('<C-S-N>', completion_prev, 'Previous completion')
      map_expr('<C-p>', completion_prev, 'Previous completion')
      map_expr('<CR>', completion_confirm, 'Confirm completion')
    end

    if client:supports_method('textDocument/formatting') then
      vim.api.nvim_clear_autocmds({ group = lsp_format_group, buffer = bufnr })
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = lsp_format_group,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({
            bufnr = bufnr,
            timeout_ms = 2000,
          })
        end,
        desc = 'Format buffer before save',
      })
    end

    map('n', '<leader>lh', vim.lsp.buf.hover, 'LSP hover')
    map('n', '<leader>ld', function()
      vim.diagnostic.open_float(nil, { scope = 'line', focus = false })
    end, 'Line diagnostics')
    map('n', '<leader>la', vim.lsp.buf.code_action, 'LSP code action')
    map('n', '<leader>ln', function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, 'Next diagnostic')
    map('n', '<leader>lp', function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, 'Previous diagnostic')
  end,
})

vim.api.nvim_create_autocmd('CursorHold', {
  group = lsp_group,
  callback = function()
    vim.diagnostic.open_float(nil, {
      scope = 'cursor',
      focus = false,
    })
  end,
})

vim.g.compile_mode = {
  default_command = {
    c = "make run -k ",
    cpp = "make run -k ",
  },
  recompile_no_fail = true,
}

vim.keymap.set("n", "<leader>R", ":below Compile<CR>")
vim.keymap.set("n", "<leader>r", ":below Recompile<CR>")

vim.keymap.set("n", "<leader>e", ":Ex<CR>")
