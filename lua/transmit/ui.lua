local watcher = require('transmit.watcher')
local sftp = require('transmit.sftp')

local ui, closing_keys = {}, {'<Esc>'}

local function select_remote(server_name)
    local remote_index = vim.fn.line(".")
    local remotes = {}

    if sftp.server_config[server_name] == nil or remote_index == nil then
        return false
    end

    for key, _ in pairs(sftp.server_config[server_name]['remotes']) do
        table.insert(remotes, key)
    end

    sftp.update_transmit_server_config(server_name, remotes[remote_index])

    -- close both windows
    vim.api.nvim_command(':close')
    vim.api.nvim_command(':close')

	local server_config = sftp.get_sftp_server_config()

	if not server_config then return false end

    if server_config.watch_for_changes ~= nil and server_config.watch_for_changes == true then
		watcher.watch_directory(vim.loop.cwd())
	end
end


local function select_server()
    local idx = vim.fn.line(".")
    local new_buf = vim.api.nvim_create_buf(false, true)

    if idx == 1 then
        sftp.update_transmit_server_config('none', nil)
        vim.api.nvim_command(':close')

        return true
    end

    idx = idx - 1

    local width, height = 40, 10

    local ui_list = vim.api.nvim_list_uis()
    local ui_iter = pairs(ui_list)

    local current_key, _ = ui_iter(ui_list)

    local ui_window = ui_list[current_key]

    for _,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(new_buf, 'n', v, ':close<CR>', {})
    end

    local new_opts = {
        title = "Transmit remotes selection",
        title_pos = "left",
        relative = "editor",
        width = width,
        height = height,
        col = (ui_window.width/2) - (width/2),
        row = (ui_window.height/2) - (height/2),
        style = "minimal",
        border = "single"
    }

    local sftp_servers, remotes = {}, {}

    for key, _ in pairs(sftp.server_config) do
        table.insert(sftp_servers, key)
    end

    for key, _ in pairs(sftp.server_config[sftp_servers[idx]]['remotes']) do
        table.insert(remotes, key)
    end

    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, remotes)
    vim.api.nvim_buf_set_option(new_buf, 'modifiable', false)

    -- Create the nested floating window inside the main floating window
    vim.api.nvim_open_win(new_buf, true, new_opts)
    vim.api.nvim_buf_set_keymap(new_buf, 'n', '<CR>', select_remote(sftp_servers[idx]), {})
  end


function ui.open_select_window()
    local buf = vim.api.nvim_create_buf(false, true)

    local width, height = 40, 10

    local ui_list = vim.api.nvim_list_uis()
    local ui_iter = pairs(ui_list)

    local current_key, _ = ui_iter(ui_list)
    local uiWindow = ui_list[current_key]

    for _,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(buf, 'n', v, ':close<CR>', {})
    end

    local opts = {
        title = "Transmit server selection",
        title_pos = "left",
        relative = "editor",
        width = width,
        height = height,
        col = (uiWindow.width/2) - (width/2),
        row = (uiWindow.height/2) - (height/2),
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
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', select_server(), {})

    for _,v in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(buf, 'n', v, ':close<CR>', {})
    end
end

return ui
