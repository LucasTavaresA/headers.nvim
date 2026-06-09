local M = {}
M.default_config = {
	code_paths = {},
	paths_file = vim.fn.stdpath("data") .. "/headers.nvim/paths.lua",
	non_code = {
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
	},
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
local header = ""
local footer = ""

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
	vim.fn.mkdir(vim.fs.dirname(M.config.paths_file), "p")
	local file, err = io.open(M.config.paths_file, "w")
	local headers = [[require("headers")]]

	if file then
		file:write(
			headers
				.. ".files = "
				.. vim.inspect(M.files)
				.. "\n"
				.. headers
				.. ".folders = "
				.. vim.inspect(M.folders)
				.. "\n"
				.. headers
				.. ".roots = "
				.. vim.inspect(M.roots)
				.. "\n"
				.. config_file_footer
		)
		file:close()
	else
		error("Error opening file: " .. err)
	end
end

--- Executes a command and returns the output, nil if non-zero exit code
---@param cmd string[]
---@return string? out
local function shell_out(cmd)
	local out = vim.fn.system(cmd)

	if vim.v.shell_error == 0 then
		return out
	end

	return nil
end

--- Returns the most specific LSP root attached to the buffer that contains the file, nil if there's none.
---@param buf integer
---@param file string
---@return string? root
local function try_get_lsp_root(buf, file)
	if file == "" then
		return nil
	end

	local normalized_file = vim.fs.normalize(file):gsub("/+$", "")
	local roots = {}

	local function add_root(root)
		if root == nil or root == "" then
			return
		end

		root = vim.fs.normalize(root):gsub("/+$", "")

		if root == "" then
			root = "/"
		end

		if root == "/" or normalized_file == root or normalized_file:sub(1, #root + 1) == root .. "/" then
			table.insert(roots, root)
		end
	end

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
		local config = client.config or {}

		for _, workspace in ipairs(client.workspace_folders or {}) do
			if workspace.uri ~= nil then
				add_root(vim.uri_to_fname(workspace.uri))
			else
				add_root(workspace.name)
			end
		end

		for _, workspace in ipairs(config.workspace_folders or {}) do
			if workspace.uri ~= nil then
				add_root(vim.uri_to_fname(workspace.uri))
			else
				add_root(workspace.name)
			end
		end

		add_root(client.root_dir or config.root_dir)
	end

	table.sort(roots, function(a, b)
		return #a > #b
	end)

	return roots[1]
end

--- Get the root of the current buffer, nil if warnings are ignored
---@return string? root
local function get_root()
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	local folder = vim.fs.dirname(file)

	pcall(dofile, M.config.paths_file)

	local root = try_get_lsp_root(buf, file)

	if root == nil and folder ~= nil and folder ~= "" then
		root = shell_out({ "git", "-C", folder, "rev-parse", "--show-toplevel" })
	end

	iterate_folders(folder, function(p)
		p = p:gsub("/+$", "") .. "/"

		if M.folders[p] ~= nil then
			root = p
		end
	end)

	if root ~= nil then
		root = vim.trim(root)
	end

	return root
end

local function warn()
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	local folder = vim.fs.dirname(file)
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })

	if
		not vim.tbl_isempty(M.config.code_paths)
		and not vim.tbl_contains(M.config.code_paths, function(p)
			p = p:gsub("/+$", "") .. "/"
			return folder:sub(1, #p) == p
		end, { predicate = true })
	then
		return
	end

	if
		not (vim.bo.modifiable and vim.bo.modified)
		or file == M.config.paths_file
		or (folder ~= nil and folder ~= "" and shell_out({ "git", "-C", folder, "check-ignore", "-q", "--", file }) ~= nil)
		or M.config.non_code[filetype] == true
	then
		return
	end

	local root = get_root()

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

		local entry

		if M.files[file] ~= nil then
			entry = M.files[file]
		elseif M.folders[root] ~= nil then
			entry = M.folders[root]
		else
			entry = M.roots[root]
		end

		if entry.header == nil and entry.footer == nil then
			header = ""
			footer = ""
			vim.diagnostic.reset(namespace, buf)
			return
		end

		header = entry.header or ""
		footer = entry.footer or ""

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
				},
			})
			return
		end

		local diagnostics = {}

		if
			header ~= ""
			and header
				~= table.concat(vim.api.nvim_buf_get_lines(buf, 0, (1 + select(2, header:gsub("\n", "\n"))), false), "\n")
		then
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

		if
			footer ~= ""
			and footer
				~= table.concat(
					vim.api.nvim_buf_get_lines(buf, line_count - (1 + select(2, footer:gsub("\n", "\n"))), line_count, false),
					"\n"
				)
		then
			table.insert(diagnostics, {
				namespace = namespace,
				bufnr = buf,
				lnum = line_count - (1 - select(2, footer:gsub("\n", "\n"))),
				col = 0,
				end_col = 999,
				severity = vim.diagnostic.severity.WARN,
				message = "File is lacking a footer! \n'" .. footer .. "'",
			})
		end

		vim.diagnostic.set(namespace, buf, diagnostics)
	end

	save()
end

--- Fixes hovered header/footer
function M.fix_hovered()
	local buf = vim.api.nvim_get_current_buf()
	local namespace = vim.api.nvim_create_namespace("headers.nvim")
	local warning_level = vim.diagnostic.severity.WARN
	local diagnostic_count = vim.diagnostic.count(buf, { namespace = namespace })[warning_level]

	if diagnostic_count and diagnostic_count > 0 then
		local hovering = vim.fn.line(".")
		local last = vim.fn.line("$")

		if hovering == 1 then
			if header ~= "" then
				vim.api.nvim_buf_set_lines(buf, 0, 0, false, vim.split(header, "\n"))
			end
		end

		if hovering == last then
			if footer ~= "" then
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, vim.split(footer, "\n"))
			end
		end
	end
end

--- Set the current buffer root to ignore warnings
function M.ignore()
	local root = get_root()

	if root == nil then
		return
	end

	M.roots[root] = {}
	save()
end

---@class HeadersConfig?
---@field code_paths string[]
---@field paths_file string
---@param opts HeadersConfig?
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})
	require("headers.table").set_all(M.config.non_code, true)

	local group = vim.api.nvim_create_augroup("headers.nvim", {})

	vim.api.nvim_create_autocmd("InsertEnter", { group = group, callback = warn })
	vim.api.nvim_create_autocmd("InsertLeave", { group = group, callback = warn })
	vim.api.nvim_create_autocmd("TextChangedI", { group = group, callback = warn })
	vim.api.nvim_create_autocmd("TextChanged", { group = group, callback = warn })

	-- In case you move between buffers in insert mode
	vim.api.nvim_create_autocmd("BufEnter", { group = group, callback = warn })
	vim.api.nvim_create_autocmd("BufLeave", { group = group, callback = warn })

	vim.api.nvim_create_user_command("HeadersConfig", function()
		vim.cmd.e(M.config.paths_file)
	end, { desc = "Open paths file" })
end

return M
-- Licensed under the GPL3 or later versions of the GPL license.
-- See the LICENSE file in the project root for more information.
