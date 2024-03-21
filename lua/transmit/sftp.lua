local data_path = vim.fn.stdpath("data")
local Path = require("plenary.path")

local sftp = {}

local queue = {}

sftp.server_config = {}

local transmit_server_data = string.format("%s/transmit.json", data_path)

local function get_current_queue_item()
    local iter = pairs(queue)

    local current_key, current_value = iter(queue)

    if queue[current_key] == nil then
        return false
    end

    return queue[current_key]
end

local function get_transmit_data()
    local path = Path:new(transmit_server_data)
    local exists = path:exists()

    if not exists then
        path:write()
    end

    local transmit_data = path:read()

    return vim.json.decode(transmit_data)
end

local function get_selected_server()
    local current_transmit_data = get_transmit_data()
    local working_dir = vim.loop.cwd()

    if current_transmit_data[working_dir] == nil or current_transmit_data[working_dir]['server_name'] == nil or current_transmit_data[working_dir] == nil then
        return false
    end

    return current_transmit_data[working_dir]['server_name']
end


local function get_sftp_server_config()
    local selected_server = get_selected_server()
    
    if selected_server == false then
        return false
    end

    return sftp.server_config[selected_server]
end

function sftp.update_transmit_server_config(server_name, remote)
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

local function process_next_queue_item(chanid, data)
    vim.print(data)
    local queue_iter = pairs(queue)
    local current_key, current_value = queue_iter(queue)

    local processes_iter = pairs(queue[current_key].processes)
    local processes_key, processes_value = processes_iter(queue[current_key].processes)

    local current_queue_item = get_current_queue_item() 

    if queue[current_key].processes[processes_key] == nil then
        queue[current_key] = nil
        current_queue_item = get_current_queue_item() 
    else
        current_queue_item = queue[current_key]
    end

    if current_queue_item == nil or current_queue_item == false then
        vim.fn.chanclose(chanid)

        return false
    end

    local processes_iter = pairs(current_queue_item.processes)
    local processes_key, processes_value = processes_iter(current_queue_item.processes)

    local current_process = current_queue_item.processes[processes_key]["process"]

    if current_queue_item.processes[processes_key]["status"] == false then
        current_queue_item.processes[processes_key]["status"] = true
        vim.print(current_queue_item.processes[processes_key]['process'])
        vim.fn.chansend(chanid, current_process)
    else 
        for data_key, data_value in pairs(data) do
            local data_start_index, data_end_index = string.find(data_value, 'Failure')
            local directory_start_index, directory_end_index = string.find(data_value, 'mkdir')

            vim.print(data_value)

            -- vim.print(data_value, current_queue_item.processes[processes_key], data_start_index, current_queue_item.processes[processes_key]['accepts_failures'])
            if current_queue_item.processes[processes_key]['accepts_failures'] == false and data_start_index and directory_start_index == false then
                vim.print(data_value .. "stop")
                vim.fn.chanclose(chanid)
                return false
            end

            if data_value == current_queue_item.processes[processes_key]["expected_response"] then
                current_queue_item.processes[processes_key] = nil
            end
        end
   end
end

local function process_connection_event(chanid, sftp_data) local current_config = get_sftp_server_config()
    local credentials = current_config.credentials

    for k,v in pairs(sftp_data) do
        if v == "Connected to " .. credentials.host .. "." then
            process_next_queue_item(chanid)

            return true
        end
    end

    return false
end

local function on_sftp_event(chanid, data, event)
    if event == 'exit' then
        vim.print(data)
        vim.fn.chanclose(chanid)
        return false
    end

    local current_queue_item = get_current_queue_item() 

    if current_queue_item == nil  or current_queue_item == false then
        return false
    end

    if current_queue_item.type == "connect" then
        process_connection_event(chanid, data)
    end

    process_next_queue_item(chanid, data)
end

function sftp.generate_upload_proceses(file, working_dir)
    local current_config = get_sftp_server_config()
    local current_transmit_data = get_transmit_data()

    local relative_path =  string.gsub(file, working_dir, '')
    local selected_remote = current_transmit_data[working_dir]['remote']
    local remote_path = current_config['remotes'][selected_remote]

    local directory_path = relative_path:match("^(.*[\\/])([^\\/]+)$") or ""
    if directory_path ~= "" then
        if string.sub(directory_path, -1, -1) == '/' then
            directory_path = string.sub(directory_path, 1, -2)
        end
    end

    local make_dir = 'mkdir ' .. remote_path .. directory_path .. " \n"
    local put_script = "put -r " .. file .. " " .. remote_path .. relative_path .. " \n"

    return {
        {
            process = make_dir,
            expected_response = "",
            status = false,
            accepts_failures = true
        },
        {
            process = put_script,
            expected_response = "",
            status = false,
            accepts_failures = false
        }
    }
end

function sftp.add_to_queue(type, filename, working_dir, processes)
    table.insert(queue, {
        type = type,
        filename = filename,
        working_dir = working_dir,
        processes = processes 
    })
end

function sftp.start_sftp_connection()
    local config = get_sftp_server_config()

    local host = config.credentials.host
    local username = config.credentials.username
    local identity_file = config.credentials.identity_file

    return vim.fn.jobstart(
        {
            "sftp",
            "-i",
            identity_file,
            "-o",
            "UpdateHostKeys=no",
            username .. '@' .. host,
        },
        {
          on_stdout = on_sftp_event,
          on_stderr = on_sftp_event,
          on_exit = on_sftp_event,
        }
    )
end

return sftp

