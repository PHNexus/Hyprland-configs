local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    javascript = { "biome" },
    javascriptreact = { "biome" },
    typescript = { "biome" },
    typescriptreact = { "biome" },
    vue = { "biome" },
    css = { "biome" },
    html = { "biome" },
    json = { "biome" },
    jsonc = { "biome" },
    svelte = { "deno_fmt" },
    sh = { "shfmt" },
    yaml = { "yamlfmt" },
    astro = { "deno_fmt" },
    toml = { "tombi" },
  },
}

return options