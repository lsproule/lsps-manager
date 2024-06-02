local M

local lspconfig = require("lspconfig")

M.enabled_servers = {}
M.servers = {}

M.path = ""

M.setup = function(path)
  M.path = path
  M.enabled_servers = from_json(M.enabled_servers) or M.enabled_servers 
  M.initial_load()
  M.from_json()
  M.to_json()
  M.setup_servers()
  vim.api.nvim_create_user_command("ToggleServer", function()
    M.telescope_toggle()
  end, {})
end


M.initial_load  = function()
  for _, lsp in ipairs(vim.fn.readdir(M.path)) do
    if lsp:match("lua$") then
      require(path .. lsp)
      if lsp.enabled then
        M.servers[lsp.name] = lsp
      end
      M.enabled_servers[lsp.name] = lsp.enabled
    end
  end
end

local function to_json()
  local M.enabled_servers = {}
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "w")
  if not file then
    print("Error opening file")
    return
  end
  file:write(vim.json.encode(M.enabled_servers))
end


M.from_json = function(servers)
  servers = servers or {}
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "r")

  if not file then
    print("Error opening file")
    return
  end

  local data = file:read("*a")

  if data == nil then
    print("No data in file")
    return
  end

  for server, enabled in pairs(vim.json.decode(data)) do
    servers[server].enabled = enabled
  end

  return servers
end

M.update_json = update_json(server)
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "r")
  if not file then
    print("Error opening file")
    return
  end
  local data = vim.json.decode(file:read("*a"))
  if data[server] == nil then
    data[server] = true
  elseif data[server] then
    data[server] = false
  elseif not data[server] then
    data[server] = true
  else
    data[server] = not data[server]
  end
  file = io.open(vim.fn.stdpath("config") .. "/servers.json", "w")
  if not file then
    print("Error opening file")
    return
  end
  file:write(vim.json.encode(data))
  file:flush()
end

local function toggle_server(server)
  update_json(server)
end

--TODO: Create an lsp autotesting

M.telescope_toggle = function()
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local telescope_picker = require("telescope.pickers")
  local server_names = {}
  for server, _ in pairs(M.servers) do
    table.insert(server_names, server)
  end
  telescope_picker
      .new({}, {
        prompt_title = "LSP Servers",
        finder = finders.new_table({
          results = server_names,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          local toggle = function()
            local selection = require("telescope.actions.state").get_selected_entry()
            toggle_server(selection.value)
            require("telescope.actions").close(prompt_bufnr)
          end
          map("i", "<CR>", toggle)
          map("n", "<CR>", toggle)
          return true
        end,
      })
      :find()
end

M.setup_servers = function()
  for server, config in pairs(M.servers) do
    if M.enabled_servers[server] then
      lspconfig[server].setup(config)
    end
  end
end

return M
