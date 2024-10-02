local sftp = require("transmit.sftp")
local events = require("transmit.events")
local util = require("transmit.util")

local transmit = {}
local closing_keys = {'<Esc>'}

function transmit.open_select_window()
    local buf = vim.api.nvim_create_buf(false, true)

    local width = 40
    local height = 10

    local ui_list = vim.api.nvim_list_uis()
    local ui_iter = pairs(ui_list)

    local current_key, _ = ui_iter(ui_list)

    local ui = ui_list[current_key]

    for _,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(buf, 'n', v, ':close<CR>', {})
    end

    local opts = {
        title = "Transmit server selection",
        title_pos = "left",
        relative = "editor",
        width = width,
        height = height,
        col = (ui.width/2) - (width/2),
        row = (ui.height/2) - (height/2),
        style = "minimal",
        border = "single"
    }

    local sftp_servers = {
        "none"
    }

    for key, _ in pairs(sftp.server_config) do
         table.insert(sftp_servers, key)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, sftp_servers)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    vim.api.nvim_open_win(buf, 1, opts)
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ":lua require('transmit').select_server()<CR>", {})

    for k,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(buf, 'n', v, ':close<CR>', {})
    end
end

function transmit.setup(config)
    if next(config) == nil then
        return false
    end

	vim.cmd('command TransmitOpenSelectWindow lua require("transmit").open_select_window()')
	vim.cmd('command TransmitUpload lua require("transmit").upload_file()')
	vim.cmd('command TransmitRemove lua require("transmit").remove_path()')

	sftp.parse_sftp_config(config.config_location)

	local server_config = sftp.get_sftp_server_config()

	if server_config == nil or server_config == false then
		return false
	end

    if server_config.watch_for_changes ~= nil and server_config.watch_for_changes == true then
		transmit.watch_current_working_directory()
    elseif server_config.upload_on_bufwrite ~= nil then
        vim.cmd([[
            augroup TransmitAutoCommands
            autocmd!
            autocmd BufWritePost * lua require("transmit").upload_file()
            augroup END
        ]])
    end

	vim.print('got here')

    end

function transmit.get_current_server()
    return sftp.get_current_server(vim.loop.cwd())
end

function transmit.get_current_remote()
    return sftp.get_current_remote(vim.loop.cwd())
end

function transmit.get_server(directory)
	return sftp.get_current_server(directory)
end

function transmit.select_server()
    local idx = vim.fn.line(".")
    local new_buf = vim.api.nvim_create_buf(false, true)

    if idx == 1 then
        sftp.update_transmit_server_config('none', nil)
        vim.api.nvim_command(':close')

        return true
    end

    idx = idx - 1

    local width = 40
    local height = 10

    local ui_list = vim.api.nvim_list_uis()
    local ui_iter = pairs(ui_list)

    local current_key, current_value = ui_iter(ui_list)

    local ui = ui_list[current_key]

    for k,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(new_buf, 'n', v, ':close<CR>', {})
    end

    local new_opts = {
        title = "Transmit remotes selection",
        title_pos = "left",
        relative = "editor",
        width = width,
        height = height,
        col = (ui.width/2) - (width/2),
        row = (ui.height/2) - (height/2),
        style = "minimal",
        border = "single"
    }

    local sftp_servers = {}

    for key, _ in pairs(sftp.server_config) do
        table.insert(sftp_servers, key)
    end

    local remotes = {}

    for key, value in pairs(sftp.server_config[sftp_servers[idx]]['remotes']) do
        table.insert(remotes, key)
    end

    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, remotes)
    vim.api.nvim_buf_set_option(new_buf, 'modifiable', false)

    -- Create the nested floating window inside the main floating window
    vim.api.nvim_open_win(new_buf, true, new_opts)
    vim.api.nvim_buf_set_keymap(new_buf, 'n', '<CR>', ":lua require('transmit').select_remote('" .. sftp_servers[idx] .. "')<CR>", {})
  end

function transmit.select_remote(server_name)
    local remote_index = vim.fn.line(".")
    local remotes = {}

    if sftp.server_config[server_name] == nil or remote_index == nil then
        return false
    end

    for key, value in pairs(sftp.server_config[server_name]['remotes']) do
        table.insert(remotes, key)
    end

    sftp.update_transmit_server_config(server_name, remotes[remote_index])

    -- close both windows
    vim.api.nvim_command(':close')
    vim.api.nvim_command(':close')

	local server_config = sftp.get_sftp_server_config()

    if server_config.watch_for_changes ~= nil and server_config.watch_for_changes == true then
		transmit.watch_current_working_directory()
	end
end

function transmit.watch_directory(directory)
	if sftp.server_config[transmit.get_server(directory)] == nil or sftp.server_config[transmit.get_server(directory)] == 'none' then
		return false
	end

	if sftp.server_config[transmit.get_server(directory)]["watch_for_changes"] == nil or sftp.server_config[transmit.get_server(directory)]['watch_for_changes'] == false then
		return false
	end

	local excluded = sftp.server_config[transmit.get_server(directory)]['exclude_watch_directories'] or {}

	events.watch_directory_for_changes(directory, excluded)
end

function transmit.watch_current_working_directory()
    if sftp.server_config[transmit.get_current_server()] == nil or sftp.server_config[transmit.get_current_server()] == 'none' then
        return false
    end

    if sftp.server_config[transmit.get_current_server()]["watch_for_changes"] == nil or sftp.server_config[transmit.get_current_server()]['watch_for_changes'] == false then
        return false
    end

	local excluded = sftp.server_config[transmit.get_current_server()]['exclude_watch_directories'] or {}

    events.watch_directory_for_changes(vim.loop.cwd(), excluded)
end

function transmit.remove_path(path)
    util.remove_path(path)
end

function transmit.upload_file(file)
    util.upload_file(file)
end

function transmit.remove_watch(directory)
	if (directory == nil) then
		events.remove_all_watchers()
	else 
		events.remove_all_watches_for_root(directory)
	end
end

return transmit;
