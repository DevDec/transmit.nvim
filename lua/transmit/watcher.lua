local util = require('transmit.util')
local sftp = require('transmit.sftp')

local watcher = {
	watching = {}
}

local function isExcludedDirectory(directory, excluded_directories)
	for _, excluded in ipairs(excluded_directories) do
		if string.find(directory, excluded) then
			return true
		end
	end

    return false
end

local function on_change(path, directory, excluded_directories)
    local f = io.open(path, "r")
    local file_exists = false
	local isDirectory = false

    if f ~= nil then
        file_exists = true
		local stat = vim.loop.fs_stat(path)

		if stat and stat.type == "directory" then
			isDirectory = true
		end

        io.close(f)
    end

	if (path == directory or isExcludedDirectory(path, excluded_directories)) then
		return
	end


	-- if file_exists and isDirectory then
		-- util.create_directory(path, directory)

		-- watcher.watch_directory_for_changes(path, excluded_directories)
	-- end

	-- TODO: Check if file is a directory, if it is then check if its being watched, if not then watch it
	-- If it is a directory then util.create_directory or util.remove_directory instead

    if file_exists == false then
        vim.schedule(function()
            util.remove_path(path, directory)
        end)
    else
        vim.schedule(function()
            util.upload_file(path, directory)
        end)
	end
end
--
local function isWindows()
	return package.config:sub(1, 1) == '\\'
end

local remove_watch = function(dir, handle_event)
	local uv = vim.uv;
	uv.fs_event_stop(handle_event, handle_event)
	watcher.watching[dir] = nil
end

function watcher.remove_all_watchers()
	local uv = vim.uv;
	for rootDirectory, _ in pairs(watcher.watching) do
		for dir, handle_event in pairs(watcher.watching[rootDirectory]) do
			uv.fs_event_stop(handle_event, handle_event)
			watcher.watching[rootDirectory][dir] = nil
		end
	end
end

function watcher.remove_all_watchers_for_directory(rootDirectory)
	local uv = vim.uv;
	if watcher.watching[rootDirectory] == nil then
		return
	end

	for dir, handle_event in pairs(watcher.watching[rootDirectory]) do
		uv.fs_event_stop(handle_event, handle_event)
		watcher.watching[rootDirectory][dir] = nil
	end
end

function watcher.watch_directory(directory)
	if
		watcher.watching[directory] ~= nil
		or (not sftp.server_config[sftp.get_current_server(directory)] or sftp.server_config[sftp.get_current_server(directory)] == 'none')
		or (not sftp.server_config[sftp.get_current_server(directory)]['watch_for_changes'])
	then
		return false
	end

	local excluded = sftp.server_config[sftp.get_current_server(directory)]['exclude_watch_directories'] or {}

	local command
	if isWindows() then
		command = 'dir "' .. directory .. '" /ad /b /s'
	else
		command = 'find "' .. directory .. '" -type d'
	end

	local flags = {
		watch_entry = false, -- true = when dir, watch dir inode, not dir content
		stat = false, -- true = don't use inotify/kqueue but periodic check, not implemented
		recursive = true -- true = watch dirs inside dirs
	}

	local uv, p = vim.uv, io.popen(command)

	if not p then return false end

	for dir in p:lines() do
		-- Skip excluded directories
		if isExcludedDirectory(dir, excluded) then
			goto continue
		end

		local handle_event = uv.new_fs_event()
		if watcher.watching[dir] ~= nil then
			uv.fs_event_stop(handle_event, handle_event)
		end

		local callback = function(err, filename)
			if err then
				remove_watch(dir, handle_event)
			else
				on_change(dir .. "/" .. filename, directory, excluded)
			end
		end

		uv.fs_event_start(handle_event, dir, flags, callback)

		watcher.watching[directory] = watcher.watching[directory] or {}

		watcher.watching[directory][dir] = handle_event

		::continue::
	end

	p:close()
end

return watcher
