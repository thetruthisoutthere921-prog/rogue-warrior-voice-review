-- Incursion Red River 1.4.0.1, UE4SS experimental. No save/config/gameplay edits.
local scripts=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])'):gsub('\\','/')
local root=scripts..'../'
local C=dofile(scripts..'config.lua')
local manifest=dofile(scripts..'manifest.lua')
local H=require('UEHelpers')
local function log(s)print('[RogueWarriorVoices] '..s..'\n')end
assert(type(C.volume)=='number'and C.volume>=0 and C.volume<=1,'volume must be 0..1')
for k in pairs(manifest)do assert(C.cooldown[k]>=0 and C.chance[k]>=0 and C.chance[k]<=1,'Invalid category config: '..k)end
if not C.enabled then log('Disabled in config');return end
local B=dofile(scripts..'backend.lua').new(root,log)
local UI=dofile(scripts..'settings.lua').new(root,C,H,log)
local S=dofile(scripts..'scheduler.lua').new(C,manifest,B)
local M={hooks={},stats={events=0,replies=0,errors=0},scheduler=S,backend=B}
RogueWarriorVoices=M
local currentPawn,currentKey,raid,startedAt=nil,'',false,0
local missionSaid=false
local deadSeen,radioPending,hostiles={},{},{}
local nextMaintenance,nextHeartbeat=0,0
local stopped=false
local hostGeneration=0
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
local function name(o)if valid(o)then return o:GetFullName()end;return ''end
local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
local function guard(label,fn)
 local ok,e=pcall(fn);if not ok then M.stats.errors=M.stats.errors+1;if M.stats.errors<=20 then log(label..': '..tostring(e))end end
 return ok
end
local GS=StaticFindObject('/Script/Engine.Default__GameplayStatics')
-- World time resets on travel; scheduler deadlines must never go backwards.
local timeline,lastRaw,lastWall=0,nil,os.time()
local function now()return timeline end
local function health(p)
 if not valid(p)then return nil end
 local h=p.HealthComponent
 if not valid(h)then h=p:GetComponentByClass(StaticFindObject('/Script/Test_C.HealthComponent'))end
 return h
end
local function alive(p)local h=health(p);return valid(h)and not h:GetIsDead()end
local function active()return valid(currentPawn)and currentPawn:IsA('/Script/Test_C.IRRBaseCharacter')and alive(currentPawn)end
local function localOwner(o)
 if not valid(o)then return false end
 if same(o,currentPawn)then return true end
 local a=o:GetOwner()
 if same(a,currentPawn)then return true end
 if valid(a)then return same(a:GetOwner(),currentPawn)or same(a:GetInstigator(),currentPawn)end
 return false
end
local function emit(category,delay,ttl)
 M.stats.events=M.stats.events+1
 if active()and (raid or(category~='missionstart'and category~='replytoenemy'and category~='enemydown'))then if C.debug then log('EVENT '..category)end;return S:offer(category,now(),delay,ttl)end
end
local function hostile(a)return valid(a)and hostiles[name(a)]==true end
local function near(a,meters)
 if not valid(a)or not valid(currentPawn)then return false end
 local x,y=a:K2_GetActorLocation(),currentPawn:K2_GetActorLocation()
 return (x.X-y.X)^2+(x.Y-y.Y)^2+(x.Z-y.Z)^2<=(meters*100)^2
end
local function combatCategory(tag,event)
 local suffix=tag:match('([^%.]+)$')or tag
 suffix=suffix:lower():gsub('[^a-z]','')
 if C.reply_categories[suffix]then return true end
 local en=event:match('([^%.]+)$')or event
 for key in pairs(C.reply_categories)do if en:lower():gsub('[^a-z]',''):sub(-#key)==key then return true end end
 return false
end
local function broadcast(_,msg,param)
 if not active()then return end
 local r=param:get();if not valid(r)then return end
 local a=r:GetOwner();if not hostile(a)or not near(a,C.reply_distance_m)or not alive(a)then return end
 local m=msg:get();local ev=m.BroadcasterEvent
 if not valid(ev)then return end
 local tag=r.RadioMessageTag.TagName:ToString()
 if not combatCategory(tag,name(ev))then radioPending[name(r)]=nil;return end
 local t=now()
 local previous=radioPending[name(r)]
 radioPending[name(r)]={actor=a,tag=tag,event=name(ev),eventId=ev:GetWwiseShortId()%4294967296,time=t,expires=t+30,ambiguous=previous~=nil}
 if C.debug then log('COMBAT SPEECH '..tag..' '..name(ev))end
end
local callbackEnum=StaticFindObject('/Script/AkAudio.EAkCallbackType')
local function speechEnd(ctx,kind,info)
 if not active()or not valid(callbackEnum)then return end
 local label=callbackEnum:GetNameByValue(kind:get()):ToString()
 if not label:find('EndOfEvent',1,true)then return end
 local r=ctx:get();local key=name(r);local pending=radioPending[key]
 if not pending then return end
 local details=info:get()
 if not valid(details)or details.EventId%4294967296~=pending.eventId then return end
 radioPending[key]=nil
 if pending.ambiguous then return end
 if now()>pending.expires or not alive(pending.actor)or not hostile(pending.actor)or not near(pending.actor,C.reply_distance_m)then return end
 -- A changed tag means the preceding line was interrupted/replaced. Do not answer it.
 if r.RadioMessageTag.TagName:ToString()~=pending.tag then return end
 if emit('replytoenemy',C.reply_delay,1.5)then M.stats.replies=M.stats.replies+1 end
end
local function ability(ctx,param)
 if not active()or not localOwner(ctx:get())then return end
 local a=param:get();local n=name(a)
 if n:find('SGA_Reload',1,true)or (valid(a)and a:IsA('/Script/Test_C.SimpleGameplayAbility_Reload'))then emit('playerreload',0,1.2)end
end
local function shot(ctx)if active()and localOwner(ctx:get())then emit('combat',0.7,1.0)end end
local function grenade(ctx)if active()and localOwner(ctx:get())then emit('grenadeout',0,4)end end
local function malfunction(ctx)if active()and localOwner(ctx:get())then emit('weaponjam',0,1.5)end end
local function damage(ctx,data,hurt)
 local h=ctx:get()
 if same(h:GetOwner(),currentPawn)and hurt:get()and data:get().Damage>0 then emit('playerwounded',0,1.2)end
end
local function death(ctx,data)
 if not active()then return end
 local a=ctx:get();local key=name(a);if deadSeen[key]then return end
 local d=data:get();local inst=d.DamageInstigator
 local pc=H.GetPlayerController()
 if (same(inst,currentPawn)or same(inst,pc))and hostile(a)then
  deadSeen[key]=true;emit('enemydown',0.4,1.8)
 end
end
local paths={
 ['/Script/Test_C.GameplayAbilityComponent:OnGameplayAbilityCommitted']=ability,
 ['/Script/Test_C.WeaponComponent:SingleFireWeapon_MC']=shot,
 ['/Script/Test_C.GrenadeComponent:K2_OnGrenadeThrown']=grenade,
 ['/Game/Blueprints/InventorySystem/Components/ItemComponents/BP_WeaponComponent.BP_WeaponComponent_C:K2_HandleMalfunction']=malfunction,
 ['/Game/Blueprints/General/Components/BP_HealthComponent.BP_HealthComponent_C:K2_ReceivedDamage']=damage,
 ['/Game/Blueprints/AI/Characters/BP_IRR_AI_BaseCharacter.BP_IRR_AI_BaseCharacter_C:OnDeath_Event']=death,
 ['/Script/IRRRadioSystem.IRRRadioManager:BroadcastRadioMessage_MC']=broadcast,
 ['/Script/IRRRadioSystem.IRRRadioComponent:OnBroadcasterEventCallback']=speechEnd,
}
local function install()
 for path,fn in pairs(paths)do
  if not M.hooks[path]and valid(StaticFindObject(path))then
   guard('hook '..path,function()
    local wrapper=function(...)local args={...};guard('event '..path,function()fn(table.unpack(args))end)end
    -- Native callbacks are pre-hooks; Blueprint callbacks execute after their body.
    local a,b=RegisterHook(path,wrapper);M.hooks[path]={a,b};log('Hooked '..path)
   end)
  end
 end
end
local function tick()
 local pc=H.GetPlayerController();local p=valid(pc)and pc.Pawn or nil
 local wall=os.time();local raw=valid(p)and GS:GetRealTimeSeconds(p)or nil
 local delta=raw and lastRaw and raw-lastRaw or nil
 timeline=timeline+((delta and delta>=0 and delta<10)and delta or math.max(0,wall-lastWall))
 lastRaw=raw;lastWall=wall
 local key=name(p)
 if key~=currentKey then
  currentPawn=p;currentKey=key;raid=valid(p)and p:IsA('/Script/Test_C.IRRBaseCharacter')and key:find('/Game/Maps/Gameplay/',1,true)~=nil and not key:lower():find('hideout',1,true)and not key:find('LVL_Menu',1,true)
  startedAt=now();missionSaid=false;radioPending={};deadSeen={};hostiles={};S:clear(startedAt);nextMaintenance=0;nextHeartbeat=0;stopped=false
  log(raid and 'Raid entered' or 'Outside raid; voice events muted')
 end
 local t=now()
 if wall>=nextHeartbeat then nextHeartbeat=wall+1;B.heartbeat();B.poll(0)end
 if hostGeneration~=(B.generation or 0)then hostGeneration=B.generation or 0;S:clear(t)end
 if t>=nextMaintenance then
  nextMaintenance=t+1;install();hostiles={}
  if valid(p)and valid(p.TeamComponent)then p.TeamComponent.Hostiles:ForEach(function(_,v)local a=v:get();if valid(a)then hostiles[name(a)]=true end end)end
  for k,v in pairs(radioPending)do if t>v.expires then radioPending[k]=nil end end
 end
 if active()then
  stopped=false
  if raid and not missionSaid and t-startedAt>=C.mission_delay then
   local gi=H.GetGameInstance()
   if valid(gi)and not gi.bShowLoadingScreen then missionSaid=true;emit('missionstart',0,5)end
  end
 elseif not stopped then S:clear(t);stopped=true end
 S:tick(t)
end
function M.preview(category)
 if manifest[category]then return S:offer(category,now(),0,5,true)end
end
function M.status()log('played='..S.stats.played..' dropped='..S.stats.dropped..' audioErrors='..S.stats.failed..' eventErrors='..M.stats.errors..' replies='..M.stats.replies..' hostReady='..tostring(B.ready)..' scheduler='..tostring(S.enabled)..' raid='..tostring(raid)..' alive='..tostring(alive(currentPawn))..' health='..name(health(currentPawn))..' events='..M.stats.events)end
function M.shutdown()
 UI:shutdown();if M.uiTimer then CancelDelayedAction(M.uiTimer)end
 if M.timer then CancelDelayedAction(M.timer)end
 for path,ids in pairs(M.hooks)do pcall(UnregisterHook,path,ids[1],ids[2])end
 B.stop();M.hooks={};log('Stopped')
end
B.start()
M.uiTimer=LoopInGameThreadWithDelay(250,function()guard('audio settings',function()UI:tick()end)end)
M.timer=LoopInGameThreadWithDelay(50,function()guard('tick',tick)end)
local previews={'missionstart','playerreload','weaponjam','grenadeout','enemydown','playerwounded','combat','replytoenemy'}
local previewIndex=0
if not IsKeyBindRegistered(Key.F7,{ModifierKey.CONTROL,ModifierKey.ALT})then RegisterKeyBind(Key.F7,{ModifierKey.CONTROL,ModifierKey.ALT},function()ExecuteInGameThread(function()previewIndex=previewIndex%#previews+1;RogueWarriorVoices.preview(previews[previewIndex]);log('Preview '..previews[previewIndex])end)end)end
if not IsKeyBindRegistered(Key.F10,{ModifierKey.CONTROL,ModifierKey.ALT})then RegisterKeyBind(Key.F10,{ModifierKey.CONTROL,ModifierKey.ALT},function()ExecuteInGameThread(function()RogueWarriorVoices.status()end)end)end
log('Loaded 152 lines; Ctrl+Alt+F7 previews, Ctrl+Alt+F10 reports status')
