local M = {}

local servers_file = vim.fn.stdpath("data") .. "/lsps.servers.json"

M.enabled_servers = {}
M.servers = {}

M.load = function()
	for _, file in pairs(vim.fn.readdir(M.opts.path, [[v:val =~ '\.lua$']])) do
		local data = require("lsps." .. file:gsub("%.lua$", ""))
		M.servers[data[1]] = {}
		data.enabled = type(data.enabled) == "nil" and true or data.enabled
		data.filename = M.opts.path .. file

		if data.enabled then
			M.servers[data[1]] = data
		end
		M.servers[data[1]].enabled = data.enabled
		M.enabled_servers[data[1]] = data.enabled
	end
end

M.create_json = function()
	local file = io.open(servers_file, "w")

	if not file then
		vim.notify("Error opening file")
		return
	end

	file:write(vim.json.encode(M.enabled_servers))
	file:flush()
end

M.from_json = function()
	local file = io.open(servers_file, "r")

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

M.update_json = function(server)
	local file = io.open(servers_file, "r")
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

	M.enabled_servers = data
	M.create_json()
end

local function toggle_server(server)
	M.update_json(server)
end

M.telescope_toggle = function()
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local telescope_picker = require("telescope.pickers")

	local function new_finder()
		local server_data = {}
		for server, _ in pairs(M.servers) do
			table.insert(server_data, { server, M.servers[server].enabled })
		end

		return finders.new_table({
			results = server_data,
			entry_maker = function(entry)
				local display = (entry[2] and "[Enabled]" or "[Disabled]") .. " " .. entry[1]

				return {
					ordinal = entry[1],
					display = display,

					filename = M.servers[entry[1]].filename,
					server = entry[1],
					enabled = entry[2],
				}
			end,
		})
	end

	local function new_previewer()
		local putils = require("telescope.previewers.utils")
		local from_entry = require("telescope.from_entry")

		local previewers = require("telescope.previewers.buffer_previewer")

		return previewers.new_buffer_previewer({
			title = "Lsp Config Preview",
			get_buffer_by_name = function(_, entry)
				return entry.server
			end,

			define_preview = function(self, entry)
				-- HIGHLIGHT
				-- putils.highlighter(bufnr, "diff", opts)

				local p = from_entry.path(entry, true, false)
				if p == nil or p == "" then
					return
				end

				conf.buffer_previewer_maker(p, self.state.bufnr, {
					bufname = self.state.bufname,
					winid = self.state.winid,
					preview = nil,
					file_encoding = nil,
				})
			end,
		})
	end

	telescope_picker
		.new({}, {
			prompt_title = "LSP Servers",
			finder = new_finder(),
			sorter = conf.generic_sorter({}),
			previewer = new_previewer(),
			attach_mappings = function(prompt_bufnr, map)
				local actions_state = require("telescope.actions.state")

				local toggle = function()
					local picker = actions_state.get_current_picker(prompt_bufnr)

					local selection = actions_state.get_selected_entry()

					if selection == nil then
						return
					end

					toggle_server(selection.server)

					M.from_json()

					-- temporarily register a callback which keeps selection on refresh
					local s = picker:get_selection_row()
					local callbacks = { unpack(picker._completion_callbacks) } -- shallow copy
					picker:register_completion_callback(function(self)
						self:set_selection(s)
						self._completion_callbacks = callbacks
					end)

					picker:refresh(new_finder(), { reset_prompt = false })
				end

				local go_to = function()
					local selection = actions_state.get_selected_entry()

					if selection == nil then
						return
					end

					require("telescope.actions").close(prompt_bufnr)

					vim.cmd.edit(selection.filename)
				end

				local go_to_key = M.opts.prompt_keys.go_to
				if go_to_key == "<CR>" then
					map("i", go_to_key, go_to)
				end
				map("n", go_to_key, go_to)

				local toggle_key = M.opts.prompt_keys.toggle
				if toggle_key == "<CR>" then
					map("i", toggle_key, toggle)
				end
				map("n", toggle_key, toggle)

				return true
			end,
		})
		:find()
end

M.setup_servers = function()
	local lspconfig = require("lspconfig")

	for server, config in pairs(M.servers) do
		local _config = config.config
		config.config = nil

		if M.enabled_servers[server] then
			local opts = config

			if type(_config) == "function" then
				opts = {
					config = function(lspconfig_)
						return _config(lspconfig_, config)
					end,
				}
			end

			lspconfig[server].setup(opts)
		end
	end
end

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", {
		path = vim.fn.stdpath("config") .. "/lua/lsps/",
		keys = {
			open = "<leader>ts",
		},
		prompt_keys = {
			go_to = "<CR>",
			toggle = "e",
		},
	}, opts or {})

	M.load()
	M.from_json()
	M.setup_servers()

  vim.keymap.set("n", M.opts.keys.open, M.telescope_toggle)

	vim.api.nvim_create_user_command("ToggleServer", function()
		M.telescope_toggle()
	end, {})
end

return M
