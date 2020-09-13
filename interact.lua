local interactions = {}

minetest.register_entity("lvae:raycollider", {
	visible = false,
	physical = true,
})

interactions.place = function(entity, player)
	local stack = player:get_wielded_item()
	local itemname = stack:get_name()
	local def = minetest.registered_nodes[itemname]
	if def then
		local eye = vector.add(vector.add(player:get_pos(), {x = 0, y = player:get_properties().eye_height, z = 0}), player:get_eye_offset())
		local target = vector.add(eye, vector.multiply(player:get_look_dir(), minetest.is_creative_enabled(player:get_player_name()) and 10 or (def.range or 4)))
		local ray = minetest.raycast(eye, target)

		-- Racycasting doesn't work on attached entities, so use a temporary one
		local rc = minetest.add_entity(vector.add(entity.pos, entity.parent.object:get_pos()), "lvae:raycollider")

		-- Make sure the ray doesn't accidentally hit something
		local physical = entity.object:get_properties().physical
		entity.object:set_properties({physical = false})

		ray:next()
		local pointed = ray:next()

		entity.object:set_properties({physical = physical})
		rc:remove()

		if pointed then
			local pos = vector.add(entity.pos, pointed.intersection_normal)
			-- TODO: check for ignore/air/buildable_to
			-- TODO: get param2 from stack and normal or something
			entity.parent:place_node(pos, {name = itemname})
			-- TODO: decrement stack
		end
	end
end

-- TODO: Calculate digging times
-- TODO: Crack animations
interactions.dig = function(entity, player)
	entity.parent:remove_node(entity.pos)
end

return interactions
