AddCSLuaFile();

function EFFECT:Init(fx)
	self.emitter = ParticleEmitter(fx:GetOrigin());
	self.ent = fx:GetEntity();
end;

function EFFECT:GetEntity()
	return IsValid(self.ent) and self.ent or false;
end;

function EFFECT:Think()
	if (self:GetEntity()) then
		if (self:GetEntity():GetEnabled()) then
			local curTime = CurTime();

			if ((self.nextParticle or 0) < curTime) then
				local ent = self:GetEntity();
				self.nextParticle = curTime + 0.1;

				local randPos = ent:GetPos() + (ent:GetUp() * math.random(7, 70)) + (ent:GetRight() * math.random(-47, 47)) + (ent:GetForward() * math.random(-24, 24));
				local normal = self:GetEntity():GetUp() * -1;
				local particle = self.emitter:Add("particle/particle_glow_05_addnofog", randPos);
				local color = (self:GetEntity():GetRealColor() / 2) * 255;
				particle:SetDieTime(1.2);
				particle:SetGravity(normal * 100);
				particle:SetVelocity(normal * 50);
				particle:SetColor(color.x, color.y, color.z);
				particle:SetAirResistance(100);
				particle:SetStartAlpha(255);
				particle:SetRoll(math.random(0, 360));
				particle:SetStartSize(math.random(1, 2));
				particle:SetEndSize(0);
				particle:SetVelocityScale(true);
				particle:SetLighting(false);
			end;
		end;

		return true;
	else
		self.emitter:Finish();
		return false;
	end;
end;

function EFFECT:Render()
end;