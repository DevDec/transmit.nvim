local sftp = require("transmit.sftp")
local queue, list = {}, {}

function queue.has_active_queue()
	return not list
end

function queue.get_current_queue_item()
	if not list then return false end

	return list[1]
end

function queue.get_next_queue_process()
    local current_queue_item = queue.get_current_queue_item()

	if not current_queue_item then return false end

    local processes_iter = pairs(current_queue_item.processes)
    local processes_key, _ = processes_iter(current_queue_item.processes)

	if not current_queue_item.processes[processes_key] then
		current_queue_item.processes = nil
        local iter = pairs(queue)
        local current_key, _ = iter(queue)

		if not current_key then return false end

        queue[current_key] = nil

        return queue.get_next_queue_process()
	end

    return current_queue_item.processes[processes_key]
end

function queue.reset_current_process()
    local iter = pairs(queue)
    local current_key, _ = iter(queue)

    local processes_iter = pairs(queue[current_key].processes)
    local processes_key, _ = processes_iter(queue[current_key].processes)

    queue[current_key].processes[processes_key] = nil
end

function queue.update_current_process_status(status, forceFinished)
    local iter = pairs(queue) local current_key, _ = iter(queue)
    local processes_iter = pairs(queue[current_key].processes)
    local processes_key, _ = processes_iter(queue[current_key].processes)

    queue[current_key].processes[processes_key]['status'] = status

    if forceFinished then
        queue[current_key].processes[processes_key]['forceFinished'] = true
    end
end

function queue.add_to_queue(type, filename, working_dir, processes)
    local start_queue = false

    if queue.has_active_queue() == false and type ~= "connect" then
        local connect_processes = sftp.generate_connect_proceses(working_dir)
        queue.add_to_queue("connect", "", "", connect_processes)

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

return queue
