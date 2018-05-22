local M = {}

function M.clamp(value, min, max)
	if value > max then return max end
	if value < min then return min end
	return value
end


function M.corun(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print(err)
	end
end


return M