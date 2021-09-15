local PATH = minetest.get_modpath(minetest.get_current_modname())
local get_drawtype = dofile(PATH .. "/drawtypes.lua")
local interactions = dofile(PATH .. "/interact.lua")

minetest.register_entity("lvae:node", {
	on_activate = function(self, _, dtime)
		self.object:set_armor_groups({immortal = 1, punch_operable = 0})
		return dtime ~= 0 and self.object:remove()
	end,
	on_rightclick = interactions.place,
	on_punch = interactions.dig,
	timer = 0,
	-- Converts generated tiles and frames into usable textures.
	-- This needs to be called at least once to show the textures on a node.
	-- Should be called regularly on animated nodes.
	update_textures = function(self)
		local drawtype = minetest.registered_nodes[self.node.name].drawtype
		local tex6 = not drawtype or drawtype == "normal" or drawtype:match("glasslike") or drawtype:match("allfaces")
		if not self.tiles then return end
		local textures = {}
		for _, ttype in pairs({"tiles", "overlay_tiles"}) do
			local t = {}
			for i, tile in ipairs(self.tiles[ttype]) do
				if type(tile) ~= "table" then
					t[i] = tile
				else
					self.animated = true
					t[i] = tile[math.floor(self.timer * (#tile / tile.length)) % #tile + 1]
				end
			end
			for i, tex in pairs(t) do
				if textures[i] then
					textures[i] = textures[i] .. "^" .. tex
				else
					textures[i] = tex
				end
			end
		end

		self.object:set_properties({textures = textures})
	end,
	on_step = function(self, dtime)
		-- TODO: convert this to recursive update_textures function using FPS
        -- TODO: Move to global handler to reduce active objects
		if self.animated then
			self.timer = self.timer + dtime
			self:update_textures()
		end
	end,
})

local lvae = {}

function lvae:new_block(pos)
	local r = self.radius
	local s = (r * 2) + 1 -- Block size

	-- Get the mapblock position (centered) and min/max edges
	local block = vector.apply(pos, function(v) return math.floor((v + r) / s) end)
	local bmin = vector.apply(block, function(v) return (v * s) - r end)
	local bmax = vector.apply(block, function(v) return (v * s) + r end)

	local emin = vector.sort(self.area.MinEdge, bmin)
	local _, emax = vector.sort(self.area.MaxEdge, bmax)

	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = {}

	-- Copy the data because the VoxelArea indexes have changed
	for i, n in pairs(self.data) do
		data[area:indexp(self.area:position(i))] = n
	end

	self.area = area
	self.data = data
end

function lvae:set_node(pos, node)
	-- Just remove the node if they are setting air
	if node.name == "air" then return self:remove_node(pos) end

	-- If the node doesn't exist then dont add it
	-- TODO: Handle unknown nodes
	if not minetest.registered_nodes[node.name] then return end

	-- Add a new mapblock if position is out of range
	if not self.area:containsp(pos) then self:new_block(pos) end
	local idx = self.area:indexp(pos)

	node.param1 = node.param1 or 0
	node.param2 = node.param2 or 0

	local lnode
	if self.data[idx] and self.data[idx].entity then -- Dont bother adding a new entity if one is already there
		lnode = self.data[idx].entity
	else
		lnode = minetest.add_entity(vector.new(0, 0, 0), "lvae:node"):get_luaentity()
		lnode.idx = idx
		lnode.parent = self

		-- Add new node data
		node.entity = lnode
		self.data[idx] = node
	end

	lnode.node = node
	lnode.pos = pos
	local properties, rotation, position = get_drawtype(node, pos, self)
	properties.infotext = node.name
	-- lnode.object:set_nametag_attributes({text = node.name .. "\n" .. minetest.pos_to_string(pos)})
	lnode.object:set_properties(properties)
	lnode.tiles = properties.tiles -- Cant be set as a property because it will get nuked
	lnode:update_textures()
	lnode.object:set_attach(
		self.object, "",
		vector.multiply(vector.add(pos, position or {x = 0, y = 0, z = 0}), 10),
		rotation or {x = 0, y = 0, z = 0}
	)

	-- Update surrounding nodes
	-- This could probably be changed to do the job of the code above
	for y = -1, 1 do
		for z = -1, 1 do
			for x = -1, 1 do
				if not (math.abs(x) == math.abs(y) and math.abs(y) == math.abs(z)) then
					local upos = vector.add(pos, vector.new(x, y, z))
					local unode = self:get_node_or_nil(upos)
					if unode and unode.name ~= "air" then
						local e = self.data[self.area:indexp(upos)].entity
						if e then
							local uproperties, urotation, uposition = get_drawtype(unode, upos, self)
							e.object:set_properties(uproperties)
							e.tiles = uproperties.tiles
							e.drawtype = minetest.registered_nodes[unode.name].drawtype
							e:update_textures()
							e.object:set_attach(
								self.object, "",
								vector.multiply(vector.add(upos, uposition or {x = 0, y = 0, z = 0}), 10),
								urotation or {x = 0, y = 0, z = 0}
							)
						end
					end
				end
			end
		end
	end
end

lvae.add_node = lvae.set_node

function lvae:bulk_set_node(positions, node)
	-- This is lazy but it gets the job done
	for _, pos in pairs(positions) do
		self:set_node(pos, node)
	end
end

function lvae:swap_node(pos, node)
	local oldnode = self:get_node(pos)
	self:set_node(pos, {name = node.name, param1 = node.param1, param2 = oldnode.param2, meta = oldnode.meta})
end

function lvae:remove_node(pos)
	if self.area:containsp(pos) then
		local idx = self.area:indexp(pos)
		if self.data[idx] then
			self.data[idx].entity.object:remove()
			self.data[idx] = nil
		end
	end
end

function lvae:get_node(pos)
	if not self.area:containsp(pos) then return {name = "ignore", param1 = 0, param2 = 0} end
	local node = self.data[self.area:indexp(pos)] or {}
	return {name = node.name or "air", param1 = node.param1 or 0, param2 = node.param2 or 0}
end

function lvae:get_node_or_nil(pos)
	if not self.area:containsp(pos) then return end
	return self:get_node(pos)
end

function lvae:place_node(pos, node)
	local entity = self:set_node(pos, node)
	local sounds = minetest.registered_nodes[node.name].sounds
	if sounds and sounds.place then minetest.sound_play(sounds.place, {pos = vector.add(self.object:get_pos(), pos)}, true) end
	-- Could do some on_ functions
end

function lvae:restore(idx)
	if idx then
		self:set_node(self.area:position(idx), self.data[idx])
		self:restore(next(self.data, idx))
	end
end

function lvae:on_activate(staticdata)
	if staticdata == "" or tonumber(staticdata) then -- New lvae
		local r = tonumber(staticdata) or 7
		self.radius = r
		self.area = VoxelArea:new({MinEdge = vector.new(-r, -r, -r), MaxEdge = vector.new(r, r, r)})
		self.data = {}
	else -- Restore old data
		local restore = minetest.deserialize(staticdata)
		self.radius = restore.radius
		self.area = VoxelArea:new({MinEdge = restore.emin, MaxEdge = restore.emax})
		self.data = restore.data
		self:restore(next(self.data))
	end
end

function lvae:get_staticdata()
	if not self.data then return end

	local sanitized = {}
	for idx, node in pairs(self.data) do
		sanitized[idx] = table.copy(node)
		sanitized[idx].entity = nil
	end

	return minetest.serialize({
		radius = self.radius,
		emin = self.area.MinEdge,
		emax = self.area.MaxEdge,
		data = sanitized,
	})
end

function lvae:remove()
	for _, node in pairs(self.data) do
		if node.entity then node.entity.object:remove() end
	end
	self.object:remove()
end

lvae.initial_properties = {textures = {"blank.png"}, pointable = false, visual_size = {x = 0, y = 0, z = 0}}
minetest.register_entity("lvae:lvae", lvae)

function LVAE(pos)
	return minetest.add_entity(pos, "lvae:lvae"):get_luaentity()
end

-- Restore LVAEs after clearing objects
local clear_objects = minetest.clear_objects
minetest.clear_objects = function(...)
	local saved = {}
	for _, entity in pairs(minetest.luaentities) do
		if entity.name == "lvae:lvae" then
			saved[#saved + 1] = {pos = entity.object:get_pos(), staticdata = entity:get_staticdata()}
		end
	end

	local ret = clear_objects(...)

	for _, data in pairs(saved) do
		minetest.add_entity(data.pos, "lvae:lvae", data.staticdata)
	end

	return ret
end

minetest.register_chatcommand("clearlvaes", {
	description = "Clear all LVAEs in world",
	privs = {server = true},
	func = function(name, param)
		minetest.log("action", name .. " clears all LVAEs.")
		minetest.chat_send_all("Clearing all LVAEs. This may take a long time."
				.. " You may experience a timeout. (by "
				.. name .. ")")
		local count = 0
		for _, entity in pairs(minetest.luaentities) do
			if entity.name == "lvae:lvae" then entity:remove() count = count + 1 end
		end
		minetest.log("action", "Cleared " .. count .. " LVAEs.")
		minetest.log("action", "LVAE clearing done.")
		minetest.chat_send_all("*** Cleared all LVAEs.")
		return true
	end
})
