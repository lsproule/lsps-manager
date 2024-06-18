local M = {}

local lspconfig = require("lspconfig")

M.enabled_servers = {}
M.servers = {}

M.path = ""

M.initial_load = function()
  for _, file in pairs(vim.fn.readdir(M.path, [[v:val =~ '\.lua$']])) do
    --vim.notify(M.path .. file)
    local data = require("lsps." .. file:gsub("%.lua$", ""))
    M.servers[data[1]] = {}
    --vim.notify(vim.inspect(data))
    if data.enabled then
      --vim.notify(vim.inspect(file))
      M.servers[data[1]] = data
    end
    M.servers[data[1]].enabled = data.enabled
    M.enabled_servers[data[1]] = data.enabled
  end
end

M.to_json = function()
  --local M.enabled_servers = {}
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "w")
  if not file then
    vim.notify("Error opening file")
    return
  end
  file:write(vim.json.encode(M.enabled_servers))
end

M.from_json = function()
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "r")

  if not file then
    M.create_json()
    return
  end

  local data = file:read("*a")
  if data == nil then
    vim.notify("No data in file")
    return
  end

  for server, enabled in pairs(vim.json.decode(data)) do
    M.servers[server].enabled = enabled
  end
end

M.create_json = function()
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "w")
  if not file then
    return
  end
  file:write(vim.json.encode(M.enabled_servers))
  file:flush()
end

M.update_json = function(server)
  local file = io.open(vim.fn.stdpath("config") .. "/servers.json", "r")
  if not file then
    M.create_json()
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
    return
  end
  file:write(vim.json.encode(data))
  file:flush()
end

local function toggle_server(server)
  M.update_json(server)
end

M.telescope_toggle = function()
  M.from_json()
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local telescope_picker = require("telescope.pickers")
  local server_data = {}
  for server, _ in pairs(M.servers) do
    local server_string = "" .. server .. " " .. (M.servers[server].enabled and "enabled" or "disabled")
    table.insert(server_data, server_string)
  end

  telescope_picker
      .new({}, {
        prompt_title = "LSP Servers",
        finder = finders.new_table({
          results = server_data,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          local toggle = function()
            local selection = require("telescope.actions.state").get_selected_entry()
            local server = selection.value:match("(.+)%s")
            toggle_server(server)
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

M.setup = function(opts)
  M.path = opts.path or vim.fn.stdpath("config") .. "/lua/lsps/"
  M.initial_load()
  M.from_json()
  M.setup_servers()
  vim.api.nvim_create_user_command("ToggleServer", function()
    M.telescope_toggle()
  end, {})
end

return M
