local M = {}

function M.set_all(t, v)
	for _, val in ipairs(t) do
		t[val] = v
	end
end

return M
-- Licensed under the GPL3 or later versions of the GPL license.
-- See the LICENSE file in the project root for more information.
