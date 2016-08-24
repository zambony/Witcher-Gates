AddCSLuaFile();

TOOL.Category = "Travel"
TOOL.Name = "Witcher Gates"
TOOL.ClientConVar["key"] = "";
TOOL.ClientConVar["r"] = "167";
TOOL.ClientConVar["g"] = "100";
TOOL.ClientConVar["b"] = "30";
TOOL.ClientConVar["spawnenabled"] = "1";
TOOL.Information = {
	{name = "left", stage = 0},
	{name = "left_next", stage = 1, icon = "gui/lmb.png"}
};

cleanup.Register("portalpairs");

if (SERVER) then
	if (!ConVarExists("sbox_maxportalpairs")) then
		CreateConVar("sbox_maxportalpairs", 5, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum number of portal pairs which can be created by users.");
	end;
end;

/*
	Gate placing
*/

function TOOL:LeftClick(trace)
	if (IsValid(trace.Entity) and trace.Entity:IsPlayer()) then return false; end;
	if (CLIENT) then return true; end;
	if (!self:GetOwner():CheckLimit("portalpairs")) then return false; end;

	-- If we haven't selected a first point...
	if (self:GetStage() == 0) then
		-- Retrieve the physics object of any hit entity. Made useless by previous code, but /something/ needs to go into SetObject...
		-- As well, retrieve a modified version of the surface normal. This normal is always horizontal and only rotates around the Y axis. Yay straight ladders.
		local physObj = trace.Entity:GetPhysicsObjectNum(trace.PhysicsBone);

		-- Clear out any junk that could possibly be left over, and store our data.
		self:ClearObjects();
		self:SetObject(1, trace.Entity, trace.HitPos, physObj, trace.PhysicsBone, trace.HitNormal);

		if (trace.HitNormal.z == 1) then
			self.y1 = self:GetOwner():EyeAngles().y;
		end;

		-- Move to the next stage.
		self:SetStage(1);
	else
		-- Same as before, but create some nice variables for us to use.
		local physObj = trace.Entity:GetPhysicsObjectNum(trace.PhysicsBone);
		local color = Color(self:GetClientInfo("r"), self:GetClientInfo("g"), self:GetClientInfo("b"));
		local key = self:GetClientInfo("key");

		-- Store the data of our second click.
		self:SetObject(2, trace.Entity, trace.HitPos, physObj, trace.PhysicsBone, trace.HitNormal);

		local portal1 = ents.Create("witcher_door");
		local portal2 = ents.Create("witcher_door");

		local norm1 = self:GetNormal(1);
		local ang = norm1:Angle();

		if (self.y1) then
			ang.y = self.y1 + 180;
		end;

		ang:RotateAroundAxis(ang:Right(), -90);
		ang:RotateAroundAxis(ang:Up(), -90);
		portal1:SetPos(self:GetPos(1) + norm1 * 3);
		portal1:Spawn();
		portal1:SetAngles(ang);
		portal1:SetNotSolid(true);
		portal1:SetColour(color);
		portal1:SetOther(portal2);
		portal1.ToggleButton = numpad.OnDown(self:GetOwner(), tonumber(key), "PortalToggle", portal1);

		if (IsValid(self:GetEnt(1)) and self:GetEnt(1):GetClass() == "prop_physics") then
			portal1:SetParent(self:GetEnt(1));
		else
			portal1:PhysicsDestroy();
		end;

		local ang2 = self:GetNormal(2):Angle();

		if (trace.HitNormal.z == 1) then
			ang2.y = self:GetOwner():EyeAngles().y + 180;
		end;

		ang2:RotateAroundAxis(ang2:Right(), -90);
		ang2:RotateAroundAxis(ang2:Up(), -90);
		portal2:SetPos(self:GetPos(2) + self:GetNormal(2) * 3);
		portal2:Spawn();
		portal2:SetAngles(ang2);
		portal2:SetNotSolid(true);
		portal2:SetColour(color);
		portal2:SetOther(portal1);
		portal2.ToggleButton = numpad.OnDown(self:GetOwner(), tonumber(key), "PortalToggle", portal2);

		if (tobool(self:GetClientInfo("spawnenabled"))) then
			portal1:Enable();
			portal2:Enable();
		end;

		if (IsValid(self:GetEnt(2)) and self:GetEnt(2):GetClass() == "prop_physics") then
			portal2:SetParent(self:GetEnt(2));
		else
			portal2:PhysicsDestroy();
		end;

		undo.Create("Portal Pair");
			undo.AddEntity(portal1);
			undo.AddEntity(portal2);
			undo.SetPlayer(self:GetOwner());
			undo.SetCustomUndoText("Undone Portal Pair");
		undo.Finish();

		-- We've finished making our portals, so go back to stage 0, clear any objects, and add 1 to our cleanup count.
		self:SetStage(0);
		self:ClearObjects();

		self.y1 = nil;

		self:GetOwner():AddCount("portalpairs", portal1);
		self:GetOwner():AddCleanup("portalpairs", portal1);
		self:GetOwner():AddCleanup("portalpairs", portal2);
	end;

	return true;
end;

function TOOL:RightClick(trace)
end;

function TOOL:DrawHUD()
	local trace = self:GetOwner():GetEyeTrace();
	local ang = trace.HitNormal:Angle();
	local wallAng = trace.HitNormal:Angle();
	local isOnFloor = trace.HitNormal.z == 1;
	local eyeAng = Angle(0, self:GetOwner():EyeAngles().y, 0);

	if (isOnFloor) then
		ang.y = self:GetOwner():EyeAngles().y + 180;
	end;

	ang:RotateAroundAxis(ang:Right(), -90);
	ang:RotateAroundAxis(ang:Up(), -90);
	cam.Start3D()
	cam.Start3D2D(trace.HitPos + trace.HitNormal * 2 - (isOnFloor and (eyeAng:Right() * -23) or (wallAng:Right() * 23)) - (isOnFloor and eyeAng:Forward() or wallAng:Up()) * 47, ang, 1);
		surface.SetDrawColor(0, 255, 0, 30);
		surface.DrawRect(0, 0, 46, 92);
	cam.End3D2D();
	cam.End3D();
end;

function TOOL:Think()
end

/*
	Holster
	Clear stored objects and reset state
*/

function TOOL:Holster()
	self:ClearObjects();
	self:SetStage(0);
end;

/*
	Control Panel
*/

function TOOL.BuildCPanel(CPanel)
	CPanel:AddControl("Header", {
		Description = "#tool.witchergate.desc"
	});

	CPanel:AddControl("Numpad", {
		Label = "#tool.witchergate.key",
		Command = "witchergate_key"
	});

	CPanel:AddControl("Color", {
		Label = "#tool.witchergate.color",
		Red = "witchergate_r",
		Green = "witchergate_g",
		Blue = "witchergate_b"
	});

	CPanel:AddControl("CheckBox", {
		Label = "#tool.witchergate.spawnon",
		Command = "witchergate_spawnenabled"
	});
end;

/*
	Language strings
*/

if (CLIENT) then
	language.Add("tool.witchergate.name", "Witcher Gates");
	language.Add("tool.witchergate.left", "Select the spot for the first portal");
	language.Add("tool.witchergate.left_next", "Select the spot for the second portal");
	language.Add("tool.witchergate.desc", "Create linked pairs of portals to allow easy travel");
	language.Add("tool.witchergate.key", "Key to toggle the pair");
	language.Add("tool.witchergate.color", "Portal color");
	language.Add("tool.witchergate.spawnon", "Start On");

	language.Add("Cleaned_portalpairs", "Cleaned up all Portal Pairs");
	language.Add("Cleanup_portalpairs", "Portal Pairs");
end;