local M = {}

local async = require "emthree.internal.async"
local utils = require "emthree.internal.utils"

M.REMOVE = hash("emthree_remove")
M.CHANGE = hash("emthree_change")
M.SELECT = hash("emthree_select")
M.RESET = hash("emthree_reset")


M.SLIDE_DOWN = hash("emthree_slide_down")
M.SLIDE_UP = hash("emthree_slide_up")
M.SLIDE_LEFT = hash("emthree_slide_left")
M.SLIDE_RIGHT = hash("emthree_slide_right")

local DIRECTIONS = {
	[M.SLIDE_DOWN] = vmath.vector3(0, -1, 0),
	[M.SLIDE_UP] = vmath.vector3(0, 1, 0),
	[M.SLIDE_LEFT] = vmath.vector3(-1, 0, 0),
	[M.SLIDE_RIGHT] = vmath.vector3(1, 0, 0),
}


local function spawner_filter(board, x, y)
	local block = board.slots[x][y]
	return block and block.spawner
end


local function create_color_filter(color)
	return function(board, x, y)
		local block = board.slots[x][y]
		return (not color and block) or (color and block and block.color == color)
	end
end


local function delay(seconds, fn, a)
	timer.delay(seconds, false, function()
		fn(a)
	end)
end


local function slide_block(board, block, from, to, duration)
	go.set_position(from, block.id)
	go.animate(block.id, "position", go.PLAYBACK_ONCE_FORWARD, to, board.config.slide_easing, duration)
end

--
-- Returns a list of neighbor slots of the same color as
-- the one on x, y. Horizontally.
--
local function horisontal_neighbors(board, x, y)
	assert(board, "You must provide a board")
	local neighbors = {}
	if not board.slots[x][y] or not board.slots[x][y].color then
		return neighbors
	end

	local color = board.slots[x][y].color
	--
	-- Search from slot left to the edge
	--
	for i = x - 1, 0, -1 do
		local block = board.slots[i][y]
		if block and block.color == color then
			table.insert(neighbors, block)
		else
			--
			-- Break the search as soon as we hit something of a different color
			--
			break
		end
	end

	--
	-- Search from slot right to the edge
	--
	for i = x + 1, board.width - 1 do
		local block = board.slots[i][y]
		if block and block.color == color then
			table.insert(neighbors, block)
		else
			--
			-- Break the search as soon as we hit something of a different color
			--
			break
		end
	end
	return neighbors
end

--
-- Returns a list of neighbor slots of the same color as
-- the one on x, y. Vertically.
--
local function vertical_neighbors(board, x, y)
	assert(board, "You must provide a board")
	local neighbors = {}
	if not board.slots[x][y] or not board.slots[x][y].color then
		return neighbors
	end

	local color = board.slots[x][y].color

	--
	-- Search from slot down to the edge
	--
	for i = y - 1, 0, -1 do
		local slot = board.slots[x][i]
		if slot and slot.color == color then
			table.insert(neighbors, slot)
		else
			--
			-- Break the search as soon as we hit something of a different type
			--
			break
		end
	end

	--
	-- Search from slot up to the edge
	--
	for i = y + 1, board.height - 1 do
		local slot = board.slots[x][i]
		if slot and slot.color == color then
			table.insert(neighbors, slot)
		else
			--
			-- Break the search as soon as we hit something of a different color
			--
			break
		end
	end
	return neighbors
end


--
-- Scans the board for any matching neighbors (row or column)
-- and count them.
--
local function find_matching_neighbors(board)
	assert(board, "You must provide a board")
	for block in M.iterate_blocks(board) do
		--
		-- Count the same type line of neighbors horisontally and
		-- vertically. Note that any number of subsequent neighbors
		-- are counted, so if a blue block has 3 blue block immediately
		-- to the right and 3 to the left if has 6 horisontal neighbors.
		--
		local hn = horisontal_neighbors(board, block.x, block.y)
		local vn = vertical_neighbors(board, block.x, block.y)
		block.horisontal_neighbors = hn
		block.vertical_neighbors = vn
	end
end


--
-- Remove blocks that are part of matches, then call callback
--
local function remove_matching_neighbors(board, callback)
	assert(board, "You must provide a board")
	assert(callback, "You must provide a callback")
	local duration = 0.3

	-- handle t, l and cross shaped block formations in a first pass
	for block in M.iterate_blocks(board) do
		if #block.horisontal_neighbors >= 2 and #block.vertical_neighbors >= 2 then
			board.on_match(board, block, block.horisontal_neighbors, block.vertical_neighbors)
		end
	end

	-- handle horisontal and vertical
	for block in M.iterate_blocks(board) do
		if #block.horisontal_neighbors >= 2 or #block.vertical_neighbors >= 2 then
			board.on_match(board, block, block.horisontal_neighbors, block.vertical_neighbors)
		end
	end

	delay(duration, callback)
end


--
-- Apply shift logic to all slots on the board, then
-- call the callback.
--
local function collapse(board, callback)
	assert(board, "You must provide a board")
	assert(callback, "You must provide a callback")
	local duration = board.config.collapse_duration

	local direction = DIRECTIONS[board.config.slide_direction]

	local collapsed = false
	local blocks = board.slots
	local empty_x = nil
	local empty_y = nil
	local block_size = board.block_size

	local function check_collapse(x, y)
		local block = blocks[x][y]
		if block and block.blocker then
			empty_x = nil
			empty_y = nil
		elseif block and block.spawner then
			-- do nothing
		elseif block then
			if empty_x and empty_y then
				--
				-- Move to empty slot
				--
				blocks[empty_x][empty_y] = block
				blocks[x][y] = nil
				block.x = empty_x
				block.y = empty_y

				--
				-- Calc new position and animate
				---
				local to = vmath.vector3((block_size / 2) + (block_size * empty_x), (block_size / 2) + (block_size * empty_y), 0)
				go.animate(block.id, "position", go.PLAYBACK_ONCE_FORWARD, to, board.config.slide_easing, duration)
				collapsed = true
				empty_x = empty_x - direction.x
				empty_y = empty_y - direction.y
			end
		-- first empty slot
		elseif not empty_x then
			empty_x = x
			empty_y = y
		end
	end

	if board.config.slide_direction == M.SLIDE_DOWN then
		for x = 0,board.width - 1 do
			empty_x = nil
			empty_y = nil
			for y = 0,board.height - 1 do
				check_collapse(x, y)
			end
		end
	elseif board.config.slide_direction == M.SLIDE_UP then
		for x = 0,board.width - 1 do
			empty_x = nil
			empty_y = nil
			for y = board.height-1,0,-1 do
				check_collapse(x, y)
			end
		end
	elseif board.config.slide_direction == M.SLIDE_LEFT then
		for y = 0,board.height - 1 do
			empty_x = nil
			empty_y = nil
			for x = 0, board.width-1 do
				check_collapse(x, y)
			end
		end
	elseif board.config.slide_direction == M.SLIDE_RIGHT then
		for y = 0,board.height - 1 do
			empty_x = nil
			empty_y = nil
			for x = board.width-1,0,-1 do
				check_collapse(x, y)
			end
		end
	end
	
	if collapsed then
		delay(duration, callback)
	else
		callback()
	end
end


--
-- Construct a new random board. It's a 2D table with origo in the
-- bottom left corner:
--
--  ...
-- (0,2) (1,2) (2,2)
-- (0,1) (1,1) (2,1)
-- (0,0) (1,0) (2,0) ...
--
-- Each slot stores the id of the game object that sits there, the x and y
-- position and the type, for easy searching. Storing the x and y position is
-- redundant but useful if we use the slots out of context, which we do at times.
-- @param width
-- @param height
-- @param block_size Size of the blocks in pixels
-- @param config Additional (and optional) board configuration values
-- @return The created bord. Pass it when calling the other functions
function M.create_board(width, height, block_size, config)
	assert(width, "You must provide a board width")
	assert(height, "You must provide a board height")
	assert(block_size, "You must provide a block size")
	config = config or {}
	config.collapse_duration = config.collapse_duration or 0.2
	config.slide_direction = config.slide_direction or M.SLIDE_DOWN
	config.slide_easing = config.slide_easing or go.EASING_OUTBOUNCE

	local board = {
		width = width,
		height = height,
		block_size = block_size,
		slots = {},
		config = config,
	}
	for x = 0, width - 1 do
		board.slots[x] = {}
	end

	M.on_match(board, function(board, block, horisontal_neighbors, vertical_neighbors)
		if #horisontal_neighbors >= 2 then
			M.remove_block(board, block)
			M.remove_blocks(board, horisontal_neighbors)
		end
		if #vertical_neighbors >= 2 then
			M.remove_block(board, block)
			M.remove_blocks(board, vertical_neighbors)
		end
	end)

	M.on_block_removed(board, function(board, block)
		-- do nothing
	end)

	M.on_stabilized(board, function(board)
		-- do nothing, board is stable
	end)

	M.on_swap(board, function(board, slot1, slot2)
		return false
	end)

	M.on_create_block(board, function(board, x, y, type, color)
		error("You must call emthree.on_create_block() and provide a function to create blocks on the board")
	end)

	M.on_create_blocker(board, function(board, x, y, type)
		return nil, type
	end)

	M.on_create_spawner(board, function(board, x, y, type)
		return nil, type
	end)
	return board
end


--- Fill the board with blocks
-- @param board The board to fill
function M.fill_board(board)
	for x = 0, board.width - 1 do
		for y = 0, board.height - 1 do
			if not board.slots[x][y] then
				M.create_block(board, x, y)
			end
		end
	end
end


local function swap(board, slot1, slot2, callback)
	local duration = 0.2

	local pos1 = go.get_position(slot1.id)
	local pos2 = go.get_position(slot2.id)
	go.animate(slot1.id, "position", go.PLAYBACK_ONCE_FORWARD, pos2, go.EASING_INOUTSINE, duration)
	go.animate(slot2.id, "position", go.PLAYBACK_ONCE_FORWARD, pos1, go.EASING_INOUTSINE, duration)
	--
	-- Switch the board structure data content of the two slots
	-- In Lua we can write a, b = b, a to swap two values
	--
	local block1 = board.slots[slot1.x][slot1.y]
	local block2 = board.slots[slot2.x][slot2.y]
	board.slots[block1.x][block1.y], board.slots[block2.x][block2.y] = board.slots[block2.x][block2.y], board.slots[block1.x][block1.y]
	block1.x, block2.x = block2.x, block1.x
	block1.y, block2.y = block2.y, block1.y

	delay(duration, callback)
end


---
-- Swap the contents of two board slots
-- @param board
-- @param slot1
-- @param slot2
local function swap_slots(board, slot1, slot2)
	assert(board, "You must provide a board")
	assert(slot1, "You must provide a first slot")
	assert(slot2, "You must provide a second slot")
	assert(coroutine.running())
	async(function(done) swap(board, slot1, slot2, done) end)
	if not board.on_swap(board, slot1, slot2) then
		local hn1 = horisontal_neighbors(board, slot1.x, slot1.y)
		local vn1 = vertical_neighbors(board, slot1.x, slot1.y)
		local hn2 = horisontal_neighbors(board, slot2.x, slot2.y)
		local vn2 = vertical_neighbors(board, slot2.x, slot2.y)
		-- not a valid swap, did not generate a match - swap back again
		if #hn1 < 2 and #hn2 < 2 and #vn1 < 2 and #vn2 < 2 then
			async(function(done) swap(board, slot1, slot2, done) end)
		end
	end
	M.stabilize(board)
end


--
-- Return an iterator function for use in generic for loops
-- to iterate all blocks on the board
-- @param board
-- @param filter_fn Optional filter function (args: board, x, y)
-- @return Function iterator
function M.iterate_blocks(board, filter_fn)
	assert(board, "You must provide a board")
	local x = 0
	local y = -1
	return function()
		repeat
			y = y + 1
			if x == board.width - 1 and y == board.height then
				return nil
			end

			if y == board.height then
				y = 0
				x = x + 1
			end
			local block = board.slots[x][y]
		until (filter_fn and filter_fn(board, x, y) and block) or (not filter_fn and block)
		return board.slots[x][y]
	end
end


--- Check if a slot is empty
-- @param board
-- @param x
-- @param y
-- @return true if the slot is empty
function M.is_empty(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	if M.on_board(board, x, y) then
		return board.slots[x][y] == nil
	end
	return false
end


--- Check if the content of a slot is a block
-- @param board
-- @param x
-- @param y
-- @return true if there is a block in the slot
function M.is_block(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	if M.on_board(board, x, y) then
		return board.slots[x][y] and board.slots[x][y].block
	end
	return false
end


--- Check if the content of a slot is a blocker
-- @param board
-- @param x
-- @param y
-- @return true if there is a blocker in the slot
function M.is_blocker(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	if M.on_board(board, x, y) then
		return board.slots[x][y] and board.slots[x][y].blocker
	end
	return false
end



--- Check if the content of a slot is a spawner
-- @param board
-- @param x
-- @param y
-- @return true if there is a spawner in the slot
function M.is_spawner(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	if M.on_board(board, x, y) then
		return board.slots[x][y] and board.slots[x][y].spawner
	end
	return false
end


--- Get a block on the board
-- @param board
-- @param x
-- @param y
-- @return The block at the given position or nil if out of bounds
function M.get_block(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	if M.on_board(board, x, y) then
		return board.slots[x][y]
	end
	return nil
end


---
-- Get all blocks of a specific color
-- @param board
-- @param color Color to search for or nil to get all blocks
-- @return All blocks of the specified color
function M.get_blocks(board, color)
	assert(board, "You must provide a board")
	local blocks = {}
	for block in M.iterate_blocks(board, create_color_filter(color)) do
		table.insert(blocks, block)
	end
	return blocks
end

--
-- Remove a single block from the board
-- @param board
-- @param block The block to remove
-- @param no_trigger True if the on_block_removed function
-- should NOT be called (defaults to true)
function M.remove_block(board, block, no_trigger)
	assert(board, "You must provide a board")

	if not block then
		return
	end

	if not board.slots[block.x][block.y] then
		-- the block has already been removed
		-- this can happen when we remove a match and a line blast or
		-- other special block effect takes place at the same time
		return
	end

	msg.post(block.id, M.REMOVE)
	--
	-- Empty slots are set to nil so we can find them
	--
	board.slots[block.x][block.y] = nil

	if not no_trigger then
		board.on_block_removed(board, block)
	end
end


--
-- Remove a list of blocks from the board
-- @param board
-- @param blocks
function M.remove_blocks(board, blocks)
	assert(board, "You must provide a board")
	assert(blocks, "You must provide a list of blocks")
	for _,block in pairs(blocks) do
		M.remove_block(board, block)
	end
end


--
-- Change type and color of an existing block
-- Use this when converting blocks into other types due
-- to a match of some kind
-- Will clear list of neighbors
function M.change_block(block, type, color)
	assert(block, "You must provide a block")
	assert(type or color, "You must provide type and/or color")
	block.color = color
	block.type = type
	block.vertical_neighbors = {}
	block.horisontal_neighbors = {}
	msg.post(block.id, M.CHANGE, { color = block.color, type = block.type, position = go.get_position(block.id) })
end


--- Create a new block on the board. This will call the function that was provided
-- by on_create_block()
-- @param board
-- @param x
-- @param y
-- @param type
-- @param color
-- @return The created block
function M.create_block(board, x, y, type, color)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	assert(not board.slots[x][y], "The position is not empty")

	local sx, sy = M.slot_to_screen(board, x, y)
	local id, color, type = board.on_create_block(vmath.vector3(sx, sy, 0), type, color)
	board.slots[x][y] = { id = id, x = x, y = y, color = color, type = type, block = true }
	return board.slots[x][y]
end


--- Create a new blocker on the board. This will call the function that was provided
-- by on_create_blocker()
-- @param board
-- @param x
-- @param y
-- @param type
-- @return The created blocker
function M.create_blocker(board, x, y, type)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	assert(not board.slots[x][y], "The position is not empty")

	local sx, sy = M.slot_to_screen(board, x, y)
	local id, type = board.on_create_blocker(vmath.vector3(sx, sy, 0), type)
	board.slots[x][y] = { id = id, x = x, y = y, type = type, blocker = true }
	return board.slots[x][y]
end


--- Create a new spawner on the board. This will call the function that was provided
-- by on_create_spawner()
-- @param board
-- @param x
-- @param y
-- @param type
-- @return The created spawner
function M.create_spawner(board, x, y, type)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	assert(not board.slots[x][y], "The position is not empty")

	local sx, sy = M.slot_to_screen(board, x, y)
	local id, type = board.on_create_spawner(vmath.vector3(sx, sy, 0), type)
	board.slots[x][y] = { id = id, x = x, y = y, type = type, spawner = true }
	return board.slots[x][y]
end


--
-- Find and return any empty slots.
--
local function find_empty_slots(board)
	assert(board, "You must provide a board")
	local slots = {}	
	for x = 0, board.width - 1 do
		for y = 0, board.height - 1 do
			if not board.slots[x][y] then
				--
				-- The slot is nil/empty so we store this position in the
				-- list of slots that we will return
				--
				table.insert(slots, { x = x, y = y })
			end
		end
	end
	return slots
end



--
-- Find and return any slots containing spawners
--
local function find_spawners(board)
	assert(board, "You must provide a board")
	local spawners = {}
	for block in M.iterate_blocks(board, spawner_filter) do
		table.insert(spawners, { x = block.x, y = block.y })
	end
	return spawners
end



local function trigger_spawners(board, callback)
	assert(board, "You must provide a board")
	local duration = 0.3

	local triggered = false
	for _,spawner in pairs(find_spawners(board)) do
		local direction = DIRECTIONS[board.config.slide_direction]
		local x = spawner.x + direction.x
		local y = spawner.y + direction.y

		local distance = 0
		while M.on_board(board, x, y) and not board.slots[x][y] do
			distance = distance + 1
			x = x + direction.x
			y = y + direction.y
		end

		if distance > 0 then
			triggered = true
			local fromslot_x = spawner.x
			local fromslot_y = spawner.y
			local from_x, from_y = M.slot_to_screen(board, spawner.x, spawner.y)
			local from = vmath.vector3(from_x, from_y, 0)
			
			for i=1,distance do
				local toslot_x = spawner.x + direction.x * i
				local toslot_y = spawner.y + direction.y * i
				local block = M.create_block(board, toslot_x, toslot_y)

				local to_x, to_y = M.slot_to_screen(board, toslot_x, toslot_y)
				local to = vmath.vector3(to_x, to_y, 0)
				slide_block(board, block, from, to, duration)
			end
		end
	end

	if triggered then
		delay(duration, callback, triggered)
	else
		callback(triggered)
	end
end


--- Stabilize the board
-- This will find and remove matching blocks and spawn new blocks in their
-- place. This process will be repeated until the board is filled and no
-- more matches exists. The board is at that point considered stable
-- @param board The board to stabilize
-- @param callback Optional callback to invoke when board is stable
function M.stabilize(board, callback)
	assert(board, "You must provide a board")
	local fn = function()
		while true do
			async(function(done)
				find_matching_neighbors(board)
				remove_matching_neighbors(board, done)
			end)
			async(function(done) collapse(board, done) end)

			local triggered = async(function(done) trigger_spawners(board, done) end)
			if not triggered then
				board.on_stabilized(board)
				if callback then callback() end
				break
			end
		end
	end

	if not coroutine.running() then
		utils.corun(fn)
	else
		fn()
	end
end


--- Check if a position is on the board or not
-- @param board
-- @param x
-- @param y
-- @return true of the position is on the board
function M.on_board(board, x, y)
	return x >= 0 and x < board.width and y >= 0 and y < board.height
end

--- Handle user input
-- @param board The board to apply the input on
-- @param action The user action table (must be a pressed or released action)
-- @return true if the action was handled
function M.on_input(board, action)
	assert(board, "You must provide a board")
	assert(action.pressed or action.released, "You must provide either a pressed or released action")
	local x, y = M.screen_to_slot(board, action.x, action.y)
	local block = M.get_block(board, x, y)

	if action.pressed then
		if not board.mark_1 then
			board.mark_1 = block
		else
			board.mark_2 = block
		end
		return block ~= nil
	else

		if board.mark_1 and board.mark_1 == board.mark_2 then
			-- second click, released on the first block again -> deselect it
			msg.post(board.mark_1.id, M.RESET)
			board.mark_1 = nil
			board.mark_2 = nil
			return true

		elseif board.mark_1 and board.mark_1 == block then
			-- first click, released on the first block -> select it
			msg.post(board.mark_1.id, M.SELECT)
			return true

		elseif board.mark_2 and board.mark_2 == block then
			-- second click, released on the second block -> swap them
			utils.corun(function()
				msg.post(".", "release_input_focus")
				local dx = math.abs(board.mark_1.x - board.mark_2.x)
				local dy = math.abs(board.mark_1.y - board.mark_2.y)
				if (dx == 1 and dy == 0) or (dy == 1 and dx == 0) then
					swap_slots(board, board.mark_1, board.mark_2)
				end
				msg.post(board.mark_1.id, M.RESET)
				board.mark_1 = nil
				board.mark_2 = nil
				msg.post(".", "acquire_input_focus")
			end)
			return true

		elseif board.mark_1 and not board.mark_2 then
			-- one block selected, released on some other block -> swipe and swap
			utils.corun(function()
				msg.post(".", "release_input_focus")
				local dx = utils.clamp(board.mark_1.x - x, -1, 1)
				local dy = utils.clamp(board.mark_1.y - y, -1, 1)
				block = M.get_block(board, board.mark_1.x - dx, board.mark_1.y - dy)
				if dx == 0 or dy == 0 and block then
					swap_slots(board, board.mark_1, block)
				end
				msg.post(board.mark_1.id, M.RESET)
				board.mark_1 = nil
				msg.post(".", "acquire_input_focus")
			end)
			return true

		else
			if board.mark_1 then
				msg.post(board.mark_1.id, M.RESET)
				board.mark_1 = nil
			end
			if board.mark_2 then
				msg.post(board.mark_2.id, M.RESET)
				board.mark_2 = nil
			end
		end
	end
end

-- Convert a screen position to slot on the board
-- @param board
-- @param x
-- @param y
-- @return slot_x
-- @return slot_y
function M.screen_to_slot(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	local pos = go.get_world_position()
	local scale = go.get_world_scale()
	local x = math.floor((x - pos.x) / (board.block_size * scale.x))
	local y = math.floor((y - pos.y) / (board.block_size * scale.y))
	return x, y
end


-- Convert a board position to a screen position
-- @param board
-- @param x
-- @param y
-- @return screen_x
-- @return screen_y
function M.slot_to_screen(board, x, y)
	assert(board, "You must provide a board")
	assert(x and y, "You must provide a position")
	local x = (board.block_size / 2) + (board.block_size * x)
	local y = (board.block_size / 2) + (board.block_size * y)
	return x, y
end


function M.color_frequency(board)
	local f = {}
	for block in M.iterate_blocks(board) do
		if block.color then
			f[block.color] = f[block.color] or 0
			f[block.color] = f[block.color] + 1
		end
	end
	local l = {}
	for color,count in pairs(f) do
		table.insert(l, { color = color, count = count })
	end
	table.sort(l, function(a, b)
		return a.count > b.count
	end)
	return l
end


function M.dump(board)
	local s = "\n"
	for y = board.height - 1,0,-1  do
		s = s .. y .. ":"
		for x = 0, board.width - 1 do
			local block = board.slots[x][y]
			if block then
				if block.spawner then
					s = s ..  "U"
				elseif block.blocker then
					s = s ..  "X"
				else
					s = s ..  hash_to_hex(block.color):sub(1,1)
				end
			else
				s = s ..  " "
			end
		end
		s = s .. "\n"
	end
	return s
end


--- Set a function to be called when a match is detected on the board
function M.on_match(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_match = fn
end


--- Set a function to be called when a block is removed
function M.on_block_removed(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_block_removed = fn
end


--- Set a function to be called when a board is stabilized
function M.on_stabilized(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_stabilized = fn
end


--- Set a function to be called when two blocks have been swapped by the user
function M.on_swap(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_swap = fn
end


-- The function to call when a block should be created
function M.on_create_block(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_create_block = fn
end


-- The function to call when a blocker should be created
function M.on_create_blocker(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_create_blocker = fn
end


-- The function to call when a spawner should be created
function M.on_create_spawner(board, fn)
	assert(board, "You must provide a board")
	assert(fn, "You must provide a function")
	board.on_create_spawner = fn
end


return M
