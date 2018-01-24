
local toxicityValue = settings.global["toxicity-value"].value;
local radiationAreaSize = settings.global["radiation-area-size"].value;
local invRadiation = settings.global["radiation-in-player-inventory"].value;

local raduranore = settings.global["rad-uran-ore"].value;
local radfuelcell = settings.global["rad-fuel-cell"].value;
local radburntfuelcell = settings.global["rad-burnt-fuel-cell"].value;
local raduranium235 = settings.global["rad-uranium-235"].value;
local raduranium238 = settings.global["rad-uranium-238"].value;
local radcentrifuge = settings.global["rad-centrifuge"].value;
local radreactor = settings.global["rad-reactor"].value;
function _log(...)
 game.print("LOG: " .. ...)
end

script.on_init(function()

end);

function doDamage(event)
	for index,player in pairs(game.connected_players) do 
	    curchar = player.character;
		if curchar then
			curExposedRadiation = get_exposed_radiation(player);
			curHalbwertszeit = get_hwz(player);	
			if curHalbwertszeit < curExposedRadiation then
				curHalbwertszeit = curExposedRadiation;
			end
			if curHalbwertszeit > 100 then
				curHalbwertszeit = 100;
			end
			_log("doDamage [" .. player.name .. "], exposed: " .. tostring(curExposedRadiation) .. " - effective: [" .. tostring(curHalbwertszeit) .. "]");
			if curHalbwertszeit >= 0.1 then
			-- 0.16 player.play_sound("GeigerCounter");
				curchar.damage(curHalbwertszeit, "neutral");
			end
			set_hwz(player, curHalbwertszeit);
		end
	end
end
function doDecay(event)
	for index,player in pairs(game.connected_players) do 
			curHalbwertszeit = get_hwz(player);	

			set_hwz(player, curHalbwertszeit / 2);
	
	end
end
function calcRadiationByItem(name, amount)

	if name =="uranium-ore" then
		return amount / 100000 / 2000 * raduranore;
	elseif name =="uranium-fuel-cell" then
		return radfuelcell * amount;
	elseif name =="used-up-uranium-fuel-cell" then
		return radburntfuelcell * amount;
	elseif name =="uranium-235" then
		return raduranium235 * amount;
	elseif name =="uranium-238" then
		return raduranium238 * amount;

	end

	return 0
end

function calcRadiation(e) 
	--_log("calcRadiation");
	for index,player in pairs(game.connected_players) do 
		curchar = player.character;
		if curchar then
			playerpos = player.position;
			playerarea = {left_top = {playerpos.x -5, playerpos.y -5}, right_bottom = {playerpos.x +5, playerpos.y +5}};
			exposedrad = 0;
			-- exposedrad = exposedrad + player.surface.count_entities_filtered{area = playerarea, name = "uranium-ore"};
			-- exposedrad = exposedrad + player.surface.count_entities_filtered{area = playerarea, name = "nuclear-reactor"} * 5;
			if invRadiation then
				for name,amount in pairs(player.get_inventory(1).get_contents()) do
					exposedrad = exposedrad + calcRadiationByItem(name, amount);
					_log(">>PINV: " .. name .. " " .. amount);

				end			
			end			
			for index,entity in pairs(player.surface.find_entities_filtered{area = playerarea}) do
				if entity.type == "resource" then
					currad = calcRadiationByItem(entity.name, entity.amount);
					if currad > 0 then
						currad = currad *  player.surface.count_entities_filtered{area = playerarea, name = "uranium-ore"};
					end
					_log("entity: " .. entity.type .. " - " .. entity.name .. " - " .. entity.amount .. " ==> " .. tostring(currad) );
					exposedrad = exposedrad + currad;
				elseif entity.type == "transport-belt" then
					currad = 0;
					for name,amount in pairs(entity.get_transport_line(1).get_contents()) do
						currad = currad + calcRadiationByItem(name, amount);
						_log(">>BELT: " .. name .. " " .. amount);
					end
					for name,amount in pairs(entity.get_transport_line(2).get_contents()) do
						currad = currad + calcRadiationByItem(name, amount);
						_log(">>BELT: " .. name .. " " .. amount);

					end
					_log("BELTRAD: " .. tostring(currad))
					exposedrad = exposedrad + currad;

				elseif entity.name == "centrifuge" then
					if entity.is_crafting() then
						currad = 0;
						currad = currad + (player.surface.count_entities_filtered{area = playerarea, name = "centrifuge"} * radcentrifuge);
						exposedrad = exposedrad + currad;
					end
				elseif entity.type == "reactor" then
					if entity.energy  > 0 then
						currad = 0;
						currad = currad + (player.surface.count_entities_filtered{area = playerarea, type = "reactor"} * radreactor);
						exposedrad = exposedrad + currad;
					end
				else
					currad = 0;
					_log("entity: " .. entity.type .. " - " .. entity.name .. " - " .. "n/a" .. " ==> " .. tostring(currad) );
				end
			
			end
			_log("--- EXPOSED: " .. tostring(exposedrad));
			if exposedrad > 1 then
				exposedrad = exposedrad * toxicityValue ;
			end
			
			set_exposed_radiation(player, exposedrad / 2);
		end
	end
end

script.on_event({defines.events.on_tick},   function (e)
	if e.tick % 60 == 0 then
		doDamage{e};
	end
	if e.tick % 90 == 0 then
		calcRadiation(e);
	end
	if e.tick % 180 == 0 then
		doDecay(e);
	end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	toxicityValue = settings.global["toxicity-value"].value;
	radiationAreaSize = settings.global["radiation-area-size"].value;
	invRadiation = settings.global["radiation-in-player-inventory"].value;
  
	raduranore = settings.global["rad-uran-ore"].value;
	radfuelcell = settings.global["rad-fuel-cell"].value;
	radburntfuelcell = settings.global["rad-burnt-fuel-cell"].value;
	raduranium235 = settings.global["rad-uranium-235"].value;
	raduranium238 = settings.global["rad-uranium-238"].value;
	radcentrifuge = settings.global["rad-centrifuge"].value;
	radreactor = settings.global["rad-reactor"].value;  
end)

function set_hwz(player, hwz)
	if global.halbwertszeiten == nil then
		global.halbwertszeiten = {}
	end
	global.halbwertszeiten[player.name] = hwz;
end

function get_hwz(player)
	if global.halbwertszeiten == nil then
		global.halbwertszeiten = {}
	end
	result = global.halbwertszeiten[player.name];
	
	if result == nil then
		return 0;
	else
		return result;
	end
end

function set_exposed_radiation(player, exposed_radiation)
	if global.exposed_radiation == nil then
		global.exposed_radiation = {}
	end
	global.exposed_radiation[player.name] = exposed_radiation;
end

function get_exposed_radiation(player)
	if global.exposed_radiation == nil then
		global.exposed_radiation = {}
	end
	result = global.exposed_radiation[player.name];
	
	if result == nil then
		return 0;
	else
		return result;
	end
end
