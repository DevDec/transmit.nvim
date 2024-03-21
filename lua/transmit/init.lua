local sftp = require("transmit.sftp")

local transmit = {}
local closing_keys = {'<Esc>'}

function transmit.send_file()
    local file = vim.api.nvim_buf_get_name(0)
    local working_dir = vim.loop.cwd()

    local processes = sftp.generate_upload_proceses(file, working_dir)

    sftp.add_to_queue("connect", "", "", {})

    sftp.add_to_queue("upload", file, working_dir, processes)

    sftp.start_sftp_connection()

--     local f = io.open(file, "r")
--     local file_exists =  f ~= nil and io.close(f)
--     if file_exists == false then
--         -- TODO: Implement deleting remote files, this is slightly more complicated so I'm not going to address this just yet.
--         delete_remote_file(chanid, relative_path)
--     else
--         upload_file(chanid, relative_path)
--     end

    -- vim.fn.chansend(chanid, 'exit \n')
end

function transmit.open_select_window()
  local buf = vim.api.nvim_create_buf(false, true)

    local width = 40
    local height = 10

    local ui_list = vim.api.nvim_list_uis()
    local ui_iter = pairs(ui_list)

    local current_key, current_value = ui_iter(ui_list)

    local ui = ui_list[current_key]

    for k,v in pairs(closing_keys) do
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

    local sftp_servers = {}

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
        return
    end

    sftp.server_config = config
end

function transmit.select_server()
    local idx = vim.fn.line(".")
    local new_buf = vim.api.nvim_create_buf(false, true)

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
end

return transmit;
