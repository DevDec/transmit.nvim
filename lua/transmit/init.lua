local M = {}
local data_path = vim.fn.stdpath("data")

local server_config = {}
local selected_server_mappings = {
    aim_dev = "declanb"
}

local function sftp_connect(server)
    local host = server_config[server].credentials.host
    local username = server_config[server].credentials.username
    local identity_file = server_config[server].credentials.identity_file
    local remote_path = server_config[server].mappings[selected_server_mappings[server]].remote_path

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

local function delete_remote_file(chanid, server)
    local remove_string = 'rm composer.json \n'

    vim.fn.chansend(chanid, remove_string)
end

local function upload_file(chanid, server)
    local local_path = server_config[server].mappings[selected_server_mappings[server]].local_path

    vim.fn.chansend(chanid, 'put ' .. local_path .. 'composer.json \n')
end

function M.send_file(server)
    local chanid = sftp_connect('aim_dev')

    local local_path = server_config[server].mappings[selected_server_mappings[server]].local_path

    local f = io.open(local_path .. 'composer.json', "r")
    local file_exists =  f ~= nil and io.close(f)

    if file_exists == false then
        delete_remote_file(chanid, 'aim_dev')
    else
        upload_file(chanid, 'aim_dev')
    end

    vim.fn.chansend(chanid, 'exit \n')
end

function M.setup(config)
    if next(config) == nil then
        return
    end

    server_config = config
end

M.setup({
    aim_dev = {
        credentials = {
            host = "52.87.27.131",
            username = "declan.brown",
            identity_file = "~/.ssh/id_declanb"
        },
        mappings =  {
            declanb = {
                local_path = "/Volumes/T7/storeVisionPep/",
                -- local_path = "~/projects/storeVisionPep/",
                remote_path = "workspace.declanb"
            },
            declanb2 = {
                local_path = "~/projects/storeVisionPep/",
                remote_path = "E:/sites/workspace.declanb2/"
            },
        },
    }
})

M.send_file('aim_dev')

return M;
