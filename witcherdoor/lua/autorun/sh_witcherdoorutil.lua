if (SERVER) then
	AddCSLuaFile();
	resource.AddWorkshop("727161410");
end;

sound.Add({
	name = "Witcher.Teleport",
	channel = CHAN_STREAM,
	volume = 1,
	level = 75,
	pitch = {100, 110},
	sound = "portal/portal_teleport.wav"
});

sound.Add({
	name = "Witcher.PortalOpen",
	channel = CHAN_STREAM,
	volume = 1,
	level = 80,
	pitch = {95, 105},
	sound = "portal/portal_open.wav"
});

sound.Add({
	name = "Witcher.PortalClose",
	channel = CHAN_STREAM,
	volume = 1,
	level = 80,
	pitch = {95, 105},
	sound = "portal/portal_dissipate.wav"
});

local clamp = math.Clamp;
local abs = math.abs;
local min, max = math.min, math.max;

function HSLToColor(H, S, L)
	H = clamp(H, 0, 360);
	S = clamp(S, 0, 1);
	L = clamp(L, 0, 1);
	local C = (1 - abs(2 * L - 1)) * S;
	local X = C * (1 - abs((H / 60) % 2 - 1));
	local m = L - C / 2;
	local R1, G1, B1 = 0, 0, 0;

	if H < 60 or H >= 360 then
		R1, G1, B1 = C, X, 0;
	elseif H < 120 then
		R1, G1, B1 = X, C, 0;
	elseif H < 180 then
		R1, G1, B1 = 0, C, X;
	elseif H < 240 then
		R1, G1, B1 = 0, X, C;
	elseif H < 300 then
		R1, G1, B1 = X, 0, C;
	else
		R1, G1, B1 = C, 0, X; -- H < 360
	end

	return Color((R1 + m) * 255, (G1 + m) * 255, (B1 + m) * 255);
end

function ColorToHSL(R, G, B)
	if type(R) == "table" then
		R, G, B = clamp(R.r, 0, 255) / 255, clamp(R.g, 0, 255) / 255, clamp(R.b, 0, 255) / 255;
	else
		R, G, B = R / 255, G / 255, B / 255;
	end

	local max, min = max(R, G, B), min(R, G, B);
	local del = max - min;
	-- Hue
	local H = 0;

	if del <= 0 then
		H = 0;
	elseif max == R then
		H = 60 * (((G - B) / del) % 6);
	elseif max == G then
		H = 60 * (((B - R) / del + 2) % 6);
	else
		H = 60 * (((R - G) / del + 4) % 6);
	end

	-- Lightness
	local L = (max + min) / 2;
	-- Saturation
	local S = 0;

	if del != 0 then
		S = del / (1 - abs(2 * L - 1));
	end

	return H, S, L;
end

function DistanceToPlane(object_pos, plane_pos, plane_forward)
	local vec = object_pos - plane_pos;
	plane_forward:Normalize();

	return plane_forward:Dot(vec);
end;

function math.VectorAngles(forward, up)
	local angles = Angle(0, 0, 0);
	local left = up:Cross(forward);
	left:Normalize();
	local xydist = math.sqrt(forward.x * forward.x + forward.y * forward.y);

	if (xydist > 0.001) then
		angles.y = math.deg(math.atan2(forward.y, forward.x));
		angles.p = math.deg(math.atan2(-forward.z, xydist));
		angles.r = math.deg(math.atan2(left.z, (left.y * forward.x) - (left.x * forward.y)));
	else
		angles.y = math.deg(math.atan2(-left.x, left.y));
		angles.p = math.deg(math.atan2(-forward.z, xydist));
		angles.r = 0;
	end;

	return angles;
end;

properties.Add("portal_persist", {
	MenuLabel = "Save Portal",
	MenuIcon = "icon16/disk.png",
	Order = 1,

	Filter = function(self, ent, player)
		if (!IsValid(ent)) then return false; end;
		if (!player:IsSuperAdmin()) then return false; end;
		if (ent:GetClass() != "witcher_gateway") then return false; end;
		if (SERVER and !IsValid(ent:GetOther())) then player:ChatPrint("This portal does not have an exit!"); return false; end;

		return true;
	end,

	Action = function(self, ent)

	end,

	SetPersist = function(self, ent, mode)
		self:MsgStart();
		net.WriteEntity(ent);
		net.WriteUInt(mode or 0, 8);
		self:MsgEnd();
	end,

	Receive = function(self, length, player)
		local ent = net.ReadEntity();

		if (!self:Filter(ent, player)) then return; end;

		local mode = net.ReadUInt(8);

		ent:SetNWInt("SaveMode", mode);
		ent:GetOther():SetNWInt("SaveMode", mode);

		if (mode == 1) then
			ent:Enable();
			ent:GetOther():Enable();
			ent:SetKeyValue("DisallowUse", "1");
			ent:GetOther():SetKeyValue("DisallowUse", "1");
		elseif (mode == 3) then
			ent:SetKeyValue("DisallowUse", "1");
			ent:GetOther():SetKeyValue("DisallowUse", "1");
		else
			ent:SetKeyValue("DisallowUse", "0");
			ent:GetOther():SetKeyValue("DisallowUse", "0");
		end;
	end,

	MenuOpen = function(self, option, ent, trace)
		local subMenu = option:AddSubMenu();

		local option = subMenu:AddOption("None", function()
			self:SetPersist(ent, 0);
		end);

		option:SetChecked(ent:GetNWInt("SaveMode", 0) == 0);

		option = subMenu:AddOption("Always On", function()
			self:SetPersist(ent, 1);
		end);

		option:SetChecked(ent:GetNWInt("SaveMode", 0) == 1);

		option = subMenu:AddOption("Toggleable", function()
			self:SetPersist(ent, 2);
		end);

		option:SetChecked(ent:GetNWInt("SaveMode", 0) == 2);

		option = subMenu:AddOption("Toggleable (Admin Only)", function()
			self:SetPersist(ent, 3);
		end);

		option:SetChecked(ent:GetNWInt("SaveMode", 0) == 3);
	end,
});

if (SERVER) then
	numpad.Register("PortalToggle", function(player, portal)
		if (!IsValid(portal)) then return false; end;
		if (portal:GetEnabled()) then
			portal:Disable();
		else
			portal:Enable();
		end;
	end);

	local function SavePortals()
		local buffer = {};

		for k, v in pairs(ents.FindByClass("witcher_gateway")) do
			if (IsValid(v) and v:GetNWInt("SaveMode", 0) >= 1 and !v.saved) then
				if (!IsValid(v:GetOther())) then continue; end;

				local other = v:GetOther();

				if (!IsValid(other)) then continue; end;

				buffer[#buffer + 1] = {
					portals = {
						[1] = {
							origin = v:GetPos(),
							angles = v:GetAngles()
						},

						[2] = {
							origin = other:GetPos(),
							angles = other:GetAngles()
						}
					},

					color = v:GetColor(),
					DisallowUse = v.DisallowUse or false,
					mode = v:GetNWInt("SaveMode", 0),
					enabled = v:GetEnabled()
				};

				v.saved = true;
				other.saved = true;
			end;
		end;

		if (buffer and table.Count(buffer) > 0) then
			local JSON = util.TableToJSON(buffer);
			file.CreateDir("witchergates");
			file.Write("witchergates/" .. game.GetMap() .. ".txt", JSON);
		else
			file.Delete("witchergates/" .. game.GetMap() .. ".txt");
		end;

		for k, v in pairs(ents.FindByClass("witcher_gateway")) do
			if (v.saved) then
				v.saved = nil;
			end;
		end;
	end;

	local function LoadPortals()
		if (!file.Exists("witchergates/" .. game.GetMap() .. ".txt", "DATA")) then return; end;
		local buffer = file.Read("witchergates/" .. game.GetMap() .. ".txt", "DATA");

		if (buffer and buffer:len() > 1) then
			local portals = util.JSONToTable(buffer);

			if (portals) then
				for k, info in pairs(portals) do
					local firstInfo = info.portals[1];
					local secondInfo = info.portals[2];
					local bDisallowUse = info.DisallowUse and "1" or "0";
					local portal1 = ents.Create("witcher_gateway");
					local portal2 = ents.Create("witcher_gateway");

					portal1:SetPos(firstInfo.origin);
					portal1:SetAngles(firstInfo.angles);
					portal1:SetColor(info.color);
					portal1:Spawn();
					portal1:SetNWInt("SaveMode", info.mode);
					portal1:SetKeyValue("DisallowUse", bDisallowUse);
					portal1:PhysicsDestroy();

					portal2:SetPos(secondInfo.origin);
					portal2:SetAngles(secondInfo.angles);
					portal2:SetColor(info.color);
					portal2:Spawn();
					portal2:SetNWInt("SaveMode", info.mode);
					portal2:SetKeyValue("DisallowUse", bDisallowUse);
					portal2:PhysicsDestroy();

					portal1:SetOther(portal2);
					portal2:SetOther(portal1);

					if (info.mode == 1 or info.enabled) then
						portal1:Enable();
						portal2:Enable();
					end;
				end;
			end;
		end;
	end;

	timer.Create("witcher_SavePortals", 180, 0, function()
		local win, msg = pcall(SavePortals);

		if (!win) then
			ErrorNoHalt("[WITCHERGATES] Something went wrong when saving portals!\n" .. msg);
		end;
	end);

	hook.Add("ShutDown", "witcher_SavePortals", function()
		local win, msg = pcall(SavePortals);

		if (!win) then
			ErrorNoHalt("[WITCHERGATES] Something went wrong when saving portals!\n" .. msg);
		end;
	end);

	hook.Add("InitPostEntity", "witcher_LoadPortals", function()
		timer.Simple(5, function()
			local win, msg = pcall(LoadPortals);

			if (!win) then
				ErrorNoHalt("[WITCHERGATES] Something went wrong when loading portals!\n" .. msg);
			end;
		end);
	end);

	hook.Add("ShouldCollide", "witcher_RPGFix", function(a, b)
		local aClass = a:GetClass();
		local bClass = b:GetClass();
		if (aClass == "rpg_missile" and (bClass == "witcher_door" or bClass == "witcher_gateway")) then
			return false;
		elseif (bClass == "rpg_missile" and (aClass == "witcher_door" or aClass == "witcher_gateway")) then
			return false;
		end;
	end);
end;