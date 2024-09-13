local data_path = vim.fn.stdpath("data")
local Path = require("plenary.path")
local Job = require('plenary.job')

local sftp = {}

local queue = {}

sftp.server_config = {}

local transmit_server_data = string.format("%s/transmit.json", data_path)

sftp.has_active_queue = function()
	return next(queue) ~= nil
end

-- function sftp.has_active_queue()
--     return next(queue) ~= nil
-- end

local function get_current_queue_item()

    local iter = pairs(queue)

    local current_key, _ = iter(queue)

    if queue[current_key] == nil then
        return false
    end

    return queue[current_key]
end

local function get_next_queue_process()
    local current_queue_item = get_current_queue_item()

    if current_queue_item == nil or current_queue_item == false then
        return false
    end

    local processes_iter = pairs(current_queue_item.processes)
    local processes_key, _ = processes_iter(current_queue_item.processes)

    if current_queue_item.processes[processes_key] == nil then
        current_queue_item.processes = nil

        local iter = pairs(queue)

        local current_key, _ = iter(queue)

        if queue[current_key] == nil then
            return false
        end

        queue[current_key] = nil

        return get_next_queue_process()
    end

    return current_queue_item.processes[processes_key]
end

local function reset_current_process()
    local iter = pairs(queue)

    local current_key, _ = iter(queue)

    local processes_iter = pairs(queue[current_key].processes)
    local processes_key, _ = processes_iter(queue[current_key].processes)

    queue[current_key].processes[processes_key] = nil
end

local function update_current_process_status(status, forceFinished)
    local iter = pairs(queue) local current_key, _ = iter(queue)

    local processes_iter = pairs(queue[current_key].processes)
    local processes_key, _ = processes_iter(queue[current_key].processes)

    queue[current_key].processes[processes_key]['status'] = status

    if forceFinished == true then
        queue[current_key].processes[processes_key]['forceFinished'] = true
    end
end

local function get_transmit_data()
    local path = Path:new(transmit_server_data)
    local exists = path:exists()

    if not exists then
        path:write('{}', 'w')
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

function sftp.parse_sftp_config(config_location)
    local path = Path:new(config_location)
    local exists = path:exists()

    if not exists then
        return false
    end

    local sftp_config_data = path:read()

    sftp.server_config = vim.json.decode(sftp_config_data)
end

function sftp.get_sftp_server_config()
    local selected_server = get_selected_server()

    if selected_server == false then
        return false
    end

    return sftp.server_config[selected_server]
end

function sftp.update_transmit_server_config(server_name, remote)
    local working_dir = vim.loop.cwd()
    local current_transmit_data = get_transmit_data()

    if server_name == 'none' then
        current_transmit_data[working_dir] = nil
    elseif current_transmit_data[working_dir] == nil then
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
    local current_queue_item = get_current_queue_item()

    if next(queue) == nil then
        vim.fn.chanclose(chanid)

        if data == 0 then
            vim.print('Sftp process finished.')
        end

        return true
    end

    if current_queue_item == nil or current_queue_item == false then
        queue = {}
        vim.fn.chansend(chanid, 'exit\n')

        return false
    end

    for k,v in pairs(data) do
        if v == nil then
            goto continue
        end

        local current_config = sftp.get_sftp_server_config()

        if current_queue_item.type == "connect" and string.find(v, 'lftp ' .. current_config.credentials.username .. '@' .. current_config.credentials.host .. ':~>') then
            local next_queue_process = get_next_queue_process()
            vim.print("Connected to server: " .. current_config.credentials.host)
            vim.fn.chansend(chanid, next_queue_process["process"])
            return true
        end

        local next_queue_process = get_next_queue_process()

        if next_queue_process == false then
            queue = {}
            vim.fn.chansend(chanid, 'exit\n')
            return false
        end

        if v ~= nil and (next_queue_process["status"] == true and string.find(v, next_queue_process["finished_response"]) or (next_queue_process["forceFinished"])) then
            reset_current_process()
            next_queue_process = get_next_queue_process()

            if next_queue_process == false then
                queue = {}
                vim.fn.chansend(chanid, 'exit\n')
                return false
            end

            vim.fn.chansend(chanid, next_queue_process["process"])
            return true
        end

        if next_queue_process["status"] == false and string.find(v, next_queue_process["success_response"]) then
            if current_queue_item["type"] == "upload" and string.find(next_queue_process["process"], "put") then
                vim.print("Uploading file: " .. current_queue_item["filename"] .. " succeeded.")
            end

            if current_queue_item["type"] == "remove" and string.find(next_queue_process["process"], "rm") then
                vim.print("Removing file: " .. current_queue_item["filename"] .. " succeeded.")
            end

            update_current_process_status(true)
        elseif next_queue_process["status"] == false and string.find(v, next_queue_process["finished_response"]) then
            if current_queue_item["type"] == "upload" and string.find(next_queue_process["process"], "put") then
                vim.print("Uploading file: " .. current_queue_item["filename"] .. " succeeded.")
            end

			if current_queue_item["type"] == "remove" and string.find(next_queue_process["process"], "rm") then
				vim.print("Removing file: " .. current_queue_item["filename"] .. " succeeded.")
			end

            reset_current_process()
            next_queue_process = get_next_queue_process()

            if next_queue_process == false then
                queue = {}
                vim.fn.chansend(chanid, 'exit\n')
                return false
            end

            vim.fn.chansend(chanid, next_queue_process["process"])
            return true
        else
            for _, failed_response_value in pairs(next_queue_process["failed_responses"]) do
                if string.find(v, failed_response_value) then
                    if next_queue_process["accepts_failures"] == false then
                        if current_queue_item["type"] == "upload" then
                            vim.print("Uploading file: " .. current_queue_item["filename"] .. " failed with response: " .. v)
                        end

                        update_current_process_status(true, true)
                        goto continue
                    end

                    update_current_process_status(true, true)
                end
            end
        end

        ::continue::
    end
end

local function on_sftp_event(chanid, data)
    process_next_queue_item(chanid, data)
end

local function escapePattern(str)
    local specialCharacters = "([%.%+%-%%%[%]%*%?%^%$%(%)])"
    return (str:gsub(specialCharacters, "%%%1"))
end

function sftp.generate_upload_proceses(file, working_dir)
    local current_config = sftp.get_sftp_server_config()
    local current_transmit_data = get_transmit_data()

    local relative_path =  string.gsub(file, escapePattern(working_dir), '')

    local selected_remote = current_transmit_data[working_dir]['remote']
    local remote_path = current_config['remotes'][selected_remote]

    local directory_path = relative_path:match("^(.*[\\/])([^\\/]+)$") or ""
    if directory_path ~= "" then
        if string.sub(directory_path, -1, -1) == '/' then
            directory_path = string.sub(directory_path, 1, -2)
        end
    end

	if directory_path ~= "" then
		if string.sub(directory_path, 1, 1) == '/' then
			directory_path = string.sub(directory_path, 2)
		end

		if string.sub(relative_path, 1, 1) == '/' then
			relative_path = string.sub(relative_path, 2)
		end

		local make_dir = 'mkdir -p ' .. directory_path .. " \n"
		if string.sub(relative_path, 1, 1) == '/' then
			relative_path = string.sub(relative_path, 2)
		end

		local put_script = "put " .. file .. " -o " .. relative_path .. " \n"

		return {
			-- {
			-- 	process = make_dir,
			-- 	success_response = 'mkdir ok',
			-- 	finished_response = 'lftp ' .. current_config.credentials.username .. '@' .. current_config.credentials.host .. ':/' .. remote_path,
			-- 	failed_responses = {
			-- 		'failed',
			-- 		'No such file or directory'
			-- 	},
			-- 	status = false,
			-- 	accepts_failures = true,
			-- 	forceFinished = true
			-- },
			{
				success_response = 'bytes transferred',
				process = put_script,
				failed_responses = {
					'failed',
					'No such file or directory'
				},
				finished_response = 'lftp ' .. current_config.credentials.username .. '@' .. current_config.credentials.host .. ':/' .. remote_path,
				status = false,
				accepts_failures = false,
				forceFinished = false
			}
		}
	end

    if string.sub(relative_path, 1, 1) == '/' then
        relative_path = string.sub(relative_path, 2)
    end

    local put_script = "put " .. file .. " -o " .. relative_path .. " \n"

    return {
        {
            process = put_script,
            success_response = 'bytes transferred',
            failed_responses = {
                'failed',
                'No such file or directory'
            },
            finished_response = 'lftp ' .. current_config.credentials.username .. '@' .. current_config.credentials.host .. ':/' .. remote_path,
            status = false,
            accepts_failures = false,
            forceFinished = false
        }
    }
end

function sftp.generate_connect_proceses(working_dir)
    local current_config = sftp.get_sftp_server_config()
    local current_transmit_data = get_transmit_data()

    local selected_remote = current_transmit_data[working_dir]['remote']
    local remote_path = current_config['remotes'][selected_remote]

    local change_directory = "cd " .. remote_path .. " \n"

    return {
        {
            process = change_directory,
            success_response = 'cd ok, cwd=/' .. remote_path,
            finished_response = 'lftp ' .. current_config.credentials.username .. '@' .. current_config.credentials.host .. ':/' .. remote_path,
            failed_responses = {
                'Failure'
            },
            status = false,
            accepts_failures = true
        },
    }
end

function sftp.generate_remove_proceses(path, working_dir)
    local current_config = sftp.get_sftp_server_config()
    local current_transmit_data = get_transmit_data()

    local selected_remote = current_transmit_data[working_dir]['remote']
    local remote_path = current_config['remotes'][selected_remote]


	local relative_path =  string.gsub(path, escapePattern(working_dir), '')

    if string.sub(relative_path, 1, 1) == '/' then
        relative_path = string.sub(relative_path, 2)
    end

    local remove_path = "rm -r " .. relative_path .. " \n"

    return {
        {
            process = remove_path,
            success_response = 'rm ok',
            finished_response = 'lftp ' .. current_config.credentials.username .. '@' .. current_config.credentials.host .. ':/' .. remote_path,
            failed_responses = {
                'failed',
            },
            status = false,
            accepts_failures = false
        },
    }
end

function sftp.add_to_queue(type, filename, working_dir, processes)
    local start_queue = false

    if sftp.has_active_queue() == false and type ~= "connect" then
        local connect_processes = sftp.generate_connect_proceses(working_dir)
        sftp.add_to_queue("connect", "", "", connect_processes)

        start_queue = true
    end

    table.insert(queue, {
        type = type,
        filename = filename,
        working_dir = working_dir,
        processes = processes
    })

    if start_queue then
        sftp.start_connection()
    end
end

function sftp.start_connection()
    local config = sftp.get_sftp_server_config()

    local host = config.credentials.host
    local username = config.credentials.username
    local identity_file = config.credentials.identity_file

    local uv = vim.loop

    local stdin = uv.new_pipe(false)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    return vim.fn.jobstart(
        {
        "lftp",
        "sftp://" .. username .. "@" .. host,
        "-u", username .. ",",
        "-e", "set sftp:connect-program \"ssh -i " .. identity_file .. "\"",
        },
        {
            pty = true,
            on_stdout = on_sftp_event,
            on_stderr = on_sftp_event,
            on_exit = on_sftp_event,
        }
    )
end

function sftp.working_dir_has_active_sftp_selection(working_dir)
    local current_transmit_data = get_transmit_data()

    if current_transmit_data[working_dir] == nil or current_transmit_data[working_dir]['remote'] == nil then
        return false
    end

    return true
end

function sftp.get_current_server(working_dir)
    if sftp.working_dir_has_active_sftp_selection(working_dir) == false then
        return 'none'
    end

    local current_transmit_data = get_transmit_data()
    return current_transmit_data[working_dir]["server_name"]
end

return sftp
