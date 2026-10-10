--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PodiumPresentation = require(script.Parent.PodiumPresentation)

local Controller = {} Controller.__index = Controller
function Controller.new(ui: any, workspace: Workspace, playersModule: any) return setmetatable({_ui=ui,_workspace=workspace,_playersModule=playersModule},Controller) end

function Controller:Initialize()
	local player=self._playersModule:GetLocalPlayer()
	local host=self._ui:GetHudHost()
	local podium=PodiumPresentation.new(self._ui,self._workspace,self._playersModule)
	podium:Initialize()
	local isMobile=UserInputService.TouchEnabled
	task.spawn(function()
		local map=self._workspace:WaitForChild("ToxicRainMap",10)
		local lobby=map and map:WaitForChild("Lobby",10)
		if not lobby then return end
		local billboards = {} :: { BillboardGui }
		for _,definition in {{pad="SoloPad",text="SOLO • СТАРТ"},{pad="GroupPad",text="GROUP 2–16"}} do
			local pad=lobby:WaitForChild(definition.pad,10)
			local billboard=pad and pad:WaitForChild("QueueLabel",10)
			if billboard and billboard:IsA("BillboardGui") then
				table.insert(billboards,billboard)
				billboard.Size=if isMobile then UDim2.fromOffset(52,13) else UDim2.fromOffset(130,45)
				billboard.StudsOffset=if isMobile then Vector3.new(0,3.5,0) else Vector3.new(0,5,0)
				billboard.MaxDistance=if isMobile then 45 else 60
				billboard.AlwaysOnTop=false
				local textLabel=billboard:FindFirstChildOfClass("TextLabel")
				if textLabel then
					textLabel.Text=definition.text
				end
				if textLabel and isMobile then
					textLabel.TextWrapped=false textLabel.BackgroundTransparency=0.38
					local textConstraint=textLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
					textConstraint.MinTextSize=4 textConstraint.MaxTextSize=8 textConstraint.Parent=textLabel
				end
			end
		end
		local function updateLobbyLabelVisibility()
			local state=self._workspace:GetAttribute("ToxicRainRoundState") or "Waiting"
			local visible=state=="Waiting" or state=="Countdown"
			for _,billboard in billboards do billboard.Enabled=visible end
		end
		self._workspace:GetAttributeChangedSignal("ToxicRainRoundState"):Connect(updateLobbyLabelVisibility)
		updateLobbyLabelVisibility()
	end)
	local rain=Instance.new("Frame") rain.Name="ToxicRainStreaks" rain.Size=UDim2.fromScale(1,1) rain.BackgroundTransparency=1 rain.Visible=false rain.Parent=host
	local winner=Instance.new("TextLabel") winner.Name="ToxicRainWinnerEffect" winner.AnchorPoint=Vector2.new(0.5,0.5) winner.Size=UDim2.new(1,-40,0,64) winner.Position=UDim2.fromScale(0.5,0.5) winner.BackgroundColor3=Color3.fromRGB(90,70,8) winner.BackgroundTransparency=0.18 winner.TextColor3=Color3.fromRGB(255,255,190) winner.TextStrokeTransparency=0.15 winner.Font=Enum.Font.GothamBlack winner.TextScaled=true winner.TextWrapped=true winner.Visible=false winner.ZIndex=8 winner.Parent=host
	local winnerSizeConstraint=Instance.new("UISizeConstraint") winnerSizeConstraint.MaxSize=Vector2.new(520,64) winnerSizeConstraint.Parent=winner
	local winnerTextConstraint=Instance.new("UITextSizeConstraint") winnerTextConstraint.MinTextSize=16 winnerTextConstraint.MaxTextSize=30 winnerTextConstraint.Parent=winner
	winner.Position=UDim2.fromScale(0.5,0.22)
	-- The countdown stays low on screen while the camera shows the starting group.
	local cinematic=Instance.new("Frame") cinematic.Name="ToxicRainStartCutscene" cinematic.Size=UDim2.fromScale(1,1) cinematic.BackgroundTransparency=1 cinematic.Visible=false cinematic.ZIndex=12 cinematic.Parent=host
	local topBar=Instance.new("Frame") topBar.Name="TopBar" topBar.AnchorPoint=Vector2.new(0.5,0.5) topBar.Position=UDim2.fromScale(0.5,0.82) topBar.Size=if isMobile then UDim2.new(0.9,0,0,70) else UDim2.new(0.92,0,0,88) topBar.BackgroundColor3=Color3.new(0,0,0) topBar.BackgroundTransparency=0.08 topBar.BorderSizePixel=0 topBar.ZIndex=12 topBar.Parent=cinematic
	local topBarCorner=Instance.new("UICorner") topBarCorner.CornerRadius=UDim.new(0,12) topBarCorner.Parent=topBar
	local startLabel=Instance.new("TextLabel") startLabel.Name="StartCountdown" startLabel.AnchorPoint=Vector2.new(0.5,0.5) startLabel.Position=UDim2.fromScale(0.5,0.5) startLabel.Size=UDim2.new(0.7,0,1,-8) startLabel.BackgroundTransparency=1 startLabel.TextColor3=Color3.fromRGB(210,255,105) startLabel.TextStrokeColor3=Color3.new(0,0,0) startLabel.TextStrokeTransparency=0.08 startLabel.Font=Enum.Font.GothamBlack startLabel.TextScaled=true startLabel.ZIndex=13 startLabel.Parent=topBar
	local startTextConstraint=Instance.new("UITextSizeConstraint") startTextConstraint.MinTextSize=28 startTextConstraint.MaxTextSize=72 startTextConstraint.Parent=startLabel
	local streaks={}
	for index=1,28 do local line=Instance.new("Frame") line.Size=UDim2.fromOffset(3,50+index%4*12) line.Position=UDim2.fromScale((index*0.137)%1,(index*0.271)%1) line.Rotation=12 line.BackgroundColor3=Color3.fromRGB(115,255,130) line.BackgroundTransparency=0.25 line.BorderSizePixel=0 line.Parent=rain table.insert(streaks,line) end
	local spectating=false
	local cutsceneActive=false
	local cutscenePlayed=false
	local cutsceneToken=0
	local cameraRestoreToken=0
	local cameraHandoffActive=false
	local function getBehindCameraFrame(root: BasePart): (CFrame, CFrame)
		local focusPosition=root.Position+Vector3.new(0,2,0)
		local cameraPosition=focusPosition-root.CFrame.LookVector*12+Vector3.new(0,4,0)
		return CFrame.lookAt(cameraPosition,focusPosition),CFrame.new(focusPosition)
	end
	local function restorePlayerCamera(snapBehind: boolean?)
		local camera=self._workspace.CurrentCamera
		local character=self._playersModule:GetCharacter()
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local root=character and character:FindFirstChild("HumanoidRootPart")
		if camera and humanoid then
			cameraRestoreToken+=1
			local restoreToken=cameraRestoreToken
			camera.CameraSubject=humanoid
			if snapBehind and root and root:IsA("BasePart") then
				cameraHandoffActive=true
				local behindFrame,focusFrame=getBehindCameraFrame(root)
				camera.CameraType=Enum.CameraType.Scriptable
				camera.CFrame=behindFrame
				camera.Focus=focusFrame
				-- Follow clears the orbit angle retained by Roblox from the side
				-- cutscene. One frame later Custom receives the camera from behind.
				task.spawn(function()
					RunService.RenderStepped:Wait()
					if restoreToken~=cameraRestoreToken then return end
					if self._workspace.CurrentCamera~=camera or not humanoid.Parent or not root.Parent then cameraHandoffActive=false return end
					local followBehindFrame,followFocusFrame=getBehindCameraFrame(root)
					camera.CameraSubject=humanoid
					camera.CameraType=Enum.CameraType.Follow
					camera.CFrame=followBehindFrame
					camera.Focus=followFocusFrame
					RunService.RenderStepped:Wait()
					if restoreToken~=cameraRestoreToken then return end
					if self._workspace.CurrentCamera~=camera or not humanoid.Parent or not root.Parent then cameraHandoffActive=false return end
					local finalBehindFrame,finalFocusFrame=getBehindCameraFrame(root)
					camera.CameraType=Enum.CameraType.Custom
					camera.CFrame=finalBehindFrame
					camera.Focus=finalFocusFrame
					cameraHandoffActive=false
				end)
			else
				cameraHandoffActive=false
				camera.CameraType=Enum.CameraType.Custom
			end
		end
	end
	local function cancelCutscene()
		cutsceneToken+=1
		cutsceneActive=false
		cinematic.Visible=false
		restorePlayerCamera(true)
	end
	local function playStartCutscene()
		if cutsceneActive then return end
		local camera=self._workspace.CurrentCamera
		local character=self._playersModule:GetCharacter()
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local root=character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not humanoid or not root or not root:IsA("BasePart") then return end
		cutsceneToken+=1
		local token=cutsceneToken
		cutsceneActive=true
		cameraRestoreToken+=1
		cameraHandoffActive=false
		startLabel.Text="СТАРТ  3"
		cinematic.Visible=true
		camera.CameraSubject=humanoid
		camera.CameraType=Enum.CameraType.Scriptable
		local startedAt=os.clock()
		task.spawn(function()
			while token==cutsceneToken do
				local elapsed=os.clock()-startedAt
				if elapsed>=4 or self._workspace:GetAttribute("ToxicRainRoundState")~="Running" or self._workspace:GetAttribute("ToxicRainStartLocked")~=true or player:GetAttribute("ToxicRainQueueMode")~="Running" then break end
				RunService.RenderStepped:Wait()
				local groupCenter=Vector3.zero
				local groupCount=0
				local maximumSpread=0
				for _,candidate in Players:GetPlayers() do
					if candidate:GetAttribute("ToxicRainQueueMode")=="Running" then
						local candidateRoot=candidate.Character and candidate.Character:FindFirstChild("HumanoidRootPart")
						if candidateRoot and candidateRoot:IsA("BasePart") then
							groupCenter+=candidateRoot.Position
							groupCount+=1
						end
					end
				end
				if groupCount>0 then groupCenter/=groupCount else groupCenter=root.Position end
				for _,candidate in Players:GetPlayers() do
					if candidate:GetAttribute("ToxicRainQueueMode")=="Running" then
						local candidateRoot=candidate.Character and candidate.Character:FindFirstChild("HumanoidRootPart")
						if candidateRoot and candidateRoot:IsA("BasePart") then maximumSpread=math.max(maximumSpread,(candidateRoot.Position-groupCenter).Magnitude) end
					end
				end
				local flatForward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
				if flatForward.Magnitude<0.01 then flatForward=Vector3.new(0,0,1) else flatForward=flatForward.Unit end
				local side=Vector3.new(flatForward.Z,0,-flatForward.X)
				local progress=math.clamp(elapsed/3.4,0,1)
				local eased=progress*progress*(3-2*progress)
				local framing=math.max(0,maximumSpread-5)
				local sideDistance=(28+framing)-(10+framing*0.35)*eased
				local backDistance=20-8*eased
				local height=16-7*eased
				local focusPosition=groupCenter+flatForward*6+Vector3.new(0,2.5,0)
				local cameraPosition=groupCenter+side*sideDistance-flatForward*backDistance+Vector3.new(0,height,0)
				camera.CFrame=CFrame.lookAt(cameraPosition,focusPosition)
				camera.Focus=CFrame.new(focusPosition)
				local remaining=self._workspace:GetAttribute("ToxicRainStartCountdown")
				startLabel.Text=if remaining==3 then "СТАРТ  3" elseif remaining==2 then "СТАРТ  2" elseif remaining==1 then "СТАРТ  1" else "ВПЕРЁД!"
			end
			if token~=cutsceneToken then return end
			cutsceneActive=false
			cinematic.Visible=false
			if player:GetAttribute("ToxicRainResult")~="Lost" then restorePlayerCamera(true) end
		end)
	end
	local function bind(character:Model)
		local humanoid=character:WaitForChild("Humanoid")::Humanoid
		local root=character:WaitForChild("HumanoidRootPart",5)
		spectating=false
		local camera=self._workspace.CurrentCamera
		if camera then camera.CameraSubject=humanoid end
		if root and root:IsA("BasePart") and (self._workspace:GetAttribute("ToxicRainRoundState") or "Waiting")~="Running" then
			root.CFrame=CFrame.lookAt(root.Position,root.Position+Vector3.new(0,0,1))
			if camera then
				camera.CameraType=Enum.CameraType.Scriptable
				camera.CFrame=CFrame.lookAt(root.Position+Vector3.new(0,5,-12),root.Position+Vector3.new(0,2,14))
				task.delay(0.15,function()
					if self._workspace.CurrentCamera==camera and humanoid.Parent then
						camera.CameraSubject=humanoid
						camera.CameraType=Enum.CameraType.Custom
					end
				end)
			end
		end
		humanoid.Died:Connect(function() spectating=true end)
	end
	local currentCharacter=self._playersModule:GetCharacter()
	if currentCharacter then task.spawn(bind,currentCharacter) end
	self._playersModule.CharacterAdded:Connect(bind)
	self._playersModule.CharacterRemoving:Connect(function()
		cameraRestoreToken+=1
		cameraHandoffActive=false
		if cutsceneActive then cancelCutscene() end
	end)
	local function updateCutsceneState()
		local state=self._workspace:GetAttribute("ToxicRainRoundState") or "Waiting"
		if state~="Running" then
			cutscenePlayed=false
			if cutsceneActive then cancelCutscene() end
		elseif self._workspace:GetAttribute("ToxicRainStartLocked")~=true then
			if cutsceneActive then cancelCutscene() elseif player:GetAttribute("ToxicRainResult")==nil then restorePlayerCamera(true) end
		elseif player:GetAttribute("ToxicRainQueueMode")=="Running" and not cutscenePlayed then
			cutscenePlayed=true
			playStartCutscene()
		end
	end
	self._workspace:GetAttributeChangedSignal("ToxicRainRoundState"):Connect(updateCutsceneState)
	self._workspace:GetAttributeChangedSignal("ToxicRainStartLocked"):Connect(updateCutsceneState)
	player:GetAttributeChangedSignal("ToxicRainQueueMode"):Connect(updateCutsceneState)
	local function update()
		rain.Visible=false
		local winnerName=self._workspace:GetAttribute("ToxicRainWinnerName") winner.Visible=typeof(winnerName)=="string" and not podium:OwnsCamera() winner.Text=if typeof(winnerName)=="string" then `ПОБЕДИТЕЛЬ: {winnerName}!` else ""
	end
	for _,name in {"ToxicRainActivePlayers","ToxicRainStartedPlayers","ToxicRainWeather","ToxicRainWinnerName"} do self._workspace:GetAttributeChangedSignal(name):Connect(update) end
	RunService.RenderStepped:Connect(function(dt)
		local hadPodiumCamera=podium._cameraOwned
		if podium:OwnsCamera() then cameraRestoreToken+=1 cameraHandoffActive=false end
		podium:Update(dt)
		if podium:OwnsCamera() then winner.Visible=false end
		if hadPodiumCamera and not podium:OwnsCamera() then restorePlayerCamera(true) end
		if rain.Visible then for index,line in streaks do local y=line.Position.Y.Scale+dt*(1.4+index%5*0.12) line.Position=UDim2.fromScale(line.Position.X.Scale,y%1.12-0.08) end end
		local map=self._workspace:FindFirstChild("ToxicRainMap") local decoration=map and map:FindFirstChild("Decoration")
		if decoration then for _,arrow in decoration:GetChildren() do if arrow:IsA("Model") and string.sub(arrow.Name,1,10)=="RoadArrow_" then local phase=arrow:GetAttribute("AnimationPhase") or 0 local glow=((os.clock()*1.8+phase)%1)<0.42 for _,part in arrow:GetChildren() do if part:IsA("BasePart") then part.Transparency=if glow then 0 else 0.72 end end end end end
		local state=self._workspace:GetAttribute("ToxicRainRoundState") or "Waiting"
		local isActiveGameplay=state=="Running" and self._workspace:GetAttribute("ToxicRainStartLocked")~=true and player:GetAttribute("ToxicRainQueueMode")=="Running" and player:GetAttribute("ToxicRainResult")==nil
		if isActiveGameplay then
			local camera=self._workspace.CurrentCamera
			local character=self._playersModule:GetCharacter()
			local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			if camera and humanoid and not cameraHandoffActive and (camera.CameraType~=Enum.CameraType.Custom or camera.CameraSubject~=humanoid) then
				restorePlayerCamera()
			end
		elseif not cutsceneActive and not podium:OwnsCamera() and (spectating or player:GetAttribute("ToxicRainResult")=="Lost") then
			local winnerId=self._workspace:GetAttribute("ToxicRainWinnerUserId") local target:Player?=if typeof(winnerId)=="number" then Players:GetPlayerByUserId(winnerId) else nil
			if not target then for _,candidate in Players:GetPlayers() do local humanoid=candidate.Character and candidate.Character:FindFirstChildOfClass("Humanoid") if candidate~=player and humanoid and humanoid.Health>0 and candidate:GetAttribute("ToxicRainResult")~="Lost" then target=candidate break end end end
			local humanoid=target and target.Character and target.Character:FindFirstChildOfClass("Humanoid") if humanoid and self._workspace.CurrentCamera then self._workspace.CurrentCamera.CameraSubject=humanoid end
		end
	end)
	updateCutsceneState()
	update()
end
return Controller
