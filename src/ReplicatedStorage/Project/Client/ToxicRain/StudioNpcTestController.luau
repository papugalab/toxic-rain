--!strict

local Protocol = require(game.ReplicatedStorage.Shared.ToxicRain.StudioNpcTestProtocol)
local Controller = {}
Controller.__index = Controller

function Controller.new(dependencies: any): any
 return setmetatable({
  _players=dependencies.PlayersModule, _ui=dependencies.UI,
  _workspace=dependencies.Workspace, _communication=dependencies.Communication,
  _initialized=false, _view=nil,
 }, Controller)
end

function Controller:Request(action: string): boolean
 local player=self._players:GetLocalPlayer()
 if player:GetAttribute("ToxicRainAdminTestAllowed")~=true then return false end
 return self._communication:Queue(Protocol.Intent,{Action=action})==true
end

function Controller:_createView()
 if self._view then return end
 local player=self._players:GetLocalPlayer()
 if player:GetAttribute("ToxicRainAdminTestAllowed")~=true then return end
 local workspace=self._workspace
local gui=Instance.new("Frame") gui.Name="StudioNpcAdminPanel" gui.Size=UDim2.fromScale(1,1) gui.BackgroundTransparency=1 gui.ZIndex=40 gui.Parent=self._ui:GetHudHost() self._view=gui
local panel=Instance.new("Frame") panel.Size=UDim2.fromOffset(640,270) panel.Position=UDim2.new(.5,-320,0,10) panel.BackgroundColor3=Color3.fromRGB(12,23,18) panel.BackgroundTransparency=.09 panel.ZIndex=50 panel.Visible=false panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,12)
local panelScale=Instance.new("UIScale") panelScale.Parent=panel
local toggle=Instance.new("TextButton") toggle.Name="AdminToggle" toggle.Size=UDim2.fromOffset(145,36) toggle.Position=UDim2.new(1,-157,1,-48) toggle.ZIndex=60 toggle.Text="Админ ▸" toggle.Font=Enum.Font.GothamBold toggle.TextSize=15 toggle.TextColor3=Color3.new(1,1,1) toggle.BackgroundColor3=Color3.fromRGB(35,58,48) toggle.Parent=gui
Instance.new("UICorner",toggle).CornerRadius=UDim.new(0,8)
toggle.Activated:Connect(function() panel.Visible=not panel.Visible toggle.Text=panel.Visible and "Админ ▾" or "Админ ▸" end)
local function label(y,height,size,text)
 local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-24,0,height) l.Position=UDim2.fromOffset(12,y) l.BackgroundTransparency=1 l.Font=Enum.Font.GothamMedium l.TextSize=size l.TextColor3=Color3.fromRGB(232,248,238) l.TextXAlignment=Enum.TextXAlignment.Left l.Text=text l.ZIndex=60 l.Parent=panel return l
end
label(9,26,18,"АДМИН · ТЕСТ НА 3 NPC")
local status=label(38,24,16,"Нажми «Запустить»")
local rows={}
for i=1,3 do rows[i]=label(67+(i-1)*34,32,14,"") end
local event=label(169,24,13,"Дождь · лужи · укрытия · толчки · яблоки")
local focus=0
local function button(text,x,width,callback)
 local b=Instance.new("TextButton") b.Size=UDim2.fromOffset(width,28) b.Position=UDim2.fromOffset(x,198) b.BackgroundColor3=Color3.fromRGB(42,85,63) b.TextColor3=Color3.new(1,1,1) b.Font=Enum.Font.GothamBold b.TextSize=13 b.Text=text b.ZIndex=60 b.Parent=panel Instance.new("UICorner",b).CornerRadius=UDim.new(0,6) b.Activated:Connect(callback) return b
end
button("Тест: 3 NPC / повторить",12,196,function() self:Request("Start") end)
local exit=button("Выйти из теста",12,196,function()self:Request("Stop")end) exit.Position=UDim2.fromOffset(12,233)
button("Все",221,64,function() focus=0 end)
for i=1,3 do button("NPC "..i,299+(i-1)*96,84,function()focus=i end) end
local rain=Instance.new("Frame") rain.Name="VisibleTestRain" rain.Size=UDim2.fromScale(1,1) rain.BackgroundTransparency=1 rain.ZIndex=0 rain.Parent=gui
local streaks={}
for i=1,55 do
 local f=Instance.new("Frame") f.Size=UDim2.fromOffset(1,math.random(28,65)) f.Rotation=13 f.BackgroundColor3=Color3.fromRGB(130,255,127) f.BackgroundTransparency=.55 f.BorderSizePixel=0 f.Parent=rain
 table.insert(streaks,{Frame=f,X=math.random(),Y=math.random()})
end
local previousCamera=nil
local connection
connection=game:GetService("RunService").RenderStepped:Connect(function(dt)
 if not gui.Parent then connection:Disconnect() return end
 panelScale.Scale=math.clamp((gui.AbsoluteSize.X-20)/640,.5,1)
 panel.Position=UDim2.new(.5,-320*panelScale.Scale,0,10)
 local folder=workspace:FindFirstChild("StudioNpcFullTest")
 local active=workspace:GetAttribute("ToxicRainStudioNpcTestActive")==true
 if not active then
  rain.Visible=false
  status.Text=player:GetAttribute("ToxicRainAdminTestMessage") or "Нажми «Тест: 3 NPC»"
  if status.Text=="" then status.Text="Нажми «Тест: 3 NPC»" end
  for i=1,3 do rows[i].Text="NPC "..i.." · ожидает запуска" end
  event.Text="Тесты доступны только тебе в Studio"
  if previousCamera then
   local camera=workspace.CurrentCamera camera.CameraType=previousCamera.Type camera.CFrame=previousCamera.CFrame previousCamera=nil
  end
  return
 end
 if not folder then return end
 if not previousCamera then local camera=workspace.CurrentCamera previousCamera={Type=camera.CameraType,CFrame=camera.CFrame} end
 local weather=workspace:GetAttribute("ToxicRainWeather")
 local state=folder:GetAttribute("State")
 status.Text=(state=="Completed" and "Завершён" or state=="Ready" and "Готов к запуску" or string.format("%.1f c",folder:GetAttribute("Elapsed") or 0)).."  |  "..(weather=="Warning" and "ВНИМАНИЕ: ДОЖДЬ ЧЕРЕЗ " or weather=="ToxicRain" and "ТОКСИЧНЫЙ ДОЖДЬ " or "Ясно ")..tostring(workspace:GetAttribute("ToxicRainWeatherTimer") or "").."  |  "..tostring(workspace:GetAttribute("ToxicRainStartCountdown") or "")
 status.TextColor3=weather=="Warning" and Color3.fromRGB(255,207,87) or weather=="ToxicRain" and Color3.fromRGB(95,255,130) or Color3.new(1,1,1)
 local points={}
 for i=1,3 do
  local m=folder:FindFirstChild("NPC"..i)
  if m then
   local hp=m:GetAttribute("ToxicRainXP") or 100
   local time=m:GetAttribute("ToxicRainFinishTime")
   rows[i].Text=string.format("%d · %d HP (мин. %d) · %s%s\nТолчки %d / защита %d · яблоки %d / съел %d",i,hp,m:GetAttribute("MinHP") or 100,m:GetAttribute("TestAction") or "",time and time>=0 and string.format(" · %.2f c",time) or "",m:GetAttribute("Hits") or 0,m:GetAttribute("Blocked") or 0,m:GetAttribute("Picked") or 0,m:GetAttribute("Eaten") or 0)
   rows[i].TextColor3=hp<=35 and Color3.fromRGB(255,130,130) or Color3.fromRGB(230,245,235)
   local root=m:FindFirstChild("HumanoidRootPart")
   if root and (focus==0 or focus==i) and (focus~=0 or state~="Completed" or m:GetAttribute("ToxicRainResult")~="Lost") then table.insert(points,root.Position) end
  else rows[i].Text="NPC "..i.." · ожидает запуска" end
 end
 event.Text=folder:GetAttribute("LastEvent") or ""
 rain.Visible=weather=="ToxicRain" and state=="Running"
 if rain.Visible then for _,s in streaks do s.Y=(s.Y+dt*.95)%1 s.Frame.Position=UDim2.fromScale(s.X,s.Y) end end
 if #points>0 then
  local center=Vector3.zero for _,p in points do center+=p end center/=#points
  local span=0 for _,p in points do span=math.max(span,(p-center).Magnitude) end
  local camera=workspace.CurrentCamera camera.CameraType=Enum.CameraType.Scriptable
  local height=math.clamp(24+span*.8,28,80)
  local target=CFrame.lookAt(center+Vector3.new(35,height,-42-span*.6),center+Vector3.new(0,4,0))
  camera.CFrame=camera.CFrame:Lerp(target,math.min(1,dt*5))
 end
end)
self._renderConnection=connection

end

function Controller:Initialize()
 if self._initialized then return end
 self._initialized=true
 local player=self._players:GetLocalPlayer()
 player:GetAttributeChangedSignal("ToxicRainAdminTestAllowed"):Connect(function()self:_createView()end)
 self:_createView()
end

return Controller
