local Path = require("plenary.path")
local data_path = vim.fn.stdpath("data")
local M = {}

local server_config = {}

local transmit_server_data = string.format("%s/transmit.json", data_path)

local function get_transmit_data()
    local path = Path:new(transmit_server_data)
    local exists = path:exists()

    if not exists then
        return {}
    end

    local transmit_data = path:read()

    return vim.json.decode(transmit_data)
end

local function update_transmit_server_config(server_name, remote)
    local working_dir = vim.loop.cwd()
    local current_transmit_data = get_transmit_data()
    if current_transmit_data[working_dir] == nil then
        current_transmit_data[working_dir] = {}
        current_transmit_data[working_dir]["server_name"] = server_name
        current_transmit_data[working_dir]["remote"] = remote
    else
        current_transmit_data[working_dir]["server_name"] = server_name
        current_transmit_data[working_dir]["remote"] = remote
    end

    Path:new(transmit_server_data):write(vim.json.encode(current_transmit_data), "w")
end

local function sftp_connect()
    local current_transmit_data = get_transmit_data()
    local working_dir = vim.loop.cwd()

    if current_transmit_data[working_dir] == nil or current_transmit_data[working_dir]['server_name'] == nil or current_transmit_data[working_dir] == nil then
        return false
    end

    local selected_server = current_transmit_data[working_dir]['server_name']
    local selected_remote = current_transmit_data[working_dir]['remote']

    if server_config[selected_server] == nil
        return false
    end

    local credentials = server_config[selected_server].credentials

    local remote_path = server_config[selected_server].remotes[selected_remote]
    local host = credentials.host
    local username = credentials.username
    local identity_file = credentials.identity_file

    return vim.fn.jobstart(
        {
            'sftp',
            '-i',
            identity_file,
            '-o',
            'UpdateHostKeys=no',
            username .. '@' .. host .. ':' .. remote_path,
        },
        {
            on_stdout = function (chanid, data, _)
                for _, value in pairs(data) do
                    if string.match(value, 'Connected') then
                        return chanid
                    end
                end
            end,
            on_stderr = function (chanid, data, _)
                for _, value in pairs(data) do
                    if string.match(value, 'Connected') then
                        return chanid
                    end
                end
            end,
        }
    )
end

local function delete_remote_file(chanid, file)
    local remove_string = 'rm composer.json \n'

    vim.fn.chansend(chanid, remove_string)
end

local function upload_file(chanid, file)
    vim.fn.chansend(chanid, 'put ' .. file .. ' \n')
end

function M.send_file()
    local file = vim.api.nvim_buf_get_name(0)
    local chanid = sftp_connect()

    if chanid == false then
        return false
    end

    local f = io.open(file, "r")
    local file_exists =  f ~= nil and io.close(f)

    if file_exists == false then
        delete_remote_file(chanid, file)
    else
        upload_file(chanid, file)
    end

    vim.fn.chansend(chanid, 'exit \n')
end

function M.setup(config)
    if next(config) == nil then
        return
    end

    server_config = config
end

function M.select_server(server_name, remote_name)
    update_transmit_server_config(server_name, remote_name)
end

M.setup({
    aim_dev = {
        local_path = "/Volumes/T7/storeVisionPep/",
        credentials = {
            host = "52.87.27.131",
            username = "declan.brown",
            identity_file = "~/.ssh/id_declanb"
        },
        remotes = {
            declanb = "workspace.declanb",
            declanb2 = "workspace.declanb2",
        },
    }
})

return M;
