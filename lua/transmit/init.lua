local M = {}

M.send_file = function ()
    fn.jobstart({ "sftp", '/', '/' })
end

return M;
