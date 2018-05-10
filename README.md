# Emthree
Emthree is a match 3 engine for Defold.


# Setup
## Add project dependencies
You can use Emthree in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

https://github.com/britzl/emthree/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/emthree/releases).


# Usage

## Terminology
This documentation uses a number of different concepts to describe the functionality of Emthree. Please refer to the list below to better understand how Emthree works.

### Board
A grid of slots where the game is played.

### Slot
A position on the board. A slot can hold a block.

### Block
A block represents an element in a slot on the board. It could be fish, candy, cakes or something else, fitting the theme of the game. Blocks have a color and an optional type.

### Match
Three or more blocks of the same color is considered a match.

### Stable Board
A board is considered stable when the board doesn't contain any matches and all slots are filled with blocks.


## EmthreeAPI

### emthree.create(width, height, block_size, block_create_fn)
Create an Emthree board of the specified dimensions, filled with blocks

**PARAMETERS**
* ```width``` (number) - Board width in blocks
* ```height``` (number) - Board height in blocks
* ```block_size``` (number) - Size of a block
* ```block_create_fn``` (function) - Function to call when a new block needs to be created.

**RETURN**
* ```board``` (table) - A representation of the board, complete with a 2D array of blocks


### emthreee.iterate_slots(board)
Return an iterator function that can be used to iterate all slots on the board

**PARAMETERS**
* ```board``` (table) - The board to iterate

**RETURN**
* ```fn``` (function) - The iterator function


### emthree.get_blocks(board, color)
Get all blocks of a certain color

**PARAMETERS**
* ```board``` (table) - The board to get blocks from
* ```color``` (any) - The color to search for

**RETURN**
* ```blocks``` (table) - A list of all blocks matching the specified color


### emthree.remove_block(board, block)
Remove a block from the board. This will invoke the function specified by `emthree.on_block_removed()`. This will also post an `emthree.REMOVE` message to the game object representing the block.

**PARAMETERS**
* ```board``` (table) - The board to remove block from
* ```block``` (table) - The block to remove


### emthree.remove_blocks(board, blocks)
Remove a list of blocks. Will repeatedly call `emthree.remove_block()`.

**PARAMETERS**
* ```board``` (table) - The board to remove blocks from
* ```block``` (table) - The blocks to remove


### emthree.change_block(block, type, color)
Change a block on the board from one type and color to another. This will post an `emthree.RESPAWN` message to the game object representing the block.

**PARAMETERS**
* ```block``` (table) - The block to change
* ```type``` (any) - The type to change to
* ```color``` (any) - The color to change to


### emthree.stabilize(board)
Stabilize the board. This will search through the board for any matches, remove these and the spawn new blocks. This process will be repeated until there are no matches to remove or new blocks to spawn. When the board is stable it will invoke the function specified by `emthree.on_stabilized`.

**PARAMETERS**
* ```board``` (table) - The board to stabilize


### emthree.on_input(board, action)
Pass user input to the board to detect interaction with the blocks. Only touch/click events with a state of `pressed` or `released` must be sent. When a block is selected through a click Emthree will send an `emthree.SELECT` message to the game object representing the block. When a block is deselected an `emthree.RESET` message is sent.

**PARAMETERS**
* ```board``` (table) - The board to apply the input to
* ```action``` (table) - The action table received from the engine lifecycle function on_input. Only pass on touch/click events where `pressed` or `released` is true.


### emthree.on_match(board, fn)
Set a function to be called whenever a match on the board is detected. Use this callback to remove the blocks involved in the match and optionally also create new blocks based on the match.

**PARAMETERS**
* ```board``` (table) - The board that will notify when a match is detected
* ```fn``` (function) - The function to call when a match is detected. The function will receive `board` and `block` as arguments.


### emthree.on_block_removed(board, fn)
Set a function to be called whenever a block is removed. Use this callback to trigger effects on special blocks.

**PARAMETERS**
* ```board``` (table) - The board that will notify when a block is removed
* ```fn``` (function) - The function to call when a block is removed. The function will receive `board` and `block` as arguments.


### emthree.on_stabilized(board, fn)
Set a function to be called when the board is stable. Use this callback to for instance enable user input or make score calculations.

**PARAMETERS**
* ```board``` (table) - The board that will notify when stable
* ```fn``` (function) - The function to call when the board is stable. The function will receive `board` as arguments.


### emthree.on_swap(board, fn)
Set a function to be called whenever a two blocks have swapped places based on user input. Use this to trigger effects when certain types of blocks were swapped.

**PARAMETERS**
* ```board``` (table) - The board where swaps will be notified
* ```fn``` (function) - The function to call when a swap is made. The function is expected to take `board`, `slot1` and `slot2` as arguments and return true if swap resulted in any changes on the board.


## Messages

### emthree.REMOVE
Message sent to the game object representing a block on the board when it is to be removed.


### emthree.CHANGE
Message sent to the game object representing a block on the board when it is to change color and/or type.

**PARAMETERS**
* ```color``` (any) - The color to change to
* ```type``` (any) - The type to change to


### emthree.SELECT
Message sent to the game object representing a block on the board when it is selected.


### emthree.RESET
Message sent to the game object representing a block on the board when it is deselected.
