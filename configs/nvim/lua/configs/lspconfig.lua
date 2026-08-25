require("nvchad.configs.lspconfig").defaults()

vim.lsp.config("basedpyright", {
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        typeCheckingMode = "off",
        diagnosticMode = "openFilesOnly",
      },
    },
  },
})

local servers = { "html", "cssls", "jsonls", "unocss", "tailwindcss", "svelte", "basedpyright", "ruff" , "astro" }

vim.lsp.enable(servers)

local vue_language_server_path = vim.fn.stdpath "data"
  .. "/mason/packages/vue-language-server/node_modules/@vue/language-server"

local tsserver_filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" }

local vue_plugin = {
  name = "@vue/typescript-plugin",
  location = vue_language_server_path,
  languages = { "vue" },
  configNamespace = "typescript",
}

vim.lsp.config("vtsls", {
  settings = {
    vtsls = {
      tsserver = { globalPlugins = { vue_plugin } },
    },
  },
  filetypes = tsserver_filetypes,
})

vim.lsp.enable { "vtsls", "vue_ls" }
