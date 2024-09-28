local queue, list = {}, {}
local sftp = {}

function queue.has_active_queue()
	return not list
end

function queue.get_current_queue_item()
	if next(list) then return false end

	local _,v = next(list)

	return v
end

function queue.get_next_queue_process()
    local current_queue_item = queue.get_current_queue_item()

	if not current_queue_item then return false end

	queue.reset_current_item()

	if not current_queue_item then return false end

    return current_queue_item
end

function queue.reset_current_process()
	local current_item = queue.get_current_queue_item()

	if not current_item then return false end

	local k,_ = next(list)
	list[k] = nil
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
	if next(sftp) == nil then
		sftp = require("transmit.sftp")
	end

    local start_queue = false

    if queue.has_active_queue() == false and type ~= "connect" then
        local connect_processes = sftp.generate_connect_proceses(working_dir)

		for _, process in pairs(connect_processes) do
			table.insert({
				type = "connect",
				working_dir = working_dir,
			}, process)
		end

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
