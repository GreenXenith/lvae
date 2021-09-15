local drawtypes = {}
local palettes = {}
local sheets = {}

local PATH = minetest.get_modpath(minetest.get_current_modname())
minetest.register_on_mods_loaded(function()
	palettes, sheets = assert(loadfile(PATH .. "/textures.lua"))(PATH)
	dofile(PATH .. "/nodebox.lua")
end)

-- Helpers
local function def(node) return minetest.registered_nodes[node.name] end

local function colorstring(colorspec)
	if type(colorspec) == "string" then
		return colorspec
	elseif type(colorspec) == "number" then
		return string.format("#%x", tile.color)
	elseif type(colorspec) == "table" then
		return minetest.rgba(colorspec.r, colorspec.g, colorspec.b, colorspec.a)
	end
	return "#FFFFFF"
end

-- TODO: World-aligned tiles
local function get_textures(node, pos, tex6)
	local d = def(node)
	local textures = {}
	local color = (d.color and colorstring(d.color)) or "#FFFFFF"

	-- Palette overrides node color
	if d.palette then
		local p = palettes[d.palette]
		-- Compress the index if needed (reverse stretch)
		local idx = math.floor(node.param2 / math.floor(256 / p.size))
		if idx < p.size then
			color = p[idx]
		end -- No need to do palette padding - default is already white
	end

	for _, ttype in pairs({"tiles", "overlay_tiles"}) do
		textures[ttype] = {}
		local t = textures[ttype]
		for i = 1, #(d[ttype] or {}) do
			local tile = d[ttype][i]
			if type(tile) == "string" then
				t[i] = tile .. "^[multiply:" .. color
			else
				local tile_color = color
				-- Tile color overrides palette color
				if tile.color then
					tile_color = colorstring(tile.color)
				end

				tile.name = tile.name or tile.image

				if not tile.animation then
					t[i] = tile.name .. "^[multiply:" .. tile_color
					if tile.align_style == "world" then
						-- Use param2 to determine texture rotations for world alignment
						-- Do some scaling
					end
				else
					local anim = tile.animation
					local sheet = sheets[tile.name]
					t[i] = {}

					if anim.type == "vertical_frames" then
						local frame_count = sheet.height / (anim.aspect_h or anim.aspect_w)
						t[i].length = anim.length
						for f = 1, frame_count do
							t[i][f] = ("[combine:%sx%s:%s,-%s=%s"):format(anim.aspect_w, anim.aspect_h, 0, (f - 1) * anim.aspect_h, tile.name)
							t[i][f] = t[i][f] .. "^[multiply:" .. tile_color
						end
					else -- anim.type == "sheet_2d"
						local frame_count = anim.frames_w * anim.frames_h
						t[i].length = frame_count * anim.frame_length
						local aspect_w, aspect_h = sheet.width / anim.frames_w, sheet.height / anim.frames_h
						for f = 1, frame_count do
							t[i][f] = ("[combine:%sx%s:-%s,-%s=%s"):format(aspect_w, aspect_h, ((f - 1) % anim.frames_w) * aspect_w, math.floor((f - 1) / anim.frames_w) * aspect_h, tile.name)
							t[i][f] = t[i][f] .. "^[multiply:" .. tile_color
						end
					end
				end
			end
		end

		-- Duplicate texture to fill 6 slots
		if tex6 then
			if #t == 1 then
				t[2] = t[1]
				t[3] = t[1]
				t[4] = t[1]
				t[5] = t[1]
				t[6] = t[1]
			elseif #t == 2 then
				t[3] = t[2]
				t[4] = t[2]
				t[5] = t[2]
				t[6] = t[2]
				t[2] = t[1]
			elseif #t == 3 then
				t[4] = t[3]
				t[5] = t[3]
				t[6] = t[3]
			end
		end
	end

	return textures
end

local rotations = {
	facedir = {[0] =
		{x = 0,   y = 0,   z = 0  }, -- 0
		{x = 0,   y = 90,  z = 0  },
		{x = 0,   y = 180, z = 0  },
		{x = 0,   y = -90, z = 0  },
		{x = 90,  y = 0,   z = 0  }, -- 4
		{x = 90,  y = 0,   z = 90 },
		{x = 90,  y = 0,   z = 180},
		{x = 90,  y = 0,   z = -90},
		{x = -90, y = 0,   z = 0  }, -- 8
		{x = -90, y = 0,   z = -90},
		{x = -90, y = 0,   z = 180},
		{x = -90, y = 0,   z = 90 },
		{x = 0,   y = 0,   z = -90}, -- 12
		{x = 90,  y = 90,  z = 0  },
		{x = 180, y = 0,   z = 90 },
		{x = 0,   y = -90, z = -90},
		{x = 0,   y = 0,   z = 90 }, -- 16
		{x = 0,   y = 90,  z = 90 },
		{x = 180, y = 0,   z = -90},
		{x = 0,   y = -90, z = 90 },
		{x = 180, y = 180, z = 0  }, -- 20
		{x = 180, y = 90,  z = 0  },
		{x = 180, y = 0,   z = 0  },
		{x = 180, y = -90, z = 0  },
	},
	wallmounted = {[0] =
		{x = -90, y = 90,  z = 0}, -- 0
		{x = 90,  y = 90,  z = 0},
		{x = 0,   y = 90,  z = 0},
		{x = 0,   y = -90, z = 0},
		{x = 0,   y = 0,   z = 0}, -- 4
		{x = 0,   y = 180, z = 0},
		{x = 0,   y = 90,  z = 0},
		{x = 0,   y = 90,  z = 0},
	}
}

local function get_node_rotation(node)
	local paramtype2 = def(node).paramtype2

	if paramtype2:match("facedir") then
		return rotations.facedir[(node.param2 % 32) % 24]
	elseif paramtype2:match("wallmounted") then
		return rotations.wallmounted[node.param2 % 8]
	end

	return {x = 0, y = 0, z = 0}
end

local scale_ten = {x = 10, y = 10, z = 10}

-- Drawtype functions are given 3 parameters: node, pos, lvae
-- These can be used to return visual properties based on surrounding nodes.
-- Functions should return a properties table, a rotation, and a position offset.
-- The properties table should include a tiles (not textures) key, typically set
-- to the result of get_textures(node, pos, tex6). When the tex6 key is set to a
-- truthy value, the textures will be duplicated to fill 6 indices.
-- param2 rotations should be handled per-drawtype, as each drawtype handles
-- rotation differently. It will default to a 0-vector.
-- Position should be used when messing with visual size in order for nodes to
-- look correct. It will default to a 0-vector.

-- Much of the drawing logic is translated from the source
-- https://github.com/minetest/minetest/blob/master/src/client/content_mapblock.cpp

drawtypes.normal = function(node, pos)
	local d = def(node)
	return {
		visual = "cube",
		tiles = get_textures(node, pos, true),
	}, get_node_rotation(node)
end

drawtypes.airlike = function(node)
	return {
		is_visible = false,
	}
end

-- NOTE: Look into liquid rollback for this
-- drawtypes.liquid

-- drawtypes.flowingliquid

-- TODO: Add adjacent culling for glasslike if implemented
drawtypes.glasslike = function(node, pos)
	return drawtypes.normal(node, pos)
end

drawtypes.glasslike_framed = function(node, pos)
	return drawtypes.glasslike(node, pos)
end

drawtypes.glasslike_framed_optional = function(node, pos)
	return drawtypes.glasslike(node, pos)
end

drawtypes.allfaces = function(node, pos)
	local properties, position, rotation, tiles = drawtypes.normal(node, pos)
	properties.visual_size = def(node).visual_scale
	return properties, position, rotation, tiles
end

drawtypes.allfaces_optional = function(node, pos)
	return drawtypes.allfaces(node, pos)
end

drawtypes.torchlike = function(node, pos, lvae)
	local d = def(node)
	-- Rotation only works when using a wallmounted paramtype
	node.param2 = (d.paramtype2:match("wallmounted") and node.param2 or 0) % 8

	local position = {x = 0, y = 0, z = 0}
	local axis = {[0] = "y", "y", "x", "x", "z", "z", "x", "x"}
	local mult = {[0] = -1, 1, -1, 1, -1, 1, -1, -1}
	position[axis[node.param2]] = (d.visual_scale - 1) * 0.5 * mult[node.param2]

	local tile, rotation = unpack(({[0] =
		{2, {x = 0, y = 45, z = 0}},
		{1, {x = 0, y = -45, z = 0}},
		{3, {x = 0, y = 0, z = 0}},
		{3, {x = 0, y = 180, z = 0}},
		{3, {x = 0, y = -90, z = 0}},
		{3, {x = 0, y = 90, z = 0}}
	})[node.param2] or {3, {x = 0, y = 0, z = 0}})

	return {
		visual = "mesh",
		mesh = "torchlike.obj",
		tiles = get_textures(node, pos),
		visual_size = vector.multiply(scale_ten, d.visual_scale),
		backface_culling = false,
	}, rotation, position
end

drawtypes.signlike = function(node, pos, lvae)
	local d = def(node)
	node.param2 = (d.paramtype2:match("wallmounted") and node.param2 or 0) % 8

	local position = {x = 0, y = 0, z = 0}
	local axis = {[0] = "y", "y", "x", "x", "z", "z", "x", "x"}
	local mult = {[0] = -1, 1, -1, 1, -1, 1, -1, -1}
	position[axis[node.param2]] = (d.visual_scale - 1) * 0.5 * mult[node.param2]

	return {
		visual = "mesh",
		mesh = "signlike.obj",
		tiles = get_textures(node, pos),
		visual_size = vector.multiply(scale_ten, d.visual_scale),
		backface_culling = false,
	}, rotations.wallmounted[node.param2], position
end

drawtypes.plantlike = function(node, pos, lvae)
	local d = def(node)
	local shape = 0
	local rotation = {x = 0, y = 0, z = 0}
	local position = {x = 0, y = 0, z = 0}
	local scale = 1

	if d.paramtype2 == "meshoptions" then
		shape = node.param2 % 8
		local mod = node.param2 - shape
		-- Bit 3: Random horizontal placement
		if mod == 8 or mod == 24 or mod == 40 or mod == 56 then
			-- This is not 100% accurate. The engine uses (x << 8 | z | y << 16)
			-- for the seed, which I cannot reproduce efficiently in Lua. Oh well.
			local rng = PcgRandom(tonumber(minetest.hash_node_position(pos)))
			position.x = (rng:next() % 16 / 16) * 0.29 - 0.145 -- There used to be a 10x scaler here
			position.z = (rng:next() % 16 / 16) * 0.29 - 0.145 -- We dont need it because attachments are 1/10
		end
		-- Bit 4: 1.4x mesh scale
		if mod == 16 or mod == 24 or mod == 48 or mod == 56 then
			-- There is a scaling quirk where the top edges retain their x/z positions and only the y position changes.
			-- Entities obviously do not share this oddity. This is only noticable on shape 4 (outward # shape).
			scale = math.sqrt(2)
		end
		-- Bit 5: Random face -y movement
		if mod == 32 or mod == 40 or mod == 48 or mod == 56 then
			-- Not implemented yet. Will implement using bones.
		end
	elseif d.paramtype2 == "degrotate" then
		rotation.y = node.param2 * 2
	end

	scale = scale * d.visual_scale
	position.y = (scale - 1) * 0.5

	return {
		visual = "mesh",
		mesh = "plantlike" .. shape .. ".obj",
		tiles = get_textures(node, pos),
		visual_size = vector.multiply(scale_ten, scale),
		backface_culling = false,
	}, rotation, position
end

drawtypes.firelike = function(node, pos, lvae)
	local d = def(node)
	local textures = {}
	local tile = 1
	local node_under = lvae:get_node_or_nil(vector.add(pos, {x = 0, y = -1, z = 0}))
	local adjacent

	if node_under and node_under.name ~= "air" then
		adjacent = false
	else
		textures = {"blank.png"}
		local node_above = lvae:get_node_or_nil(vector.add(pos, {x = 0, y = 1, z = 0}))
		local dirs = {
			{x = 0, y = 0, z = 1}, -- N
			{x = 1, y = 0, z = 0}, -- E
			{x = 0, y = 0, z = -1}, -- S
			{x = -1, y = 0, z = 0}, -- W
		}

		for i, dir in pairs(dirs) do
			local dnode = lvae:get_node_or_nil(vector.add(pos, dir))
			if dnode and dnode.name ~= "air" then
				textures[1 + i] = tile
				textures[5 + i] = "blank.png"
				adjacent = true
			elseif node_above and node_above.name ~= "air" then
				textures[5 + i] = tile
				textures[1 + i] = "blank.png"
				adjacent = true
			else
				textures[1 + i] = "blank.png"
				textures[5 + i] = "blank.png"
			end
		end
	end

	if not adjacent then
		textures = {tile, tile, tile, tile, tile, "blank.png", "blank.png", "blank.png", "blank.png"}
	end

	local tiles = get_textures(node, pos)
	local t1 = tiles.tiles[1]
	local t2 = tiles.overlay_tiles[1]
	for i, t in pairs(textures) do
		tiles.tiles[i] = (t == 1 and {t1} or {t})[1]
		tiles.overlay_tiles[i] = (t == 1 and {t2} or {t})[1]
	end

	return {
		visual = "mesh",
		mesh = "firelike.obj",
		tiles = tiles,
		visual_size = vector.multiply(scale_ten, d.visual_scale),
		backface_culling = false,
	}, {x = 0, y = 0, z = 0}, {x = 0, y = (d.visual_scale - 1) * 0.5, z = 0}
end

-- NOTE: This is a useless drawtype and should be deprecated
-- See: https://github.com/minetest/minetest/issues/10269
-- drawtypes.fencelike

local function is_same_rail(node1, pos2, lvae)
	local node2 = lvae:get_node_or_nil(pos2)
	if node2 then
		local def1 = def(node1)
		local def2 = def(node2)
		if def1.groups.connect_to_raillike or def2.groups.connect_to_raillike then
			return def1.groups.connect_to_raillike == def2.groups.connect_to_raillike
		else
			return def1.drawtype == def2.drawtype
		end
	end
end

drawtypes.raillike = function(node, pos, lvae)
	local rail_kinds = {
		[0] = {1, 0}, -- Straight
		[1] = {1, 0},
		[8] = {1, 90},
		[4] = {1, 180},
		[2] = {1, 270},
		[5] = {1, 0},
		[10] = {1, 90},
		[9] = {2, 0}, -- Curved
		[3] = {2, 90},
		[6] = {2, 180},
		[12] = {2, 270},
		[13] = {3, 0}, -- Junction
		[11] = {3, 90},
		[7] = {3, 180},
		[14] = {3, 270},
		[15] = {4, 0}, -- Cross
	}

	local rots = {
		[1] = {x = 0, y = 0, z = 1}, -- N
		[2] = {x = 1, y = 0, z = 0}, -- E
		[4] = {x = 0, y = 0, z = -1}, -- S
		[8] = {x = -1, y = 0, z = 0}, -- W
	}

	local code = 0
	local angle
	local tile_index
	local sloped = false

	for bit, rot in pairs(rots) do
		local npos = vector.add(pos, rot)
		local rail_above = is_same_rail(node, vector.add(npos, {x = 0, y = 1, z = 0}), lvae)
		if rail_above then
			sloped = true
			angle = math.deg(math.atan2(rot.x, rot.z))
		end
		if rail_above or is_same_rail(node, npos, lvae) or is_same_rail(node, vector.add(npos, {x = 0, y = -1, z = 0}), lvae) then
			code = code + bit
		end
	end

	if sloped then
		tile_index = 1
	else
		tile_index = rail_kinds[code][1]
		angle = rail_kinds[code][2]
	end

	local tiles = get_textures(node, pos)

	return {
		visual = "mesh",
		mesh = "raillike.obj",
		tiles = sloped and {
			tiles = {"blank.png", tiles.tiles[tile_index]},
			overlay_tiles = {"blank.png", tiles.overlay_tiles[tile_index]}
		} or {
			tiles = {tiles.tiles[tile_index], "blank.png"},
			overlay_tiles = {tiles.overlay_tiles[tile_index], "blank.png"}
		},
		visual_size = scale_ten,
	}, {x = 0, y = angle, z = 0}
end

drawtypes.nodebox = function(node, pos, lvae)
	local d = def(node)
	local nodebox = d.node_box
	local tiles = get_textures(node, pos, true)
	local textures = {tiles = {}, overlay_tiles = {}}
	local rotation = {x = 0, y = 0, z = 0}
	local b = "blank.png"

	if nodebox.type == "normal" or nodebox.type == "fixed" or nodebox.type == "leveled" then
		textures = tiles
		rotation = get_node_rotation(node, pos)
	elseif nodebox.type == "wallmounted" then
		-- 3 possible nodeboxes with 6 textures each for a total of 18 textures
		for i = 1, 3 * 6 do
			textures.tiles[i] = b
			textures.overlay_tiles[i] = b
		end
		local dir = node.param2 % 8
		local offset = (((dir == 0 or dir >= 6) and 0) or (dir == 1 and 1) or 2) * 6
		for i = 1, 6 do
			textures.tiles[i + offset] = tiles.tiles[i]
			textures.overlay_tiles[i + offset] = tiles.overlay_tiles[i]
		end

		-- Calculate rotation
		local dirs = {
			[2] = {x = 0, y =  0,   z = 0},
			[3] = {x = 0, y =  180, z = 0},
			[4] = {x = 0, y = -90,  z = 0},
			[5] = {x = 0, y =  90,  z = 0},
		}
		if dir > 1 and dir < 6 then
			rotation = dirs[dir] or rotation
		end
	elseif nodebox.type == "connected" then
		-- There are 15 possible nodeboxes with 6 textures each for a total of 90 textures
		for i = 1, 15 * 6 do
			textures.tiles[i] = b
			textures.overlay_tiles[i] = b
		end

		-- Fixed nodebox
		for i = 1, 6 do
			textures.tiles[i] = tiles.tiles[i]
			textures.overlay_tiles[i] = tiles.overlay_tiles[i]
		end

		local dirs = {
			{"top",    {x = 0, y = 1, z = 0}},
			{"bottom", {x = 0, y = -1, z = 0}},
			{"front",  {x = 0, y = 0, z = -1}},
			{"left",   {x = 1, y = 0, z = 0}},
			{"back",   {x = 0, y = 0, z = 1}},
			{"right",  {x = -1, y = 0, z = 0}},
		}
		local connects_to = (type(d.connects_to) == "table" and d.connects_to) or {d.connects_to}
		local disconnected = true
		local disconnected_sides = true

		for i, dir in pairs(dirs) do
			local dirname = dir[1]
			if nodebox["connect_" .. dirname] or nodebox["disconnected_" .. dirname] then
				local dnode = lvae:get_node_or_nil(vector.add(pos, dir[2]))
				local connects = false
				for _, c in pairs(connects_to) do
					connects = (c:sub(1, 6) == "group:" and minetest.get_item_group(dnode.name, c:sub(7)) ~= 0) or dnode.name == c or connects
				end
				if connects then
					disconnected = false
					if i > 2 then disconnected_sides = false end
					if nodebox["connect_" .. dirname] then
						for j = 1, 6 do
							textures.tiles[((1 + i - 1) * 6) + j] = tiles.tiles[j]
							textures.overlay_tiles[((1 + i - 1) * 6) + j] = tiles.overlay_tiles[j]
						end
					end
				elseif nodebox["disconnected_" .. dirname] then
					for j = 1, 6 do
						textures.tiles[((7 + i - 1) * 6) + j] = tiles.tiles[j]
						textures.overlay_tiles[((7 + i - 1) * 6) + j] = tiles.overlay_tiles[j]
					end
				end
			end
		end

		if disconnected then
			for i = 1, 6 do
				textures.tiles[(13 * 6) + i] = tiles.tiles[i]
				textures.overlay_tiles[(13 * 6) + i] = tiles.overlay_tiles[i]
			end
		elseif disconnected_sides then
			for i = 1, 6 do
				textures.tiles[(14 * 6) + i] = tiles.tiles[i]
				textures.overlay_tiles[(14 * 6) + i] = tiles.overlay_tiles[i]
			end
		end
	end

	return {
		visual = "mesh",
		mesh = ("lvae_%s.obj"):format(node.name:gsub(":", "_")),
		tiles = textures,
		visual_size = vector.multiply(scale_ten, d.visual_scale),
	}, rotation
end

drawtypes.mesh = function(node, pos)
	local d = def(node)
	return {
		visual = "mesh",
		mesh = d.mesh,
		tiles = get_textures(node, pos),
		visual_size = vector.multiply(scale_ten, d.visual_scale),
	}, get_node_rotation(node)
end

-- drawtypes.plantlike_rooted

return function(node, pos, lvae)
	local d = def(node)
	local drawtype = drawtypes[d.drawtype or "normal"]
	local properties, rotation, position = (drawtype or drawtypes["airlike"])(node, pos, lvae)

	-- Offset the boxes opposite of the position offset to restore correct position
	-- The true center of the entity will not match the node center.
	-- This may break things like nametags.
	if not vector.equals(position or {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}) then
		properties.collisionbox = properties.collisionbox or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
		properties.selectionbox = properties.selectionbox or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
		local offset = {position.x, position.y, position.z, position.x, position.y, position.z}
		for i, o in pairs(offset) do
			properties.collisionbox[i] = properties.collisionbox[i] - o
			properties.selectionbox[i] = properties.selectionbox[i] - o
		end
	end

	properties.physical = d.walkable
	properties.collide_with_objects = true
	properties.use_texture_alpha = d.use_texture_alpha
	properties.glow = d.light_source

	return properties, rotation, position
end
