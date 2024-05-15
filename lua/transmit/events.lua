local util = require('transmit.util')

local events = {}

events.watching = {}

local function on_change(path, directory, remove_watch, handle_event)
    local f = io.open(path, "r")
    local file_exists = false
    if f ~= nil then
        file_exists = true
        io.close(f)
    end

    if file_exists == false then
        vim.schedule(function()
            util.remove_path(path, directory)
        end)
        -- vim.schedule(function()
        --     remove_watch(directory, handle_event)
        -- end)
        -- vim.schedule(function()
        --     events.watch_directory_for_changes(directory)
        -- end)
    else
        vim.schedule(function()
            util.upload_file(path, directory)
        end)
        -- vim.schedule(function()
        --     remove_watch(directory, handle_event)
        -- end)
        -- vim.schedule(function()
        --     events.watch_directory_for_changes(directory)
        -- end)
    end
end

function events.watch_directory_for_changes(directory)
    if events.watching[directory] ~= nil then
        return false
    end

    local handle_event = vim.loop.new_fs_event()

    -- these are just the default values
    local flags = {
        watch_entry = false, -- true = when dir, watch dir inode, not dir content
        stat = false, -- true = don't use inotify/kqueue but periodic check, not implemented
        recursive = true -- true = watch dirs inside dirs
    }

    local remove_watch = function(directory, handle_event)
        events.watching[directory] = nil
        vim.loop.fs_event_stop(handle_event, handle_event)
    end

    local callback = function(err, filename, events)
        if err then
            remove_watch(directory, handle_event)
        else
            on_change(directory .. "/" .. filename, directory, remove_watch, handle_event)
        end
    end

    vim.loop.fs_event_start(handle_event, directory, flags, callback)
    events.watching[directory] = true
end

return events
