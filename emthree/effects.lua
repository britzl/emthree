local emthree = require "emthree.emthree"

local M = {}



function M.horisontal_lineblast(board, block, width)
	assert(board, "You must provide a board")
	assert(block, "You must provide a block")
	width = width or 1
	for w=0,width-1 do
		local y = block.y - math.floor(width / 2) + w
		if emthree.on_board(board, block.x, y) then
			emthree.remove_block(board, board.slots[block.x][y])
			for x=block.x, 0, -1 do
				if emthree.is_block(board, x, y) then emthree.remove_block(board, board.slots[x][y]) end
			end
			for x=block.x, board.width -1 do
				if emthree.is_block(board, x, y) then emthree.remove_block(board, board.slots[x][y]) end
			end
		end
	end
end


function M.vertical_lineblast(board, block, width)
	assert(board, "You must provide a board")
	assert(block, "You must provide a block")
	width = width or 1
	for w=0,width-1 do
		local x = block.x - math.floor(width / 2) + w
		if emthree.on_board(board, x, block.y) then
			emthree.remove_block(board, board.slots[x][block.y])
			for y=block.y, 0, -1 do
				if emthree.is_block(board, x, y) then emthree.remove_block(board, board.slots[x][y]) end
			end
			for y=block.y, board.height -1 do
				if emthree.is_block(board, x, y) then emthree.remove_block(board, board.slots[x][y]) end
			end
		end
	end
end


function M.bomb(board, block, radius)
	assert(board, "You must provide a board")
	assert(block, "You must provide a block")
	assert(radius, "You must provide a radius")
	for r=1,radius do
		for x=block.x-r,block.x+r do
			for y=block.y-r,block.y+r do
				if emthree.is_block(board, x, y) then
					emthree.remove_block(board, board.slots[x][y])
				end
			end
		end
	end
end


function M.remove_color(board, color)
	assert(board, "You must provide a board")
	assert(color, "You must provide a color")
	local blocks = emthree.get_blocks(board, color)
	while #blocks > 0 do
		local b = table.remove(blocks, math.random(1, #blocks))
		emthree.remove_block(board, b)
	end
end


function M.remove_all(board)
	assert(board, "You must provide a board")
	local blocks = emthree.get_blocks(board)
	while #blocks > 0 do
		local b = table.remove(blocks, math.random(1, #blocks))
		if emthree.is_block(board, b.x, b.y) then 
			emthree.remove_block(board, b)
		end
	end
end

return M