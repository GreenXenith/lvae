-- NOTE: Most of this file is a mess and is likely broken. Could use a rewrite.

-- Convert a box table to a mesh
-- All arrays in this function are flat
local function boxes_to_faces(boxes)
	if not boxes then return end
	if type(boxes[1]) ~= "table" then boxes = {boxes} end

	local verts = {}
	local faces = {}
	local texcs = {}

	for _, b in pairs(boxes) do
		-- Box as vertices
		local v = {
			{b[4], b[5], b[3]}, {b[1], b[5], b[3]}, {b[1], b[5], b[6]}, {b[4], b[5], b[6]},
			{b[4], b[2], b[3]}, {b[1], b[2], b[3]}, {b[1], b[2], b[6]}, {b[4], b[2], b[6]},
		}

		for _, vert in pairs(v) do
			verts[#verts + 1] = vert
		end

		--        z-
		--    2 ------ 1
		--    |\       |\
		--    | \      | \
		-- x+ |  3 ------ 4 x-
		--    6 -|---- 5  |
		--     \ |      \ |
		--      \|       \|
		--       7 ------ 8
		--            z+

		-- Faces constructed using vertex indices
		-- Follows nodebox tile order
		-- Counter-clockwise winding order is important
		local f = {
			{1, 2, 3, 4}, {8, 7, 6, 5}, -- y+, y-
			{3, 2, 6, 7}, {1, 4, 8, 5}, -- x+, x-
			{4, 3, 7, 8}, {2, 1, 5, 6}, -- z+, z-
		}

		math.sign = math.sign or function(n) return n > 0 and 1 or n < 0 and -1 or 0 end
		-- Map vertex components to uv components
		local tmap = {
			{-1,  3}, -- y+
			{-1, -3}, -- y-
			{ 3,  2}, -- x+
			{-3,  2}, -- x-
			{ 1,  2}, -- z+
			{-1,  2}, -- z-
		}

		-- Create 4 UV coordinates for each face
		for i = 1, 6 do
			for j = 1, 4 do
				-- Using the actual vertex coordinates will make it scale properly
				local vx = v[f[i][j]]
				local x = tmap[i][1]
				local y = tmap[i][2]
				texcs[#texcs + 1] = {vx[math.abs(x)] * math.sign(x) + 0.5, vx[math.abs(y)] * math.sign(y) + 0.5}
			end
		end

		local off = #faces
		local voff = ((off / 6) * 8)
		for i, face in pairs(f) do
			local toff = (off * 4) + ((i - 1) * 4)
			-- vertex index, uv index, normal index
			faces[#faces + 1] = {
				face[1] + voff, 1 + toff, i,
				face[2] + voff, 2 + toff, i,
				face[3] + voff, 3 + toff, i,
				face[4] + voff, 4 + toff, i,
			}
		end
	end

	return {verts = verts, faces = faces, texcs = texcs}
end

local function insert(t, v)
	table.insert(t, v or false)
end

local function nodebox_to_mesh(nodebox, filepath)
	local boxes = {}

	if nodebox.type == "normal" then
		insert(boxes, boxes_to_faces({-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}))
	elseif nodebox.type == "fixed" then
		insert(boxes, boxes_to_faces(nodebox.fixed))
	elseif nodebox.type == "leveled" then
		insert(boxes, boxes_to_faces(nodebox.fixed))
	elseif nodebox.type == "wallmounted" then
		insert(boxes, boxes_to_faces(nodebox.wall_top))
		insert(boxes, boxes_to_faces(nodebox.wall_bottom))
		insert(boxes, boxes_to_faces(nodebox.wall_side))
	elseif nodebox.type == "connected" then
		insert(boxes, boxes_to_faces(nodebox.fixed))

		for _, dir in pairs({"top", "bottom", "front", "left", "back", "right"}) do
			insert(boxes, boxes_to_faces(nodebox["connect_" .. dir]))
		end

		for _, dir in pairs({"top", "bottom", "front", "left", "back", "right"}) do
			insert(boxes, boxes_to_faces(nodebox["disconnected_" .. dir]))
		end

		insert(boxes, boxes_to_faces(nodebox.disconnected))
		insert(boxes, boxes_to_faces(nodebox.disconnected_sides))
	end

	local mesh = io.open(filepath, "w")

	local norms = {
		{-1, 0, 0}, {1, 0, 0}, -- x
		{0, -1, 0}, {0, 1, 0}, -- y
		{0, 0, -1}, {0, 0, 1}, -- z
	}
	for _, n in pairs(norms) do
		mesh:write(("vn %s %s %s\n"):format(unpack(n)))
	end

	-- Each box has local offsets. These are used as a sort of "global" offset
	local vcount = 0
	local tcount = 0
	local mcount = 0

	-- Each box may be one or more cuboids
	for _, box in pairs(boxes) do
		if box then
			for _, v in pairs(box.verts) do
				mesh:write(("v %s %s %s\n"):format(unpack(v)))
			end

			for _, t in pairs(box.texcs) do
				mesh:write(("vt %s %s\n"):format(unpack(t)))
			end

			for f = 1, 6 do
				mcount = mcount + 1
				mesh:write(("g M_%s\n"):format(mcount))
				for j = 0, #box.faces / 6 - 1 do
					local face = {}
					for i = 1, 12, 3 do
						face[i] = box.faces[f + j * 6][i] + vcount
						face[i + 1] = box.faces[f + j * 6][i + 1] + tcount
						face[i + 2] = box.faces[f + j * 6][i + 2]
					end
					mesh:write(("f %s/%s/%s %s/%s/%s %s/%s/%s %s/%s/%s\n"):format(unpack(face)))
				end
			end

			vcount = vcount + #box.verts
			tcount = tcount + #box.texcs
		else -- Still need to increment materials
			for i = 1, 6 do
				mcount = mcount + 1
				mesh:write(("g M_%s\n"):format(mcount))
				mesh:write(("f 1/1/1 1/1/1 1/1/1 1/1/1\n"))
			end
		end
	end

	mesh:close()
end

-- Put media files in the current world folder to avoid conflicts when running
-- the mod in simultaneous servers
local path = minetest.get_worldpath() .. "/lvae"
minetest.mkdir(path)

for name, def in pairs(minetest.registered_nodes) do
	if def.drawtype == "nodebox" then
		local filename = ("lvae_%s.obj"):format(name:gsub(":", "_"))
		nodebox_to_mesh(def.node_box, path .. "/" .. filename)
		-- worldmods are loaded before other mods, so we cant write the media
		-- at this point and expect it to load. Dynamic media has to be added
		-- during runtime, so we use minetest.after. This runs in a globalstep,
		-- which means the media shouldnt be sent until the server step starts
		-- and the server is loaded.
		minetest.after(0, function()
			minetest.dynamic_add_media({filepath = path .. "/" .. filename}, function() end)
		end)
	end
end

-- Clear out generated files since they may change later
minetest.register_on_shutdown(function()
	for _, filename in pairs(minetest.get_dir_list(path, false)) do
		os.remove(path .. "/" .. filename)
	end
	os.remove(path)
end)
