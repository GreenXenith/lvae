-- This file should be called in a register_on_mods_loaded hook
-- Loads all color palettes and tilesheets into Lua memory for use later

local palettes = {}
local sheets = {}

local png = dofile(... .. "/png.lua")
assert(png, "Failed to load PNG module. I don't know why or how this happened.")

local all_textures = {}
local mods = {}

-- Collect all the filepaths (indexed by filename)
-- TODO: Support all media paths
-- TODO: Support recursive media paths
for _, modname in pairs(minetest.get_modnames()) do
	local path = minetest.get_modpath(modname) .. "/textures/"
	local files = minetest.get_dir_list(path, false)
	mods[modname] = {}
	for _, file in pairs(files) do
		if file:sub(-4) == ".png" then
			mods[modname][file] = path .. file
			all_textures[file] = mods[modname][file]
		end
	end
end

for node, def in pairs(minetest.registered_nodes) do
	-- Read image palette into memory
	if def.palette then
		local image = png.load_from_file(mods[def.mod_origin] and mods[def.mod_origin][def.palette] or all_textures[def.palette])
		local palette = {}
		local idx = 0
		for pixel, px, py in png.pixels(image) do
			palette[idx] = minetest.rgba(pixel.r, pixel.g, pixel.b)
			idx = idx + 1
		end
		palette.size = idx
		palettes[def.palette] = palette
	end

	-- Store tilesheet dimensions
	for _, ttype in pairs({"tiles", "overlay_tiles"}) do
		if def[ttype] then
			for _, tile in pairs(def[ttype]) do
				if type(tile) == "table" then
					tile.name = tile.name or tile.image
					if tile.animation and not sheets[tile.name] then
						-- Could just read the image and extract the proper headers, but too lazy to do that
						local image = png.load_from_file(mods[def.mod_origin] and mods[def.mod_origin][tile.name] or all_textures[tile.name])
						local w, h = 0, 0
						for _, px, py in png.pixels(image) do
							w, h = px, py
						end
						sheets[tile.name] = {width = w + 1, height = h + 1}
					end
				end
			end
		end
	end
end

return palettes, sheets
