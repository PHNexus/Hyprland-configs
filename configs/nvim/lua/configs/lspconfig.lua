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

local java_home = "/usr/lib/jvm/default"

-- Helper function to detect the installed Java major version dynamically
local function get_java_version(path)
  local handle = io.popen(path .. "/bin/java -version 2>&1")
  if not handle then return "JavaSE-21" end -- Safe fallback
  local result = handle:read("*a")
  handle:close()

  -- Extracts major version from outputs like 'version "21..."' or 'version "1.8..."'
  local major = result:match('version "([%d]+)')
  if not major then
    major = result:match('version "1%.([%d]+)')
  end

  if major then
    local num = tonumber(major)
    if num == 1 then
      return "JavaSE-1.8"
    else
      return "JavaSE-" .. major
    end
  end

  return "JavaSE-21" -- Fallback if parsing fails
end

local java_se_name = get_java_version(java_home)

vim.lsp.config("jdtls", {
  cmd = { "jdtls" },
  root_dir = vim.fs.root(0, { ".git", "pom.xml", "build.gradle", "build.gradle.kts" }),
  settings = {
    java = {
      home = java_home,
      configuration = {
        updateBuildConfiguration = "automatic",
        runtimes = {
          {
            name = java_se_name, -- Dynamically sets "JavaSE-21", "JavaSE-27", etc.
            path = java_home,
            default = true,
          },
        },
      },
    },
  },
})

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

-- Single call with all servers
local servers = {
  "html",
  "cssls",
  "jsonls",
  "unocss",
  "tailwindcss",
  "svelte",
  "basedpyright",
  "ruff",
  "astro",
  "kotlin_language_server",
  "jdtls",
  "vtsls",
  "vue_ls",
}

vim.lsp.enable(servers)
