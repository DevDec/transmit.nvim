local Sftp = {}

---@class TransmitUI
---@field transmit Transmit
local TransmitUI = {}

local closing_keys = {'<Esc>'}

TransmitUI.__index = TransmitUI

function TransmitUI:new(transmit, sftp)
	local ui = setmetatable({
		transmit = transmit
	}, TransmitUI)

	Sftp = sftp

	return ui
end

function TransmitUI:open_select_window()
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

    local Sftp_servers = {
        "none"
    }

    for key, _ in pairs(Sftp.server_config) do
         table.insert(Sftp_servers, key)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, Sftp_servers)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    vim.api.nvim_open_win(buf, 1, opts)

	TransmitUI:select_server()

    for _,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(buf, 'n', v, ':close<CR>', {})
    end
end

function TransmitUI:select_server()
    local idx = vim.fn.line(".")
    local new_buf = vim.api.nvim_create_buf(false, true)

    if idx == 1 then
        Sftp:update_transmit_server_config('none', nil)
        vim.api.nvim_command(':close')

        return true
    end

    idx = idx - 1

    local width = 40
    local height = 10

    local ui_list = vim.api.nvim_list_uis()
    local ui_iter = pairs(ui_list)

    local current_key, _ = ui_iter(ui_list)

    local ui = ui_list[current_key]

    for _,v in pairs(closing_keys) do
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

    for key, _ in pairs(Sftp.server_config) do
        table.insert(sftp_servers, key)
    end

    local remotes = {}

    for key, _ in pairs(Sftp.server_config[sftp_servers[idx]]['remotes']) do
        table.insert(remotes, key)
    end

    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, remotes)
    vim.api.nvim_buf_set_option(new_buf, 'modifiable', false)

    -- Create the nested floating window inside the main floating window
    vim.api.nvim_open_win(new_buf, true, new_opts)

	self:select_remote(sftp_servers[idx])
end

function TransmitUI:select_remote(server_name)
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

	if server_config and server_config.watch_for_changes then
		TransmitUI.transmit:watch_current_working_directory()
	end
end

return TransmitUI
