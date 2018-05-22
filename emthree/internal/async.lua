local M = {}

local unpack = _G.unpack or table.unpack


function M.async(fn, ...)
	assert(fn)
	local co = coroutine.running()
	assert(co)
	local results = nil
	local state = "RUNNING"
	fn(function(...)
		results = { ... }
		if state == "YIELDED" then
			local ok, err = coroutine.resume(co)
			if not ok then print(err) end
		else
			state = "DONE"
		end
	end, ...)
	if state == "RUNNING" then
		state = "YIELDED"
		coroutine.yield()
		state = "DONE"		-- not really needed
	end
	return unpack(results)
end


function M.http_request(url, method, headers, post_data, options)
	return M.async(function(done)
		http.request(url, method, function(self, id, response)
			done(response)
		end, headers, post_data, options)
	end)
end


setmetatable(M, {
	__call = function(t, ...)
		return M.async(...)
	end
})

return M
