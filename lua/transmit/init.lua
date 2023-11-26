local M = {}

M.send_file = function ()
    vim.fn.jobstart({ "sftp", '/', '/' })
end

return M;
