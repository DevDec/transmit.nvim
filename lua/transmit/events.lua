local Util = require('transmit.util')

---@class Events
---@field watching table
---@field sftp TransmitSftp
local Events = {}

Events.__index = Events

function Events:new(sftp)
	local events = setmetatable({
		watching = {},
		sftp = sftp,
	}, Events)

	Util:new(sftp)

	return events
end

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
		-- Util.create_directory(path, directory)

		-- Events:watch_directory_for_changes(path, excluded_directories)
	-- end

	-- TODO: Check if file is a directory, if it is then check if its being watched, if not then watch it
	-- If it is a directory then Util.create_directory or util.remove_directory instead

    if file_exists == false then
        vim.schedule(function()
            Util.remove_path(path, directory)
        end)
    else
        vim.schedule(function()
            Util.upload_file(path, directory)
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
	Events.watching[dir] = nil
end

function Events:remove_all_watchers()
	local uv = vim.uv;
	for rootDirectory, _ in pairs(self.watching) do
		for dir, handle_event in pairs(self.watching[rootDirectory]) do
			uv.fs_event_stop(handle_event, handle_event)
			self.watching[rootDirectory][dir] = nil
		end
	end
end

function Events:remove_all_watchers_for_root(rootDirectory)
	local uv = vim.uv;
	if self.watching[rootDirectory] == nil then
		return
	end

	for dir, handle_event in pairs(self.watching[rootDirectory]) do
		uv.fs_event_stop(handle_event, handle_event)
		self.watching[rootDirectory][dir] = nil
	end
end

function Events:watch_directory_for_changes(directory, excluded_directories)
	if self.watching[directory] ~= nil then
		return
	end

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

	local uv = vim.uv;
	local p = io.popen(command)

	if p == nil then
		return
	end

	for dir in p:lines() do
		-- Skip excluded directories
		if isExcludedDirectory(dir, excluded_directories) then
			goto continue
		end

		local handle_event = uv.new_fs_event()
		if self.watching[dir] ~= nil then
			uv.fs_event_stop(handle_event, handle_event)
		end

		local callback = function(err, filename, events)
			if err then
				remove_watch(dir, handle_event)
			else
				on_change(dir .. "/" .. filename, directory, excluded_directories)
			end
		end

		uv.fs_event_start(handle_event, dir, flags, callback)

		self.watching[directory] = self.watching[directory] or {}

		self.watching[directory][dir] = handle_event

		::continue::
	end

	p:close()
end

return Events
