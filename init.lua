local modname = minetest.get_current_modname()
local mallets = {}
local sharks = {}

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
			if data.pos and adjacent_water(data.pos) >= 2 then
				return modname .. ":" .. stack:get_name():gsub(":", "__")
			end
		end
	})

	nodecore.register_aism({
		label = "bite or deshark",
		interval = 1,
		chance = 1,
		itemnames = sharks,
		action = function(stack, data)
			if data.pos and adjacent_water(data.pos) < 2 then
				return stack:get_name():sub(modname:len() + 2):gsub("__", ":")
			elseif data.pos and data.inv and minetest.settings:get_bool(modname .. ".bite", true) then
				if math.random(1, 1) == 1 then
					-- Chomp
					nodecore.addphealth(minetest.get_player_by_name(data.inv:get_location().name), -1, modname .. "_bite")
					if math.random(1, 3) == 1 then
						-- Escapé
						local taken = stack:take_item(1)
						nodecore.item_eject(data.pos, taken)
					end
				end
				return stack
			end
		end
	})
end)
