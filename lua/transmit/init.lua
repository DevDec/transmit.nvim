local Sftp = require("transmit.sftp")
local Events = require("transmit.events")
local Util = require("transmit.util")
local Ui = require("transmit.ui")

---@class Transmit
---@field config_path[string]

---@class Transmit
---@field ui TransmitUI
local Transmit = {}

Transmit.__index = Transmit

function Transmit.new(sftp)
	local transmit = setmetatable({
	},
	Transmit)

	transmit.ui = Ui:new(transmit, sftp)

	return transmit
end

<<<<<<< Updated upstream
function transmit.setup(config)
=======
function Transmit:setup(config)
>>>>>>> Stashed changes
    if next(config) == nil then
        return false
    end

<<<<<<< Updated upstream
	vim.cmd('command TransmitOpenSelectWindow lua require("transmit").open_select_window()')
	vim.cmd('command TransmitUpload lua require("transmit").upload_file()')
	vim.cmd('command TransmitRemove lua require("transmit").remove_path()')

	sftp.parse_sftp_config(config.config_location)
=======
	Sftp:parse_sftp_config(config.config_location)
>>>>>>> Stashed changes

	vim.print(Sftp)

	local server_config = Sftp:get_sftp_server_config()

	if not server_config then
		return false
	end

    if server_config.watch_for_changes ~= nil and server_config.watch_for_changes == true then
		self:watch_current_working_directory()
    elseif server_config.upload_on_bufwrite ~= nil then
        vim.cmd([[
            augroup Transmit:utoCommands
            autocmd!
            autocmd BufWritePost * lua require("transmit").upload_file()
            augroup END
        ]])
<<<<<<< Updated upstream
    end

	vim.print('got here')

    end

function transmit.get_current_server()
    return sftp.get_current_server(vim.loop.cwd())
end

function transmit.get_server(directory)
	return sftp.get_current_server(directory)
end

function transmit.select_server()
    local idx = vim.fn.line(".")
    local new_buf = vim.api.nvim_create_buf(false, true)
=======
>>>>>>> Stashed changes

    end

    vim.cmd('command TransmitOpenSelectWindow lua require("transmit").ui:open_select_window()')
    vim.cmd('command TransmitUpload lua require("transmit"):upload_file()')
    vim.cmd('command TransmitRemove lua require("transmit"):remove_path()')

	Events:new(Sftp)

	Transmit:new(Sftp)
end

function Transmit:get_current_server()
    return Sftp:get_current_server(vim.loop.cwd())
end

function Transmit:get_server(directory)
	return Sftp:get_current_server(directory)
end

function Transmit:select_remote(server_name)
    local remote_index = vim.fn.line(".")
    local remotes = {}

    if Sftp.server_config[server_name] == nil or remote_index == nil then
        return false
    end

    for key, _ in pairs(Sftp.server_config[server_name]['remotes']) do
        table.insert(remotes, key)
    end

    Sftp:update_transmit_server_config(server_name, remotes[remote_index])

    -- close both windows
    vim.api.nvim_command(':close')
    vim.api.nvim_command(':close')

	local server_config = Sftp:get_sftp_server_config()

	if not server_config then
		return false
	end

    if server_config.watch_for_changes ~= nil and server_config.watch_for_changes == true then
		self:watch_current_working_directory()
	end
end

function Transmit:watch_directory(directory)
	if Sftp.server_config[self:get_server(directory)] == nil or Sftp.server_config[self:get_server(directory)] == 'none' then
		return false
	end

	if Sftp.server_config[self:get_server(directory)]["watch_for_changes"] == nil or Sftp.server_config[self:get_server(directory)]['watch_for_changes'] == false then
		return false
	end

	local excluded = Sftp.server_config[self:get_server(directory)]['exclude_watch_directories'] or {}

	Events.watch_directory_for_changes(directory, excluded)
end

function Transmit:watch_current_working_directory()
    if Sftp.server_config[self:get_current_server()] == nil or Sftp.server_config[self:get_current_server()] == 'none' then
        return false
    end

    if Sftp.server_config[self:get_current_server()]["watch_for_changes"] == nil or Sftp.server_config[self:get_current_server()]['watch_for_changes'] == false then
        return false
    end

	local excluded = Sftp.server_config[self:get_current_server()]['exclude_watch_directories'] or {}

	Events:watch_directory_for_changes(vim.loop.cwd(), excluded)
end

function Transmit:remove_path(path)
    Util:remove_path(path)
end

function Transmit:upload_file(file)
    Util:upload_file(file)
end

function Transmit:remove_watch(directory)
	if (directory == nil) then
		Events:remove_all_watchers()
	else
		Events:remove_all_watchers_for_root(directory)
	end
end

return Transmit
