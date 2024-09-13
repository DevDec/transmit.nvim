local sftp = require('transmit.sftp')
local util = {}

-- function util.create_directory(path, working_dir)
-- 	if working_dir == nil then
-- 		working_dir = vim.loop.cwd()
-- 	end
--
-- 	if sftp.working_dir_has_active_sftp_selection(working_dir) == false then
-- 		return false
-- 	end
--
-- 	local create_processes = sftp.generate_create_dir(path, working_dir)
-- 	sftp.add_to_queue("create_dir", path, working_dir, create_processes)
-- end

function util.remove_path(path, working_dir)
    if path == nil then
        path = vim.api.nvim_buf_get_name(0)
    end

    if working_dir == nil then
        working_dir = vim.loop.cwd()
    end

    if sftp.working_dir_has_active_sftp_selection(working_dir) == false then
        return false
    end

    local remove_processes = sftp.generate_remove_proceses(path, working_dir)

    sftp.add_to_queue("remove", path, working_dir, remove_processes)
end

function util.upload_file(file, working_dir)
    if file == nil then
        file = vim.api.nvim_buf_get_name(0)
    end

    if working_dir == nil then
        working_dir = vim.loop.cwd()
    end

    if sftp.working_dir_has_active_sftp_selection(working_dir) == false then
        return false
    end

    local upload_processes = sftp.generate_upload_proceses(file, working_dir)
    sftp.add_to_queue("upload", file, working_dir, upload_processes)
end

return util
