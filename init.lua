-- Leader key (used as prefix for custom bindings like <leader>f, <leader>s, etc.)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- UI
vim.o.number = true              -- show absolute line number on cursor line
vim.o.relativenumber = true      -- show relative numbers on other lines (fast jumps: 5j, 12k)
vim.o.cursorline = true          -- highlight the line the cursor is on
vim.o.signcolumn = 'yes'         -- always show the sign column so text doesn't jump when diagnostics appear
vim.o.scrolloff = 8              -- keep 8 lines visible above/below cursor when scrolling
vim.o.splitright = true          -- new vertical splits open to the right
vim.o.splitbelow = true          -- new horizontal splits open below
vim.o.winborder = 'rounded'      -- rounded borders for all floating windows (hover, signature, etc.)
vim.o.list = true                -- visualize whitespace
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.breakindent = true         -- wrapped lines keep visual indent

-- Behavior
vim.o.mouse = 'a'                -- enable mouse in all modes
vim.o.undofile = true            -- persist undo history across restarts
vim.o.ignorecase = true          -- case-insensitive search…
vim.o.smartcase = true           -- …unless the query contains a capital letter
vim.o.updatetime = 250           -- faster CursorHold (used by LSP, gitsigns, etc.)
vim.o.timeoutlen = 300           -- snappier which-key / multi-key mapping response
vim.o.confirm = true             -- prompt to save instead of erroring on :q with unsaved changes
vim.o.inccommand = 'split'       -- live preview of :s substitutions in a split
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'  -- sync yank/paste with system clipboard (deferred so startup stays fast)
end)

-- Indentation (2 spaces, no tabs)
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2

-- Diagnostics: sort by severity, only underline errors, virtual text with source when ambiguous
vim.diagnostic.config {
  severity_sort = true,
  float = { source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = {},
  virtual_text = { source = 'if_many', spacing = 2 },
}

-- Diagnostics quickfix list (use built-in ]d / [d to navigate, <C-w>d to peek)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

-- Exit terminal mode without the awful default <C-\><C-n>
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>')

-- Keep cursor centered on half-page jumps and search results
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- Join lines without moving the cursor
vim.keymap.set('n', 'J', 'mzJ`z')

-- Move visually selected lines up/down, preserving the selection and re-indenting
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Paste over a visual selection without clobbering the clipboard
vim.keymap.set('x', '<leader>p', [["_dP]])

-- Project-wide substitute of the word under the cursor (interactive — edit before pressing Enter)
vim.keymap.set('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Run the current file in a small terminal split (python via uv, C/C++ via g++ c++23)
vim.keymap.set('n', '<leader>r', function()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.cmd('w')
  local file = vim.fn.expand('%')
  local ft = vim.bo.filetype
  local cmd
  if ft == 'python' then
    cmd = 'uv run ' .. file
  elseif ft == 'cpp' or ft == 'c' then
    local output = vim.fn.expand('%:r')
    cmd = 'g++ -std=c++23 -o ' .. output .. ' ' .. file .. ' && ./' .. output
  else
    vim.notify('No runner for filetype: ' .. ft, vim.log.levels.WARN)
    return
  end
  vim.cmd('8split | terminal ' .. cmd)
  vim.cmd('wincmd p')
end)

-- Briefly highlight yanked text so you can see what got copied
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() vim.hl.on_yank() end,
})

-- Bootstrap lazy.nvim plugin manager on first run
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', 'https://github.com/folke/lazy.nvim.git', lazypath }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  -- Syntax highlighting + smart indent via tree-sitter parsers
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = { 'c', 'cpp', 'lua', 'python', 'vim', 'vimdoc', 'bash' },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  -- Fuzzy finder for files, grep, buffers
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      { '<leader>f', '<cmd>Telescope find_files<cr>' },
      { '<leader>g', '<cmd>Telescope live_grep<cr>' },
      { '<leader>b', '<cmd>Telescope buffers<cr>' },
      { '<leader>/', '<cmd>Telescope current_buffer_fuzzy_find<cr>' },
    },
  },

  -- LSP: Mason installs the servers, nvim-lspconfig wires them up. Default nvim 0.11+ LSP keymaps apply:
  -- K (hover), grn (rename), grr (references), gra (code action), gri (implementation), gO (symbols), <C-]> (definition).
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      local servers = {
        clangd = {},
        lua_ls = {
          settings = {
            Lua = { completion = { callSnippet = 'Replace' } },
          },
        },
        ruff = {},
      }

      require('mason-lspconfig').setup {
        ensure_installed = vim.tbl_keys(servers),
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  -- Autocompletion (LSP, paths, buffer words); <C-y> accepts, <C-n>/<C-p> navigate
  {
    'saghen/blink.cmp',
    version = '1.*',
    opts = {
      keymap = { preset = 'default' },
      completion = { documentation = { auto_show = true } },
      sources = { default = { 'lsp', 'path', 'buffer' } },
      signature = { enabled = true },
      fuzzy = { implementation = 'lua' },
    },
  },

  -- Format on save (falls back to LSP formatting when no formatter is configured)
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    opts = {
      format_on_save = { timeout_ms = 500, lsp_format = 'fallback' },
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_fix', 'ruff_format' },
        c = { 'clang-format' },
        cpp = { 'clang-format' },
      },
    },
  },

  -- Typing practice (:Typr, :TyprStats)
  {
    'nvzone/typr',
    dependencies = 'nvzone/volt',
    opts = {},
    cmd = { 'Typr', 'TyprStats' },
  },

  -- Colorscheme
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
})
