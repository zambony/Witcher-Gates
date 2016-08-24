AddCSLuaFile();

DEFINE_BASECLASS("base_entity");

ENT.Type			= "anim";
ENT.PrintName		= "Witcher Portal";
ENT.Category		= "Portals";
ENT.Spawnable		= false;
ENT.AdminOnly		= true;
ENT.Model			= Model("models/hunter/blocks/cube1x2x025.mdl");
ENT.RenderGroup 	= RENDERGROUP_BOTH;

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Enabled");
	self:NetworkVar("Vector", 0, "TempColor");
	self:NetworkVar("Vector", 1, "RealColor");
	self:NetworkVar("Entity", 0, "Other");
	self:NetworkVar("Float", 0, "AnimStart");

	if (SERVER) then
		self:NetworkVarNotify("TempColor", function(ent, name, old, new)
			local color = HSVToColor(new.x, new.y, new.z);
			local r = (color.r * 2) / 255;
			local g = (color.g * 2) / 255;
			local b = (color.b * 2) / 255;

			self:SetRealColor(Vector(r, g, b));
		end);
	end;
end;

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS;
end;

local function InFront(posA, posB, normal)
	local Vec1 = (posB - posA):GetNormalized();

	return (normal:Dot(Vec1) >= 0);
end;

if (SERVER) then

	function ENT:SpawnFunction(player, trace, class)
		if (!trace.Hit) then return; end;
		local entity = ents.Create(class);

		entity:SetPos(trace.HitPos + trace.HitNormal * 1.5);
		entity:Spawn();
		local ang = entity:GetAngles();
		ang:RotateAroundAxis(entity:GetForward(), -90)
		entity:SetAngles(ang);

		return entity;
	end;

	function ENT:Initialize()
		self:SetModel(self.Model);
		self:SetSolid(SOLID_VPHYSICS);
		self:PhysicsInit(SOLID_VPHYSICS);
		self:SetMaterial("vgui/black");
		self:DrawShadow(false);
		self:SetTrigger(true);
		self:SetEnabled(false);
		self:SetUseType(SIMPLE_USE);
		self:SetCollisionGroup(COLLISION_GROUP_WORLD);
		self:SetCustomCollisionCheck(true);

		local phys = self:GetPhysicsObject();

		if (IsValid(phys)) then
			phys:Wake();
		end;
	end;

	function ENT:Enable()
		if (self:GetEnabled()) then return; end;
		self:SetEnabled(true);
		self:EmitSound("Witcher.PortalOpen");

		if (!self.ambient) then
			local filter = RecipientFilter();
			filter:AddAllPlayers();

			self.ambient = CreateSound(self, "portal/portal_ambient.wav", filter);
		end;

		self.ambient:Play();

		self:SetAnimStart(CurTime());
	end;

	function ENT:Disable()
		if (!self:GetEnabled()) then return; end;
		self:SetEnabled(false);
		self:EmitSound("Witcher.PortalClose");

		if (self.ambient) then
			self.ambient:Stop();
		end;

		self:SetAnimStart(CurTime());
	end;

	function ENT:SetColour(color)
		local h, s, v = ColorToHSV(color);

		self:SetTempColor(Vector(h, s, v));

		if (IsValid(self:GetOther())) then
			self:GetOther():SetTempColor(Vector(h, s, v));
		end;
	end;

	function ENT:OnRemove()
		if (self.ambient) then
			self.ambient:Stop();
		end;
	end;

	function ENT:AcceptInput(input, activator, caller, data)
		local other = self:GetOther();
		if (input == "TurnOn") then
			self:Enable();

			if (IsValid(other)) then
				other:Enable();
			end;
		elseif (input == "TurnOff") then
			self:Disable();

			if (IsValid(other)) then
				other:Disable();
			end;
		elseif (input == "Toggle") then
			if (self:GetEnabled()) then
				self:Disable();

				if (IsValid(other)) then
					other:Disable();
				end;
			else
				self:Enable();

				if (IsValid(other)) then
					other:Enable();
				end;
			end;
		end;
	end;

	function ENT:KeyValue(key, value)
		if (key == "color") then
			local args = string.Explode(" ", value, false);
			self:SetColour(Color(args[1], args[2], args[3]));
		end;
	end;

	function ENT:TransformOffset(v, a1, a2)
		return (v:Dot(a1:Right()) * a2:Right() + v:Dot(a1:Up()) * (-a2:Up()) - v:Dot(a1:Forward()) * a2:Forward());
	end;

	function ENT:GetFloorOffset(pos1, height)
		local offset = Vector(0, 0, 0);
		local pos = Vector(0, 0, 0);
		pos:Set(pos1); --stupid pointers...
		pos = self:GetOther():WorldToLocal(pos);
		pos.y = pos.y + height;
		pos.z = pos.z + 10;

		for i = 0, 30 do
			local openspace = util.IsInWorld(self:GetOther():LocalToWorld(pos - Vector(0, i, 0)));
			--debugoverlay.Box(self:GetOther():LocalToWorld(pos - Vector(0, i, 0)), Vector(-2, -2, 0), Vector(2, 2, 2), 5)

			if (openspace) then
				offset.z = i;
				break;
			end;
		end;

		return offset;
	end;

	function ENT:GetOffsets(portal, ent)
		local pos;

		if (ent:IsPlayer()) then
			pos = ent:EyePos();
		else
			pos = ent:GetPos();
		end;

		local offset = self:WorldToLocal(pos);
		offset.x = -offset.x;
		offset.y = offset.y;
		local output = portal:LocalToWorld(offset);

		if (ent:IsPlayer() and SERVER) then
			return output + self:GetFloorOffset(output, (ent:EyePos() - ent:GetPos()).z);
		else
			return output;
		end;
	end;

	function ENT:GetPortalAngleOffsets(portal, ent)
		local angles = ent:GetAngles();
		local normal = self:GetUp();
		local forward = -angles:Forward();
		local up = angles:Up();
		-- reflect forward
		local dot = forward:Dot(normal);
		forward = forward + (-2 * dot) * normal;
		-- reflect up
		dot = up:Dot(normal);
		up = up + (-2 * dot) * normal;
		-- convert to angles
		angles = math.VectorAngles(forward, up);
		local LocalAngles = self:WorldToLocalAngles(angles);
		-- repair
		LocalAngles.x = -LocalAngles.x;
		LocalAngles.y = -LocalAngles.y;

		return portal:LocalToWorldAngles(LocalAngles);
	end;

	function ENT:StartTouch(ent)

	end;

	function ENT:Touch(ent)
		if (IsValid(self:GetOther()) and self:GetEnabled()) then
			if (InFront(ent:GetPos(), self:GetPos() - self:GetUp() * 2.8, self:GetUp())) then return; end;
			if (ent:IsPlayer()) then
				if (CurTime() < (ent.lastPort or 0) + 0.4) then return; end;

				local color = self:GetRealColor();
				local vel = ent:GetVelocity();
				local other = self:GetOther();

				local normVel = vel:GetNormalized();
				local dir = self:GetUp():Dot(normVel);

				-- If they aren't approaching the portal or they aren't moving fast enough, don't teleport.
				if (dir > 0 or (self:GetUp().z <= 0.5 and vel:Length() < 1)) then return; end;

				local newPos = self:GetOffsets(other, ent);
				local newVel = self:TransformOffset(vel, self:GetAngles(), other:GetAngles());
				local newAngles = self:GetPortalAngleOffsets(other, ent);
				newAngles.z = 0;

				-- Correct for if player is crouched
				newPos.z = newPos.z - (ent:EyePos() - ent:GetPos()).z;

				-- If the portal is slanted, account for it
				if (other:GetAngles().z > -60) then
					newPos = newPos + Angle(0, other:GetAngles().y + 90, 0):Forward() * 50;
				end;

				local offset = Vector();

				-- Correcting for eye height usually ends up getting us stuck in slanted portals. Find open space for us
				for i = 0, 20 do
					local openspace = util.IsInWorld(newPos + Vector(0, 0, i));

					if (openspace) then
						offset.z = i;
						break;
					end;
				end;

				newPos = newPos + offset + other:GetUp() * 3;

				local planeDist = DistanceToPlane(newPos, other:GetPos(), other:GetUp())
				if (planeDist <= 16) then
					newPos = newPos + other:GetUp() * planeDist;
				end;

				-- This trace allows 100% less getting stuck in things. It traces from the portal to the desired position using the player's hull.
				-- If it hits, it'll set you somewhere safe-ish most of the time.
				local up = other:GetUp();
				local nearestPoint = other:NearestPoint(newPos);
				local nearNormal = (newPos - nearestPoint):GetNormalized()
				local foundSpot = false;
				local trace;

				for i = 0, 30 do
					trace = util.TraceEntity({
						start = nearestPoint + up * (up.z > 0 and up.z * 30 or 16) + nearNormal * 5 + other:GetRight() * i,
						endpos = newPos + up + other:GetRight() * i,
						filter = function(traceEnt) if (traceEnt == other or (IsValid(other:GetParent()) and traceEnt == other:GetParent())) then return false; else return true; end end;
					}, ent);

					if (!trace.AllSolid) then
						foundSpot = true;
						break;
					end;
				end;
				// debugoverlay.Box(trace.HitPos, Vector(-16, -16, 0), Vector(16, 16, 72), 5, color_green);
				// debugoverlay.Box(trace.StartPos, Vector(-16, -16, 0), Vector(16, 16, 72), 5, color_black);
				// debugoverlay.Box(newPos, Vector(-16, -16, 0), Vector(16, 16, 72), 5, color_red);

				if (!foundSpot) then return; end;

				ent:SetPos(trace.HitPos + up * 2);
				ent:SetLocalVelocity(newVel);
				ent:SetEyeAngles(newAngles);
				ent.lastPort = CurTime();

				sound.Play("portal/portal_teleport.wav", self:WorldSpaceCenter());
				sound.Play("portal/portal_teleport.wav", other:WorldSpaceCenter());

				ent:ScreenFade(SCREENFADE.IN, color_black, 0.2, 0.03);
			else
				if (CurTime() < (ent.lastPort or 0) + 0.4) then return; end;

				if (ent:GetClass():find("door") or ent:GetClass():find("func_")) then return; end;
				if (!IsValid(ent:GetPhysicsObject())) then return; end;

				if (IsValid(self:GetParent())) then
					for k, v in pairs(constraint.GetAllConstrainedEntities(self:GetParent())) do
						if (v == ent) then
							return;
						end;
					end;
				end;

				local vel = ent:GetVelocity();
				local other = self:GetOther();

				local newPos = self:GetOffsets(other, ent);
				local newVel = self:TransformOffset(vel, self:GetAngles(), other:GetAngles());
				local newAngles = self:GetPortalAngleOffsets(other, ent);

				ent:SetPos(newPos);

				if (IsValid(ent:GetPhysicsObject())) then
					ent:GetPhysicsObject():SetVelocity(newVel);
				end;

				ent:SetAngles(newAngles);
				ent.lastPort = CurTime();

				sound.Play("portal/portal_teleport.wav", self:WorldSpaceCenter());
				sound.Play("portal/portal_teleport.wav", other:WorldSpaceCenter());
			end;
		end;
	end;

elseif (CLIENT) then

	local function DefineClipBuffer(ref)
		render.ClearStencil();
		render.SetStencilEnable(true);
		render.SetStencilCompareFunction(STENCIL_ALWAYS);
		render.SetStencilPassOperation(STENCIL_REPLACE);
		render.SetStencilFailOperation(STENCIL_KEEP);
		render.SetStencilZFailOperation(STENCIL_KEEP);
		render.SetStencilWriteMask(254);
		render.SetStencilTestMask(254);
		render.SetStencilReferenceValue(ref or 43);
	end;

	local function DrawToBuffer()
		render.SetStencilCompareFunction(STENCIL_EQUAL);
	end;

	local function EndClipBuffer()
		render.SetStencilEnable(false);
		render.ClearStencil();
	end;

	function ENT:Initialize()
		self.PixVis = util.GetPixelVisibleHandle();
		local matrix = Matrix();
		matrix:Scale(Vector(1, 1, 0.01));
		local offset = 1.8;

		local effectData = EffectData();
		effectData:SetEntity(self);
		effectData:SetOrigin(self:GetPos());
		util.Effect("portal_inhale", effectData);

		self:SetSolid(SOLID_VPHYSICS);

		self.hole = ClientsideModel("models/hunter/plates/plate1x2.mdl", RENDERGROUP_BOTH);
		self.hole:SetPos(self:GetPos() - self:GetUp() * (1 + offset));
		self.hole:SetAngles(self:GetAngles());
		self.hole:SetParent(self);
		self.hole:SetNoDraw(true);
		self.hole:EnableMatrix("RenderMultiply", matrix);

		self.top = ClientsideModel("models/hunter/plates/plate075x1.mdl", RENDERGROUP_BOTH);
		self.top:SetMaterial("portal/border");
		self.top:SetPos(self:GetPos() + self:GetRight() * 44.5 - self:GetUp() * (12.5 + offset));
		self.top:SetParent(self);
		self.top:SetLocalAngles(Angle(-75, -90, 0));
		self.top:SetNoDraw(true);
		self.top:EnableMatrix("RenderMultiply", matrix);

		self.bottom = ClientsideModel("models/hunter/plates/plate075x1.mdl", RENDERGROUP_BOTH);
		self.bottom:SetMaterial("portal/border");
		self.bottom:SetPos(self:GetPos() - self:GetRight() * 44.5 - self:GetUp() * (12.5 + offset));
		self.bottom:SetParent(self);
		self.bottom:SetLocalAngles(Angle(-75, 90, 0));
		self.bottom:SetNoDraw(true);
		self.bottom:EnableMatrix("RenderMultiply", matrix);

		self.left = ClientsideModel("models/hunter/plates/plate075x2.mdl", RENDERGROUP_BOTH);
		self.left:SetMaterial("portal/border");
		self.left:SetPos(self:GetPos() + self:GetForward() * 20.8 - self:GetUp() * (12.5 + offset));
		self.left:SetParent(self);
		self.left:SetLocalAngles(Angle(-75, 0, 0));
		self.left:SetNoDraw(true);
		self.left:EnableMatrix("RenderMultiply", matrix);

		self.right = ClientsideModel("models/hunter/plates/plate075x2.mdl", RENDERGROUP_BOTH);
		self.right:SetMaterial("portal/border");
		self.right:SetPos(self:GetPos() - self:GetForward() * 20.8 - self:GetUp() * (12.5 + offset));
		self.right:SetParent(self);
		self.right:SetLocalAngles(Angle(-105, 0, 0));
		self.right:SetNoDraw(true);
		self.right:EnableMatrix("RenderMultiply", matrix);

		self.back = ClientsideModel("models/hunter/plates/plate3x3.mdl", RENDERGROUP_BOTH);
		self.back:SetMaterial("vgui/black");
		self.back:SetPos(self:GetPos() - self:GetUp() * 42);
		self.back:SetParent(self);
		self.back:SetLocalAngles(angle_zero);
		self.back:SetNoDraw(true);

		self.h, self.s, self.l = 0, 1, 1;
	end;

	function ENT:OnRemove()
		self.top:Remove();
		self.bottom:Remove();
		self.left:Remove();
		self.right:Remove();
		self.hole:Remove();
		self.back:Remove();
	end;

	function ENT:Draw()

	end;

	function ENT:Think()
		if (self:GetEnabled()) then
			local light = DynamicLight(self:EntIndex());

			if (light) then
				local vecCol = self:GetRealColor();
				light.pos = self:WorldSpaceCenter() + self:GetUp() * 15;
				light.Size = 300;
				light.style = 5;
				light.Decay = 600;
				light.brightness = 1;
				light.r = (vecCol.x / 2) * 255;
				light.g = (vecCol.y / 2) * 255;
				light.b = (vecCol.z / 2) * 255;
				light.DieTime = CurTime() + 0.1;
			end;
		end;

		if (!IsValid(self.hole)) then
			self.hole = ClientsideModel("models/hunter/plates/plate1x2.mdl", RENDERGROUP_BOTH);
			self.hole:SetPos(self:GetPos() - self:GetUp() * (1 + offset));
			self.hole:SetAngles(self:GetAngles());
			self.hole:SetParent(self);
			self.hole:SetNoDraw(true);
			self.hole:EnableMatrix("RenderMultiply", matrix);
		end;

		if (!IsValid(self.top)) then
			self.top = ClientsideModel("models/hunter/plates/plate075x1.mdl", RENDERGROUP_BOTH);
			self.top:SetMaterial("portal/border");
			self.top:SetPos(self:GetPos() + self:GetRight() * 44.5 - self:GetUp() * (12.5 + offset));
			self.top:SetParent(self);
			self.top:SetLocalAngles(Angle(-75, -90, 0));
			self.top:SetNoDraw(true);
			self.top:EnableMatrix("RenderMultiply", matrix);
		end;

		if (!IsValid(self.bottom)) then
			self.bottom = ClientsideModel("models/hunter/plates/plate075x1.mdl", RENDERGROUP_BOTH);
			self.bottom:SetMaterial("portal/border");
			self.bottom:SetPos(self:GetPos() - self:GetRight() * 44.5 - self:GetUp() * (12.5 + offset));
			self.bottom:SetParent(self);
			self.bottom:SetLocalAngles(Angle(-75, 90, 0));
			self.bottom:SetNoDraw(true);
			self.bottom:EnableMatrix("RenderMultiply", matrix);
		end;

		if (!IsValid(self.left)) then
			self.left = ClientsideModel("models/hunter/plates/plate075x2.mdl", RENDERGROUP_BOTH);
			self.left:SetMaterial("portal/border");
			self.left:SetPos(self:GetPos() + self:GetForward() * 20.8 - self:GetUp() * (12.5 + offset));
			self.left:SetParent(self);
			self.left:SetLocalAngles(Angle(-75, 0, 0));
			self.left:SetNoDraw(true);
			self.left:EnableMatrix("RenderMultiply", matrix);
		end;

		if (!IsValid(self.right)) then
			self.right = ClientsideModel("models/hunter/plates/plate075x2.mdl", RENDERGROUP_BOTH);
			self.right:SetMaterial("portal/border");
			self.right:SetPos(self:GetPos() - self:GetForward() * 20.8 - self:GetUp() * (12.5 + offset));
			self.right:SetParent(self);
			self.right:SetLocalAngles(Angle(-105, 0, 0));
			self.right:SetNoDraw(true);
			self.right:EnableMatrix("RenderMultiply", matrix);
		end;

		if (!IsValid(self.back)) then
			self.back = ClientsideModel("models/hunter/plates/plate3x3.mdl", RENDERGROUP_BOTH);
			self.back:SetMaterial("vgui/black");
			self.back:SetPos(self:GetPos() - self:GetUp() * 42);
			self.back:SetParent(self);
			self.back:SetLocalAngles(angle_zero);
			self.back:SetNoDraw(true);
		end;

		self.top:SetParent(self);
		self.bottom:SetParent(self);
		self.left:SetParent(self);
		self.right:SetParent(self);
		self.hole:SetParent(self);
		self.back:SetParent(self);
	end;

	local mat = CreateMaterial("witcherGlow", "UnlitGeneric", {
		["$basetexture"] = "sprites/light_glow02",
		["$basetexturetransform"] = "center 0 0 scale 1 1 rotate 0 translate 0 0",
		["$additive"] = 1,
		["$translucent"] = 1,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$ignorez"] = 1
	});

	function ENT:DrawTranslucent()
		if (InFront(LocalPlayer():EyePos(), self:GetPos() - self:GetUp() * 1.8, self:GetUp())) then return; end;

		local bEnabled = self:GetEnabled();
		local color = self:GetRealColor();
		local elapsed = CurTime() - self:GetAnimStart();
		local frac = math.Clamp(elapsed / (bEnabled and 0.5 or 0.1), 0, 1);

		if (frac <= 1) then
			self.h, self.s, self.l = ColorToHSL((color.x / 2) * 255, (color.y / 2) * 255, (color.z / 2) * 255);
			self.l = Lerp(frac, self.l or 1, bEnabled and 0 or 1);
			self.col = HSLToColor(self.h, self.s, self.l);
		end;

		if (bEnabled) then
			self.lerpr = Lerp(frac, self.lerpr or 255, self.col.r);
			self.lerpg = Lerp(frac, self.lerpg or 255, self.col.g);
			self.lerpb = Lerp(frac, self.lerpb or 255, self.col.b);
		else
			self.lerpr = Lerp(frac, self.lerpr or 0, self.col.r);
			self.lerpg = Lerp(frac, self.lerpg or 0, self.col.g);
			self.lerpb = Lerp(frac, self.lerpb or 0, self.col.b);
		end;

		self.top:SetNoDraw(true);

		DefineClipBuffer();

		if ((bEnabled and frac > 0) or (!bEnabled and frac < 1)) then
			self.hole:DrawModel();
		end;

		DrawToBuffer();

		render.ClearBuffersObeyStencil(self.lerpr, self.lerpg, self.lerpb, 0, bEnabled);

		if (bEnabled and frac >= 0.1) then
			if (frac >= 1) then
				self.back:DrawModel();
			end;
			render.SetColorModulation(color.x * 3, color.y * 3, color.z * 3);
			self.top:DrawModel();
			self.bottom:DrawModel();
			self.left:DrawModel();
			self.right:DrawModel();
			render.SetColorModulation(1, 1, 1);
		end;

		EndClipBuffer();

		if (!bEnabled) then return; end;

		local norm = self:GetUp();
		local viewNorm = (self:GetPos() - EyePos()):GetNormalized();
		local dot = viewNorm:Dot(norm * -1);

		if (dot >= 0) then
			render.SetColorModulation(1, 1, 1);
			local visible = util.PixelVisible(self:GetPos() + self:GetUp() * 3, 20, self.PixVis);

			if (!visible) then return; end;

			local alpha = math.Clamp((EyePos():Distance(self:GetPos()) / 10) * dot * visible, 0, 30);
			local newColor = Color((color.x / 2) * 255, (color.y / 2) * 255, (color.z / 2) * 255, alpha);

			render.SetMaterial(mat);
			render.DrawSprite(self:GetPos() + self:GetUp() * 2, 600, 600, newColor, visible * dot);
		end;
	end;
end;