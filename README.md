# LSPS Manager


## Getting Started

Lazy

```lua
return {
    "lsproule/lsp-manager",
    config = function()
        require("lsp-manager").setup({
            path = vim.fn.stdpath("config") .. "/lua/lsps/",
            keys = {
                open = "<leader>ts",
            },
            prompt_keys = {
                go_to = "<CR>",
                toggle = "e",
            },
	    })
    end
}
```

in your lua directory you can now create an lsps/ directory and you can configure lsps like this

in `lsps/emmet.lua`
```lua
return {
    "emmet_ls"
}
```

if you want to pass options it can be done like this
in `lua_ls.lua`

```lua
return {
  "lua_ls",
  opts = {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_dir = require("lspconfig.util").root_pattern(".git", vim.fn.getcwd()),
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = vim.split(package.path, ";"),
        },
        diagnostics = {
          enable = true,
          globals = { "vim", "use" },
        },
        workspace = {
          library = { vim.api.nvim_get_runtime_file("", true), vim.env.VIMRUNTIME },
        },
        telemetry = {
          enable = false,
        },
      },
    },
  },
}
```

if you want complete control you can do it with a config block like this

in `clang.lua`
```lua
return {
	"clangd",
	config = function(lspconfig)
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		lspconfig.clangd.setup({
			cmd = { "clangd", "--background-index", "--offset-encoding=utf-16" },
			capabilities = capabilities,
			filetypes = { "c", "cpp", "objc", "objcpp" },
			root_dir = lspconfig.util.root_pattern("compile_commands.json", "compile_flags.txt", ".git"),
			init_options = {
				clangdFileStatus = true,
				usePlaceholders = true,
				completeUnimported = true,
				semanticHighlighting = true,
			},
		})
	end,
}
```

you can activate and deactivate lsps or jump to the config with
`<leader>ts`

