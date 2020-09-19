local modname = minetest.get_current_modname()
local mallets = {}
local sharks = {}

-- Internal settings (per-second; lower = more likely)
local CHANCE_ACTION = 8 -- Probability of doing something while in inventory
local CHANCE_BITE = 5 -- Probability of biting the player
local CHANCE_ESCAPE = 3 -- Probability of leaving the inventory
local CHANCE_CALM = 2 -- Probability multiplier while calm (base chance * calmness * multiplier)
local BITE_DMG = 1 -- Damage done when player is bit
local SUBMERSED_COUNT = 2 -- Total adjacent water nodes to be considered submersed (should be 1-5)

local function register_shark(itemname, def)
	-- Only match not-hot mallet heads from other mods
	if not itemname:match(modname .. ":") and itemname:match("toolhead_mallet") and not def.groups.damage_touch then
		local newname = modname .. ":" .. itemname:gsub(":", "__")
		local newdef = table.copy(def)

		newdef.drop = itemname
		newdef.description = newdef.description:gsub("Mallet Head", "Hammerhead Shark")

		if itemname == "nc_woodwork:toolhead_mallet" then
			newdef.inventory_image = "nc_woodwork_plank.png^[mask:" .. modname .. "_mask.png"
		else
			newdef.inventory_image = newdef.inventory_image:gsub("%[mask:.-%.png", "[mask:" .. modname .. "_mask.png")
		end

		minetest.register_item(":" .. newname, newdef)

		table.insert(mallets, itemname)
		table.insert(sharks, newname)
	end
end

-- Check already-registered items
for itemname, def in pairs(minetest.registered_items) do
	register_shark(itemname, def)
end

-- Catch any new items
nodecore.register_on_register_item(function(itemname, def)
	register_shark(itemname, def)
end)

local function adjacent_water(pos)
	local a = 0
	for _, dir in pairs(nodecore.dirs()) do
		a = a + (minetest.get_item_group(minetest.get_node(vector.add(pos, dir)).name, "water") ~= 0 and 1 or 0)
	end
	return a
end

minetest.register_on_mods_loaded(function()
	nodecore.register_aism({
		label = "sharkify",
		interval = 1,
		chance = 1,
		itemnames = mallets,
		action = function(stack, data)
			if data.pos and adjacent_water(data.pos) >= SUBMERSED_COUNT then
				return modname .. ":" .. stack:get_name():gsub(":", "__")
			end
		end,
	})

	nodecore.register_aism({
		label = "act or deshark",
		interval = 1,
		chance = 1,
		itemnames = sharks,
		action = function(stack, data)
			if data.pos and adjacent_water(data.pos) < SUBMERSED_COUNT then
				-- No longer submersed
				return stack:get_name():sub(modname:len() + 2):gsub("__", ":")
			elseif data.pos and data.inv and minetest.settings:get_bool(modname .. ".hostile", true) then
				-- In inventory and submersed
				if math.random(1, CHANCE_ACTION) == 1 then
					local player = minetest.get_player_by_name(data.inv:get_location().name)
					-- Calmness based on environment
					local calm = 1
					local has_sponge = data.inv:contains_item("main", "nc_sponge:sponge_living") or data.inv:contains_item("main", "nc_sponge:sponge_wet")
					calm = calm + (has_sponge and 1 or 0) -- Enjoys company of sponge
					calm = calm + nodecore.get_node_light(data.pos) / 5 -- Prefers light
					calm = calm - vector.length(vector.multiply(player:get_player_velocity(), {x = 1, y = 0, z = 1})) / 5 -- Not an adrenaline junkie
					calm = math.floor(math.max(1, calm) * math.max(1, CHANCE_CALM))

					-- Chomp
					if CHANCE_BITE > 0 and math.random(1, CHANCE_BITE * calm) == 1 then
						nodecore.addphealth(player, -BITE_DMG, modname .. "_bite")
					end

					-- Escapé
					if CHANCE_ESCAPE > 0 and math.random(1, CHANCE_ESCAPE * calm) == 1 then
						nodecore.item_eject(data.pos, stack:take_item(1))
					end
				end
				return stack
			end
		end,
	})
end)
