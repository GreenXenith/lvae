# Lua Voxel Area Entities (Alpha)
True voxel area entities written in Lua.  

### What is this?
LVAE is an API for mods to use to create large structures that are not locked to the node grid and can be moved or rotated like an entity.

### What about [meshnode](https://forum.minetest.net/viewtopic.php?f=11&t=8059)?
Meshnode is not an API. On top of that, it lacks support for many drawtypes and nodes. It is also very outdated (released in 2013). LVAE can be used to make a similar mod (and one will be released in the near future).

## Usage
Add `lvae` as a dependency in your mod.  
Use `LVAE(pos)` to create a new LVAE at position `pos` (returns a luaentity).  
The returned object has methods mirroring those listed in the Minetest API for world interaction, such as `set_node`, `get_node`, etc.  
Positions are relative to the parent position.  
Example:  
```lua
local lvae = LVAE({x = 0, y = 10, z = 0})
lvae:set_node({x = 0, y = 0, z = 0}, {name = "default:cobble"})
print(lvae:get_node({x = 0, y = 0, z = 0}).name) -- Will return "default:cobble"
```

## Todo
### Logic and interaction
* Implement proper placing/digging logic
* World-aligned textures
* Node metadata/inventories
* on_* hooks

### Drawtypes
* Fix nodeboxes (they are far from perfect)
* `plantlike_rooted`
* `glasslikeliquidlevel` (paramtype2)
* `glasslike_framed`  
  I do not intend to implement liquids any time soon, but it should be possible.

### API
* Object flags (interactable, metadata, etc)
* Implement as many node methods as possible
* Import nodes from VoxelManip
