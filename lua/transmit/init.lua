local M = {}

M.send_file = function ()
    vim.fn.jobstart({ "sftp", '/', '/' }, {
            on_stderr = function(_, data, _)
                vim.print('error')
                -- vim.list_extend(stderr, data)
            end,
            on_exit = function(_, code, _)
                vim.print('failed')
            end
    })
end

return M;
