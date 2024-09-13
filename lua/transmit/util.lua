---@class Util
---@field sftp TransmitSftp
local Util = {}

Util.__index = Util

function Util:new(sftp)
	local util = setmetatable({
		sftp = sftp
	}, Util)
	return util
end

function Util:remove_path(path, working_dir)
    if path == nil then
        path = vim.api.nvim_buf_get_name(0)
    end

    if working_dir == nil then
        working_dir = vim.loop.cwd()
    end

    if self.sftp:working_dir_has_active_sftp_selection(working_dir) == false then
        return false
    end

    local remove_processes = self.sftp:generate_remove_proceses(path, working_dir)

    self.sftp:add_to_queue("remove", path, working_dir, remove_processes)
end

function Util:upload_file(file, working_dir)
    if file == nil then
        file = vim.api.nvim_buf_get_name(0)
    end

    if working_dir == nil then
        working_dir = vim.loop.cwd()
    end

    if self.sftp:working_dir_has_active_sftp_selection(working_dir) == false then
        return false
    end

    local upload_processes = self.sftp:generate_upload_proceses(file, working_dir)
    self.sftp:add_to_queue("upload", file, working_dir, upload_processes)
end

return Util
