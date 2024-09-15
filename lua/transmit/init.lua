local sftp = require("transmit.sftp")
local watcher = require("transmit.watcher")

local transmit = {}

function transmit.setup(config)
	if not config then return false end

	vim.cmd('command TransmitOpenSelectWindow lua require("transmit.ui").open_select_windw()')
	vim.cmd('command TransmitUpload lua require("transmit.util").upload_file()')
	vim.cmd('command TransmitRemove lua require("transmit.util").remove_path()')

	local server_config = sftp.parse_sftp_config(config.config_location)

	if not server_config then return false end

    if server_config.watch_for_changes ~= nil and server_config.watch_for_changes == true then
		watcher.watch_directory(vim.loop.cwd())
    elseif server_config.upload_on_bufwrite ~= nil then
        vim.cmd([[
            augroup TransmitAutoCommands
            autocmd!
            autocmd BufWritePost * lua require("transmit.util").upload_file()
            augroup END
        ]])
    end
end

return transmit;
