vim.opt.number = true
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.cmd [[packadd packer.nvim]]

vim.api.nvim_set_keymap('n', '<leader>q', ':exit<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>s', ':w<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>w', ':wq<CR>', { noremap = true })

return require('packer').startup(function(use)
  use {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.0',
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { noremap = true })
      vim.api.nvim_set_keymap('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { noremap = true })
      vim.api.nvim_set_keymap('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { noremap = true })
      vim.api.nvim_set_keymap('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', { noremap = true })
    end,
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { 'c', 'css', 'javascript', 'http', 'markdown', 'nix', 'scss', 'sql', 'vim', 'vue' },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = true,
        },
      })
    end,
  }

  use {
    'neovim/nvim-lspconfig',
    requires = {
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-nvim-lua',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      local lspconfig = require('lspconfig')
      local mlsp = require('mason-lspconfig')
      local mason = require('mason')
      local cmp_lsp = require('cmp_nvim_lsp')
      local cmp = require('cmp')

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = cmp_lsp.update_capabilities(capabilities)

      local on_attach = function(client, bufnr)
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

        local bufopts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
        vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
        vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
        vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
        vim.keymap.set('n', '<space>wl', function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, bufopts)
        vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
        vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
        vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
        vim.keymap.set('n', '<space>f', vim.lsp.buf.formatting, bufopts)
      end

      local servers = { 'clangd', 'pyright', 'tsserver', 'rnix', 'tailwindcss', 'sumneko_lua', 'eslint', 'dockerls', 'cssls', 'html', 'jsonls' }
      mlsp.setup_handlers({
        function(name)
          if vim.tbl_contains(servers, name) then
           lspconfig[name].setup({
              capabilities = capabilities,
	      on_attach = on_attach,
	    })
          end
	end,
      })

      mlsp.setup({
        automatic_install = true,
	ensure_installed = servers,
      })

      mason.setup()

      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm { select = true },
          ['<C-e>'] = cmp.mapping.abort(),
        }),
        sources = cmp.config.sources({
          { name = 'buffer' },
          { name = 'nvim_lua' },
          { name = 'nvim_lsp' },
        })
      })

      cmp.setup.cmdline('/', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      })

      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        })
      })
    end
  }

  use {
    'stevearc/dressing.nvim',
    config = function() require('dressing').setup({}) end,
  }

  use {
    'glepnir/lspsaga.nvim',
    branch = 'main',
    config = function() require('lspsaga').init_lsp_saga() end,
  }

  use {
    'lewis6991/gitsigns.nvim',
    config = function() require('gitsigns').setup({
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol',
      },
      current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
      signcolumn = true,
      numhl = true,
    }) end,
  }

  use {
    'nvim-lua/plenary.nvim',
    'TimUntersberger/neogit',
    'sindrets/diffview.nvim',
    config = function()
      require('neogit').setup({
        kind = "tab",
        auto_refresh = true,
        integrations = {
          diffview = true,
        },
      })

      vim.api.nvim_set_keymap('n', '<leader>g', ':Neogit<CR>', { noremap = true })
    end
  }

  use {
    'sindrets/winshift.nvim',
    config = function()
      require('winshift').setup({})

      vim.api.nvim_set_keymap('n', '<leader>m', ':WinShift<CR>', { noremap = true })
    end,
  }

  use {
    'folke/tokyonight.nvim',
    config = function() vim.cmd [[colorscheme tokyonight]] end,
  }

  use { 'norcalli/nvim-colorizer.lua' }
  use { 'gpanders/editorconfig.nvim' }
  use { 'xiyaowong/nvim-cursorword' }
  use { 'LnL7/vim-nix' }
end)
