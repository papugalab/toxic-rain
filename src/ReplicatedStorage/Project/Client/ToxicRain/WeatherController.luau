--!strict
local Lighting=game:GetService("Lighting")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Controller={} Controller.__index=Controller
function Controller.new(ui:any,workspace:Workspace,ordinarySound:any,playersModule:any) return setmetatable({_ui=ui,_workspace=workspace,_sound=ordinarySound,_players=playersModule},Controller) end
function Controller.ShouldPlayThunder(previous:string,current:string):boolean
	return (current=="Warning" and previous~="Warning") or (current=="ToxicRain" and previous~="ToxicRain")
end

function Controller.ResolveVisualState(active:boolean,weather:any,playerZ:number?,frontZ:number?):string
	if not active or playerZ==nil then return "Inactive" end
	-- Being overtaken is more urgent than the rain warning or rain itself.
	if frontZ~=nil and playerZ<=frontZ then return "Storm" end
	if weather=="ToxicRain" then return "Rain" end
	if weather=="Warning" then return "Warning" end
	if frontZ~=nil and playerZ-frontZ<=60 then return "Approaching" end
	return "Clear"
end

function Controller:Initialize()
	local player=self._players:GetLocalPlayer() local host=self._ui:GetHudHost() local random=Random.new()
	local isMobile=UserInputService.TouchEnabled
	local warning=Instance.new("TextLabel") warning.Name="ToxicRainWarningBanner" warning.AnchorPoint=Vector2.zero warning.Position=UDim2.fromOffset(16,4) warning.Size=UDim2.new(0.42,0,0,44) warning.BackgroundColor3=Color3.fromRGB(25,8,5) warning.BackgroundTransparency=0.12 warning.TextColor3=Color3.fromRGB(255,210,70) warning.TextStrokeTransparency=0.2 warning.Font=Enum.Font.GothamBlack warning.TextScaled=true warning.TextWrapped=false warning.Text="⚠ УКРОЙТЕСЬ! ТОКСИЧНЫЙ ДОЖДЬ" warning.Visible=false warning.ZIndex=12 warning.Parent=host
	local warningSizeConstraint=Instance.new("UISizeConstraint") warningSizeConstraint.MinSize=Vector2.new(220,44) warningSizeConstraint.MaxSize=Vector2.new(300,44) warningSizeConstraint.Parent=warning
	local warningTextConstraint=Instance.new("UITextSizeConstraint") warningTextConstraint.MinTextSize=12 warningTextConstraint.MaxTextSize=22 warningTextConstraint.Parent=warning
	warning.TextWrapped=true
	if not isMobile then
		warningSizeConstraint:Destroy() warningTextConstraint:Destroy()
		warning.AnchorPoint=Vector2.new(0.5,1) warning.Position=UDim2.new(0.5,0,1,-90) warning.Size=UDim2.fromOffset(560,72) warning.TextScaled=false warning.TextWrapped=true warning.TextSize=30
	end
	local flashParent:Instance=host
	if isMobile then
		local overlayGui=Instance.new("ScreenGui")
		overlayGui.Name="ToxicRainWeatherOverlay"
		overlayGui.ResetOnSpawn=false
		overlayGui.ScreenInsets=Enum.ScreenInsets.None
		overlayGui.ClipToDeviceSafeArea=false
		overlayGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
		overlayGui.DisplayOrder=-10
		overlayGui.Parent=player:WaitForChild("PlayerGui")
		flashParent=overlayGui
	end
	local rainTint=Instance.new("Frame") rainTint.Name="ToxicRainFullscreenTint" rainTint.Size=UDim2.fromScale(1,1) rainTint.BackgroundColor3=Color3.fromRGB(70,190,80) rainTint.BackgroundTransparency=1 rainTint.BorderSizePixel=0 rainTint.ZIndex=0 rainTint.Parent=flashParent
	local flash=Instance.new("Frame") flash.Name="ToxicRainLightningFlash" flash.Size=UDim2.fromScale(1,1) flash.BackgroundColor3=Color3.fromRGB(225,255,210) flash.BackgroundTransparency=1 flash.BorderSizePixel=0 flash.ZIndex=20 flash.Parent=flashParent
	local grade=Instance.new("ColorCorrectionEffect") grade.Name="ToxicRainWeatherGrade" grade.Parent=Lighting
	local folder=Instance.new("Folder") folder.Name="ToxicRainLocalRain" folder.Parent=self._workspace local drops={}
	for index=1,44 do local drop=Instance.new("Part") drop.Name=`Drop_{index}` drop.Anchored=true drop.CanCollide=false drop.CanTouch=false drop.CanQuery=false drop.CastShadow=false drop.Material=Enum.Material.Neon drop.Color=Color3.fromRGB(105,255,120) drop.Size=Vector3.new(0.08,random:NextNumber(2.5,5.5),0.08) drop.Transparency=1 drop.Parent=folder table.insert(drops,{Part=drop,Offset=Vector3.new(random:NextNumber(-24,24),random:NextNumber(2,28),random:NextNumber(-20,20))}) end
	local previous="Clear" local lastWinnerUserId:number?=nil local fountainSoundClock=0
	local function lightning()
		flash.BackgroundTransparency=0.08
		TweenService:Create(flash,TweenInfo.new(0.18),{BackgroundTransparency=1}):Play()
		if not isMobile then
			grade.Brightness=0.45
			TweenService:Create(grade,TweenInfo.new(0.35),{Brightness=-0.08}):Play()
		end
		self._sound:PlayLocal({CueId="ToxicRain.SFX.Thunder"})
	end
	local function update()
		local weather=self._workspace:GetAttribute("ToxicRainWeather") or "Clear"
		local winnerUserId=self._workspace:GetAttribute("ToxicRainWinnerUserId")
		if Controller.ShouldPlayThunder(previous,weather) then lightning() end
		if typeof(winnerUserId)=="number" and winnerUserId==player.UserId and winnerUserId~=lastWinnerUserId then self._sound:PlayLocal({CueId="ToxicRain.SFX.Victory"}) end
		lastWinnerUserId=if typeof(winnerUserId)=="number" then winnerUserId else nil
		previous=weather
	end
	self._workspace:GetAttributeChangedSignal("ToxicRainWeather"):Connect(update)
	self._workspace:GetAttributeChangedSignal("ToxicRainWinnerUserId"):Connect(update)
	RunService.RenderStepped:Connect(function(dt)
		local weather=self._workspace:GetAttribute("ToxicRainWeather")
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local frontZ=self._workspace:GetAttribute("ToxicRainFrontZ")
		local active=self._workspace:GetAttribute("ToxicRainRoundState")=="Running"
			and player:GetAttribute("ToxicRainQueueMode")=="Running" and player:GetAttribute("ToxicRainResult")==nil
		local visual=Controller.ResolveVisualState(active,weather,
			if root and root:IsA("BasePart") then root.Position.Z else nil,
			if typeof(frontZ)=="number" then frontZ else nil)
		local insideFront=visual=="Storm"
		local dangerVisual=visual=="Rain" or insideFront
		local caution=visual=="Warning" or visual=="Approaching"
		warning.Visible=insideFront or caution
		warning.Text=if insideFront then "☢ ТЫ ВНУТРИ БУРИ!\nТЕРЯЕШЬ ЗДОРОВЬЕ — БЕГИ К ФИНИШУ!"
			elseif visual=="Approaching" then "⚠ БУРЯ ДОГОНЯЕТ" else "⚠ УКРОЙТЕСЬ! ТОКСИЧНЫЙ ДОЖДЬ"
		warning.BackgroundColor3=if insideFront then Color3.fromRGB(7,43,19) else Color3.fromRGB(25,8,5)
		warning.TextColor3=if insideFront then Color3.fromRGB(210,255,190) else Color3.fromRGB(255,210,70)
		warning.TextScaled=isMobile or insideFront
		warning.TextTransparency=if insideFront then 0 elseif warning.Visible then 0.08+math.abs(math.sin(os.clock()*5))*0.34 else 0
		-- A real screen tint on desktop as well as touch devices, not just dimmer
		-- world lighting. Keep it behind the HUD so health and controls stay legible.
		rainTint.BackgroundColor3=if insideFront then Color3.fromRGB(12,94,35)
			elseif visual=="Warning" then Color3.fromRGB(255,210,150) else Color3.fromRGB(70,190,80)
		rainTint.BackgroundTransparency=if insideFront then 0.45 elseif visual=="Rain" then (if isMobile then 0.65 else 0.84)
			elseif caution then (if isMobile then 0.9 else 1) else 1
		if isMobile then
			grade.TintColor=Color3.new(1,1,1) grade.Contrast=0 grade.Saturation=0 grade.Brightness=0
		elseif insideFront then
			grade.TintColor=Color3.fromRGB(110,205,120) grade.Contrast=0.12 grade.Saturation=0.05 grade.Brightness=-0.02
		elseif dangerVisual then
			grade.TintColor=Color3.fromRGB(125,210,120) grade.Contrast=0.2 grade.Saturation=-0.2 grade.Brightness=-0.08
		elseif caution then
			grade.TintColor=Color3.fromRGB(220,235,165) grade.Contrast=0.08 grade.Saturation=-0.08 grade.Brightness=0
		else
			grade.TintColor=Color3.new(1,1,1) grade.Contrast=0 grade.Saturation=0 grade.Brightness=0
		end
		for _,record in drops do
			local part=record.Part::BasePart
			if dangerVisual and root and root:IsA("BasePart") then
				record.Offset-=Vector3.new(0,dt*54,0)
				if record.Offset.Y < -3 then record.Offset=Vector3.new(random:NextNumber(-24,24),random:NextNumber(20,30),random:NextNumber(-20,20)) end
				part.CFrame=CFrame.new(root.Position+record.Offset)*CFrame.Angles(0,0,math.rad(-9)) part.Transparency=0.2
			else part.Transparency=1 end
		end
		fountainSoundClock+=dt
		if fountainSoundClock>=1.2 and root and root:IsA("BasePart") then
			fountainSoundClock=0
			local map=self._workspace:FindFirstChild("ToxicRainMap")
			local hazards=map and map:FindFirstChild("RuntimeToxicHazards")
			if hazards then
				for _,model in hazards:GetChildren() do
					local pool=model:IsA("Model") and model:FindFirstChild("WarningPool") or nil
					local state=model:GetAttribute("ToxicRainFountainState")
					if pool and pool:IsA("BasePart") and state~="Idle" and (pool.Position-root.Position).Magnitude<=28 then
						self._sound:PlayLocal({CueId="Template.SFX.CartoonBubble"})
						break
					end
				end
			end
		end
	end)
	update()
end
return Controller
