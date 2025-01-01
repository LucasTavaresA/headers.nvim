-- TODO(LucasTA): code action to write the header and footer
-- TODO(LucasTA): code action to ignore header and footer
local M = {}
M.default_config = {
	paths_file = vim.fn.stdpath("data") .. "/headers.nvim/paths.lua",
}
local config_file_footer = [[

-- This footer gets readded when headers.nvim saves this file!
-- There is no need to reopen neovim after saving this file!
--
-- Only one will be shown, the priority is: 1.file 2.folder 3.root
--
-- to ignore warning set to {} like this:
-- require("headers").roots = {
--   ["/example/project/"] = {
--   }
-- }
--
-- usage example:
-- require("headers").example = {
--   ["/example/project/"] = {
--     header = "",
--     footer = "// Licensed under the GPL3 or later versions of the GPL license.\n// See the LICENSE file in the project root for more information.\n",
--   }
-- }
]]
M.roots = {}
M.files = {}
M.folders = {}
local non_code = {
	"sh",
	"zsh",
	"bash",
	"fish",
	"vim",
	"markdown",
	"txt",
	"json",
	"yaml",
	"toml",
	"ini",
	"html",
	"css",
	"sql",
	"xml",
	"cmake",
	"make",
	"diff",
	"patch",
	"git",
	"gitcommit",
	"gitconfig",
	"gitignore",
	"gitattributes",
}

require("headers.table").set_all(non_code, true)

--- Traverses folders from the shallowest to the deepest, executing the callback for each folder
---@param folder string
---@param callback fun(folder: string)
local function iterate_folders(folder, callback)
	if folder == nil then
		callback("/")
		return
	end

	callback(folder)
	local parent = folder:match("(.+)/")
	iterate_folders(parent, callback)
end

local function save()
	os.execute("mkdir -p " .. vim.fs.dirname(M.config.paths_file))
	local file, err = io.open(M.config.paths_file, "w")
	local headers = [[require("headers")]]

	if file then
		file:write(
			headers .. ".files = " .. vim.inspect(M.files)
			.. '\n'
			.. headers .. ".folders = " .. vim.inspect(M.folders)
			.. '\n'
			.. headers .. ".roots = " .. vim.inspect(M.roots)
			.. '\n'
			.. config_file_footer
		)
		file:close()
	else
		error("Error opening file: " .. err)
	end
end

--- Executes a shell command and returns the output, nil if non-zero exit code
---@param cmd string
---@return string? out
local function shell_out(cmd)
	local out = vim.fn.system(cmd)

	if vim.v.shell_error == 0 then
		return out
	end

	return nil
end

local function warn()
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	local folder = vim.fs.dirname(file)
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })

	if
			not (vim.bo.modifiable and vim.bo.modified) or
			file == M.config.paths_file or
			shell_out("git check-ignore -q " .. file) ~= nil or
			non_code[filetype] == true
	then
		return
	end

	pcall(dofile, M.config.paths_file)

	local root = vim.lsp.buf.list_workspace_folders()[1]

	if root == nil then
		root = shell_out("git rev-parse --show-toplevel")
	end

	iterate_folders(folder, function(p)
		p = p:gsub("/+$", "") .. "/"

		if M.folders[p] ~= nil then
			root = p
		end
	end)

	if root == nil then
		return
	end

	if M.roots[root] == nil then
		M.roots[root] = { header = "", footer = "" }
		save()
		return
	end

	do
		local namespace = vim.api.nvim_create_namespace("headers.nvim")
		local header
		local footer

		if M.files[file] ~= nil then
			header = M.files[file].header
			footer = M.files[file].footer
		elseif M.folders[root] ~= nil then
			header = M.folders[root].header
			footer = M.folders[root].footer
		else
			header = M.roots[root].header
			footer = M.roots[root].footer
		end

		if header == "" and footer == "" then
			vim.diagnostic.set(namespace, buf, {
				{
					namespace = namespace,
					bufnr = buf,
					lnum = 0,
					col = 0,
					end_col = 999,
					severity = vim.diagnostic.severity.WARN,
					message = "No header or footer set for this project at " .. root .. " Set it with :HeadersConfig",
				}
			})
			return
		elseif header == nil and footer == nil then
			vim.diagnostic.reset(namespace, buf)
			return
		end

		local diagnostics = {}

		if header ~= "" and header ~= table.concat(vim.api.nvim_buf_get_lines(buf, 0, (1 + select(2, header:gsub('\n', '\n'))), false), '\n') then
			table.insert(diagnostics, {
				namespace = namespace,
				bufnr = buf,
				lnum = 0,
				col = 0,
				end_col = 999,
				severity = vim.diagnostic.severity.WARN,
				message = "File is lacking a header! \n'" .. header .. "'",
			})
		end

		local line_count = vim.api.nvim_buf_line_count(buf)

		if footer ~= "" and footer ~= table.concat(vim.api.nvim_buf_get_lines(buf, line_count - (1 + select(2, footer:gsub('\n', '\n'))), line_count, false), '\n') then
			table.insert(diagnostics, {
				namespace = namespace,
				bufnr = buf,
				lnum = line_count - (1 - select(2, footer:gsub('\n', '\n'))),
				col = 0,
				end_col = 999,
				severity = vim.diagnostic.severity.WARN,
				message = "File is lacking a footer! \n'" .. footer .. "'",
			})
		end

		vim.diagnostic.set(namespace, buf, diagnostics)
	end
end

---@class HeadersConfig?
---@field paths_file string
---@param opts HeadersConfig?
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})

	local group = vim.api.nvim_create_augroup("headers.nvim", {})

	vim.api.nvim_create_autocmd('InsertEnter', { group = group, callback = warn })
	vim.api.nvim_create_autocmd('InsertLeave', { group = group, callback = warn })
	vim.api.nvim_create_autocmd('TextChangedI', { group = group, callback = warn })
	vim.api.nvim_create_autocmd('TextChanged', { group = group, callback = warn })

	-- In case you move between buffers in insert mode
	vim.api.nvim_create_autocmd('BufEnter', { group = group, callback = warn })
	vim.api.nvim_create_autocmd('BufLeave', { group = group, callback = warn })

	vim.api.nvim_create_user_command("HeadersConfig", function()
		vim.cmd.e(M.config.paths_file)
	end, { desc = 'Open paths file' })
end

return M
-- Licensed under the GPL3 or later versions of the GPL license.
-- See the LICENSE file in the project root for more information.
