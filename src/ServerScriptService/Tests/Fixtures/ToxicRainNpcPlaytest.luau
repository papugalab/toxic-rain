--!strict

-- Manually launched Studio fixture. Uses the current game runtimes without changing damage rules.
local Signal = require(game.ReplicatedStorage.Shared.Util.Signal)
local Fixture = {}

function Fixture.Create(dependencies: any): any
local workspace=dependencies.Workspace
local RR=dependencies.RoundFactory
local CR=dependencies.CombatFactory
local RS=game:GetService("RunService")
local Physics=game:GetService("PhysicsService")
pcall(function() Physics:RegisterCollisionGroup("StudioDemoNPCs") end)
Physics:CollisionGroupSetCollidable("StudioDemoNPCs","StudioDemoNPCs",false)
local observer=dependencies.Observer
local ch=observer.Character
assert(ch and ch:FindFirstChild("HumanoidRootPart"),"AdminCharacterNotReady")
local old=ch.Archivable ch.Archivable=true
local template=ch:Clone() ch.Archivable=old
for _,d in template:GetDescendants() do
 if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("Backpack") then d:Destroy()
 elseif d:IsA("BasePart") then d.Anchored=false d.CollisionGroup="StudioDemoNPCs" end
end
local folder=Instance.new("Folder") folder.Name="StudioNpcFullTest" folder.Parent=workspace
local ctx: any={Records={},Round=nil,Combat=nil,Connection=nil,Events={},Signals={}}

local names={"Осторожный","Толкач","Рискованный"}
local colors={Color3.fromRGB(75,200,255),Color3.fromRGB(255,177,68),Color3.fromRGB(224,105,255)}
local function log(text)
 local elapsed=ctx.Round and ctx.Round._runStartedAt>0 and os.clock()-ctx.Round._runStartedAt or 0
 table.insert(ctx.Events,{Time=math.round(elapsed*10)/10,Text=text})
 folder:SetAttribute("LastEvent",text)
 if #ctx.Events>250 then table.remove(ctx.Events,1) end
 print("[NPC full test]",math.round(elapsed*10)/10,text)
end
local function stopRun()
 if ctx.Connection then ctx.Connection:Disconnect() ctx.Connection=nil end
 local r=ctx.Round
 if r then r._generation+=1 if r._heartbeat then r._heartbeat:Disconnect() end
  r:_releaseStartLock() r:_clearRoundObjects()
  for _,c in r._lobbyConnections do c:Disconnect() end
 end
 local c=ctx.Combat
 if c then c:_releaseAll() for _,v in c._connections do v:Disconnect() end
 for _,v in c._deathConnections do v:Disconnect() end
 if c._runtimeFolder then c._runtimeFolder:Destroy() end end
 for _,s in ctx.Signals do s:Destroy() end table.clear(ctx.Signals)
 for _,v in ctx.Records do v.Track:Stop() v.Player.Character:Destroy() end
 table.clear(ctx.Records)
end
ctx.Stop=function() stopRun() folder:Destroy() template:Destroy() end
local function signal()
 local b=Signal.new()
 table.insert(ctx.Signals,b)
 return b
end
local comm={RegisterHandler=function() end}
local function start()
 stopRun() table.clear(ctx.Events)
 folder:SetAttribute("State","Countdown")
 local list={}
 for i=1,3 do
  local model=template:Clone() model.Name="NPC"..i model.Parent=folder
  local hum=model:FindFirstChildOfClass("Humanoid")
  hum.Health=100 hum.DisplayName=i.." · "..names[i] hum.BreakJointsOnDeath=false
  local root=model.HumanoidRootPart root.Anchored=false root:SetNetworkOwner(nil)
  local backpack=Instance.new("Backpack") backpack.Parent=model
  local rec: any={Index=i,MinHP=100,Damage=0,RainDamage=0,PuddleDamage=0,FrontDamage=0,DeathDamage=0,Picked=0,Eaten=0,Hits=0,Blocked=0,Grips=0}
  local p: any={UserId=-2000-i,Name="NPC"..i,DisplayName=names[i],Character=model,Parent=folder}
  function p:GetAttribute(k) return self.Character:GetAttribute(k) end
  function p:SetAttribute(k,v)
   local before=self.Character:GetAttribute(k)
   self.Character:SetAttribute(k,v)
   if k=="ToxicRainXP" and type(v)=="number" then
    rec.MinHP=math.min(rec.MinHP,v) model:SetAttribute("MinHP",rec.MinHP)
    if type(before)=="number" and v<before then
     local damage=before-v rec.Damage+=damage
     local hazard=self:GetAttribute("ToxicRainHazard")
     local kind=hum.Health<=0 and "Death" or hazard=="Puddle" and "Puddle" or hazard=="Front" and "Front" or "Rain"
     rec[kind.."Damage"]+=damage
     model:SetAttribute(kind.."Damage",rec[kind.."Damage"])
     log(names[i]..": "..before.." → "..v.." HP ("..kind..")")
    end
   elseif k=="ToxicRainAppleCount" and type(before)=="number" and type(v)=="number" then
    if v>before then rec.Picked+=v-before log(names[i]..": подобрал яблоко") model:SetAttribute("Picked",rec.Picked)
    elseif v<before then rec.Eaten+=before-v log(names[i]..": съел яблоко, здоровье "..tostring(self:GetAttribute("ToxicRainXP"))) model:SetAttribute("Eaten",rec.Eaten) end
   elseif k=="ToxicRainPushOutcome" then
    if v=="Hit" then rec.Hits+=1 model:SetAttribute("Hits",rec.Hits)
    elseif v=="Blocked" then rec.Blocked+=1 model:SetAttribute("Blocked",rec.Blocked) end
    log(names[i]..": толчок "..tostring(v))
   elseif k=="ToxicRainGripSlot" and v and v~=before then rec.Grips+=1 model:SetAttribute("Grips",rec.Grips) log(names[i]..": держится за укрытие")
   elseif k=="ToxicRainResult" and v then log(names[i]..": "..tostring(v)) end
  end
  function p:FindFirstChildOfClass(k) return k=="Backpack" and backpack or nil end
  function p:LoadCharacter() end
  rec.Player=p rec.Hum=hum rec.Root=root
  local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
  local anim=Instance.new("Animation") anim.AnimationId="rbxassetid://913376220"
  rec.Track=animator:LoadAnimation(anim) rec.Track.Looped=true rec.Track.Priority=Enum.AnimationPriority.Movement
  local label=Instance.new("BillboardGui") label.Name="TestLabel" label.Size=UDim2.fromOffset(230,66) label.StudsOffset=Vector3.new(0,3.9,0) label.AlwaysOnTop=true label.Parent=root
  local text=Instance.new("TextLabel") text.Name="Text" text.Size=UDim2.fromScale(1,1) text.BackgroundColor3=Color3.fromRGB(15,22,18) text.BackgroundTransparency=.15 text.TextColor3=colors[i] text.TextSize=15 text.Font=Enum.Font.GothamBold text.Parent=label
  rec.Label=text
  table.insert(list,p) table.insert(ctx.Records,rec)
 end
 local adapter: any={CharacterAdded=signal(),CharacterRemoving=signal(),PlayerRemoving=signal()}
 function adapter:GetPlayers() return list end
 function adapter:GetPlayerByUserId(id) for _,p in list do if p.UserId==id then return p end end end
 function adapter:GetPlayerFromCharacter(model) for _,p in list do if p.Character==model then return p end end end
 function adapter:ObservePlayers(added) for _,p in list do added(p) end return function()end end
 local r=RR.new(adapter,workspace,comm) ctx.Round=r
 r:Initialize()
 r._scheduleRestart=function(self)
  if self._restartScheduled then return end
  self._restartScheduled=true self._generation+=1
  folder:SetAttribute("State","Completed") log("Раунд завершён")
 end
 local combat=CR.new({PlayersModule=adapter,Communication=comm,Workspace=workspace}) ctx.Combat=combat combat:Initialize()
 local stops=combat._stops
 local first=stops[1].Zone
 local second=stops[2].Zone
 local weak
 for _,d in workspace.ToxicRainMap.Shelters:GetDescendants() do
  if d:IsA("BasePart") and d:GetAttribute("ProtectionClass")=="Weak" and math.abs(d.Position.Z-340)<15 then weak=d break end
 end
 local function inside(zone,pos,margin)
  local v=zone.CFrame:PointToObjectSpace(pos)
  return math.abs(v.X)<=zone.Size.X/2+(margin or 0) and math.abs(v.Z)<=zone.Size.Z/2+(margin or 0)
 end
 local function safeGoal(rec,goal)
  local pos=rec.Root.Position
  if pos.Z>=675 then
 if math.abs(pos.X+8.785)>10 then return Vector3.new(-8.785,pos.Y,math.max(690,math.min(700,pos.Z))) end
 return Vector3.new(-8.785,pos.Y,724)
 end
 if pos.Z<235 or (goal-pos).Magnitude<10 then return goal end
  local best=goal local score=math.huge
  for x=-49,46,5 do
   local target=Vector3.new(x,pos.Y,math.min(goal.Z,pos.Z+11))
   local cost=math.abs(x-goal.X)*.12+math.abs(x-pos.X)*.25
   for _,zone in r._puddleZones do
    if inside(zone,target,2) then cost+=120 end
    local mid=pos:Lerp(target,.5)
    if inside(zone,mid,1.5) then cost+=120 end
   end
   if cost<score then score=cost best=target end
  end
  return best
 end
 ctx.Connection=RS.Heartbeat:Connect(function()
  local snap=r._round:GetSnapshot()
  local t=os.clock()-r._runStartedAt
  if r._runStartedAt>0 and t>120 and snap.state=="Running" then
   for _,rec in ctx.Records do r:EliminatePlayer(rec.Player,true) end
   log("Тайм-аут теста: участники не завершили маршрут")
  end
  local running=snap.state=="Running" and not r._startLocked and r._runStartedAt>0
  if running then folder:SetAttribute("State","Running") folder:SetAttribute("Elapsed",t) end
  for _,rec in ctx.Records do
   local p=rec.Player local root=rec.Root local hum=rec.Hum local i=rec.Index
   if not root.Parent then p:SetAttribute("TestAction",p:GetAttribute("ToxicRainResult")=="Lost" and "Погиб" or "Финиш") continue end
   local hp=p:GetAttribute("ToxicRainXP") or 100
   local action="Ждёт старт"
   if running and snap.results[p.UserId]=="Active" and hum.Health>0 then
    local pos=root.Position
    local goal
    if t<23 then
     goal=Vector3.new(first.Position.X+(i==1 and -3 or i==2 and 2 or 4),pos.Y,first.Position.Z+(i-2)*3)
     action="К укрытию"
     if i==3 and t<13.6 then goal=Vector3.new(first.Position.X+12,pos.Y,first.Position.Z-5) action="Поздно прячется" end
    elseif t<41 then
     local z=i==3 and weak or second
     goal=Vector3.new(z.Position.X+(i==3 and -6 or i==1 and -3 or 2),pos.Y,z.Position.Z+(i==2 and 3 or -2))
     action=i==3 and "Под деревом: слабая защита" or "К следующему укрытию"
    else
     goal=Vector3.new(-8.785,pos.Y,724) action="К финишу, обходит лужи"
     if i==2 and t<44 then
      local near local distance=math.huge
      for _,zone in r._puddleZones do
       local d=(zone.Position-pos).Magnitude
       if d<distance then near=zone distance=d end
      end
      if near and distance<28 then goal=Vector3.new(near.Position.X,pos.Y,near.Position.Z) action="Рискует: попал в лужу" end
     else goal=safeGoal(rec,goal) end
    end
    if (p:GetAttribute("ToxicRainAppleCount") or 0)>0 and hp<=79 then
     if r:ConsumeApple(p) then rec.EatingUntil=os.clock()+1 end
    end
    local apple
    if (p:GetAttribute("ToxicRainAppleCount") or 0)==0 then
     local dist=math.huge
     for _,a in workspace.ToxicRainMap.AppleSpawnPoints:GetDescendants() do
      if a:IsA("BasePart") and a.Transparency<.5 and not a:GetAttribute("Taken") then
       local d=(a.Position-pos).Magnitude
       if d<dist and (a.Position.Z>=pos.Z-18) then apple=a dist=d end
      end
     end
     if apple and (dist<4.3) then r:_giveApple(p,apple)
     elseif apple and i==3 and ((t<10 and apple.Position.Z<first.Position.Z) or (hp<85 and dist<85 and workspace:GetAttribute("ToxicRainWeather")=="Clear")) then
      goal=Vector3.new(apple.Position.X,pos.Y,apple.Position.Z) action="Нашёл яблоко, бежит подобрать"
     end
    end
    if i==1 and (workspace:GetAttribute("ToxicRainWeather")=="Warning" or workspace:GetAttribute("ToxicRainWeather")=="ToxicRain") and t<41 then
     local stop=t<23 and 1 or 2
     local slot
     for _,s in combat._slots do if s.StopIndex==stop and (not s.Occupant or s.Occupant==p) then slot=s break end end
     if slot then
      goal=Vector3.new(slot.StandCFrame.X,pos.Y,slot.StandCFrame.Z)
      if (pos-slot.Point.Position).Magnitude<6.5 and not combat._grips[p] then combat:_tryGrip(p,slot.Id) end
     end
    end
    if i==2 and t>7 and t<41 then
     for _,target in ctx.Records do
      local diff=target.Root.Position-pos
      if target~=rec and target.Hum.Health>0 and diff.Magnitude<9 and diff.Magnitude>.5 then
       local tool=combat:_findPushTool(p) if tool then hum:EquipTool(tool) end
       combat:_tryPush(p,Vector3.new(diff.X,0,diff.Z).Unit)
       break
      end
     end
    end
    if combat._grips[p] then action="Держится за ручку: защищён" hum:Move(Vector3.zero) rec.Track:Stop()
    elseif (combat._victimImmuneUntil[p] or 0)>os.clock() then action="Отлетает от толчка"
    else
     local diff=Vector3.new(goal.X-pos.X,0,goal.Z-pos.Z)
     local dir=diff.Magnitude>1.1 and diff.Unit or Vector3.zero
     if dir.Magnitude==0 then action=t<41 and "Прячется от дождя" or action end
     local speed=i==1 and 31 or i==2 and 29 or 27
     hum.WalkSpeed=speed hum:Move(dir,false)
     root.AssemblyLinearVelocity=Vector3.new(dir.X*speed,root.AssemblyLinearVelocity.Y,dir.Z*speed)
     if dir.Magnitude>0 then
      if not rec.Track.IsPlaying then rec.Track:Play(.15) end
     elseif rec.Track.IsPlaying then rec.Track:Stop(.15) end
    end
    if rec.EatingUntil and os.clock()<rec.EatingUntil then action="Съел яблоко" end
   elseif p:GetAttribute("ToxicRainResult") then
    action=p:GetAttribute("ToxicRainResult")=="Lost" and "Погиб" or "Финиш"
    hum:Move(Vector3.zero) rec.Track:Stop()
   end
   p:SetAttribute("TestAction",action)
   rec.Label.Text=i.." · "..names[i].." | "..hp.." HP\n"..action
  end
 end)
 r._countdownRunning=true
 for _,p in list do r:_queuePlayer(p,"Group") end
 r._countdownRunning=false
 r:_beginCountdown(3,nil)
 log("Полный тест: обычные правила, 3 NPC")
end
ctx.Start=start
folder:SetAttribute("State","Ready")
return ctx
end

return Fixture
