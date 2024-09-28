local data_path = vim.fn.stdpath("data")
local Path = require("plenary.path")
local queue = require('transmit.sftp-queue')

local sftp = {
	server_config = {}
}

local transmit_server_data = string.format("%s/transmit.json", data_path)

local function get_transmit_data()
    local path = Path:new(transmit_server_data)
    local exists = path:exists()

    if not exists then
        path:write('{}', 'w')
    end

    local transmit_data = path:read()

    return vim.json.decode(transmit_data)
end

function sftp.get_selected_server()
    local current_transmit_data = get_transmit_data()
    local working_dir = vim.loop.cwd()

	if not current_transmit_data[working_dir] or not current_transmit_data[working_dir]['server_name'] then
		return false
	end

    return current_transmit_data[working_dir]['server_name']
end

function sftp.parse_sftp_config(config_location)
    local path = Path:new(config_location)
    local exists = path:exists()

    if not exists then return false end

    local sftp_config_data = path:read()

    sftp.server_config = vim.json.decode(sftp_config_data)

	return sftp.server_config
end

function sftp.get_sftp_server_config()
    local selected_server = sftp.get_selected_server()

	if not selected_server then return false end

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

local function on_sftp_event(chanid, data, event)
	local queue_item = queue.get_current_queue_item()

	if event == "exit" then
		return
	end

	if not queue_item then
		vim.fn.chansend(chanid, "exit\n")
	end

	if queue_item.finished_response and string.find(data, queue_item.finished_response) then
		local next_process = queue.get_next_queue_process()

		if not next_process then
			vim.fn.chansend(chanid, "exit\n")
			return
		end

		vim.fn.chansend(chanid, next_process.process)
		return
	end

end

local function escapePattern(str)
    local specialCharacters = "([%.%+%-%%%[%]%*%?%^%$%(%)])"
    return (str:gsub(specialCharacters, "%%%1"))
end

function sftp.generate_upload_proceses(file, working_dir)
    local current_config = sftp.get_sftp_server_config()
    local current_transmit_data = get_transmit_data()

	if not current_transmit_data or not current_config then return false end

    local relative_path =  string.gsub(file, escapePattern(working_dir), '')

    local selected_remote = current_transmit_data[working_dir]['remote']
    local remote_path = current_config['remotes'][selected_remote]

    local directory_path = relative_path:match("^(.*[\\/])([^\\/]+)$") or ""

	if directory_path ~= "" then
		if string.sub(directory_path, 1, 1) == '/' then
			directory_path = string.sub(directory_path, 2)
		end

		local put_script = "put " .. file .. " -o " .. relative_path .. " \n"

		return {
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

	if not current_config or not current_transmit_data then return false end

    local selected_remote = current_transmit_data[working_dir]['remote']
    local remote_path = current_config['remotes'][selected_remote]
	local change_directory = "cd " .. remote_path ..  "\n pwd\n"

    return {
		{
			finished_response = 'Connected to ' .. current_config.credentials.host,
		},
        {
            process = change_directory,
            finished_response = remote_path,
            failed_responses = {
                'Failure',
				'No such file or directory'
            }
        },
    }
end

function sftp.generate_remove_proceses(path, working_dir)
    local current_config = sftp.get_sftp_server_config()
    local current_transmit_data = get_transmit_data()

	if not current_config or not current_transmit_data then return false end

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

function sftp.start_connection()
    local config = sftp.get_sftp_server_config()

	if not config then return false end

    local host = config.credentials.host
    local username = config.credentials.username

    return vim.fn.jobstart(
        {
			"sftp",
			username .. "@" .. host
        },
        {
            pty = false,
			stdout_buffered = false,
			stderr_buffered = false,
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
