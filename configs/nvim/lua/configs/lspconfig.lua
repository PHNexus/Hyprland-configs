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

vim.lsp.config("kotlin_language_server", {
  settings = {
    kotlin = {
      diagnostics = {
        enabled = true,
      },
    },
  },
})

-- Configuração do jdtls (USANDO O PACOTE DO AUR, NÃO O MASON)
vim.lsp.config("jdtls", {
  cmd = { "/usr/bin/jdtls" },
  root_dir = vim.fs.root(0, { ".git", "pom.xml", "build.gradle", "build.gradle.kts" }),
  settings = {
    java = {
      home = "/usr/lib/jvm/java-26-openjdk",
      configuration = {
        updateBuildConfiguration = "automatic",
        runtimes = {
          {
            name = "JavaSE-26",
            path = "/usr/lib/jvm/java-26-openjdk",
            default = true,
          },
        },
      },
    },
  },
})

local servers = { "html", "cssls", "jsonls", "unocss", "tailwindcss", "svelte", "basedpyright", "ruff", "astro", "kotlin_language_server", "jdtls" }
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