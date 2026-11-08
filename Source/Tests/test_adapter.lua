local root=...;local realDofile=dofile;local clock=0;local hooks={};local seq=0;local state={}
local function wrap(x)return{get=function()return x end}end
local function object(n,id)
 return {IsValid=function()return true end,GetFullName=function()return n end,GetAddress=function()return id end,IsA=function()return false end,GetOwner=function()return nil end,GetInstigator=function()return nil end}
end
local p=object('BP_Player /Game/Maps/Gameplay/LVL_Quarry.LVL_Quarry:PersistentLevel.Player',1)
local enemy=object('BP_AI /Game/Maps/Gameplay/LVL_Quarry.LVL_Quarry:PersistentLevel.Enemy',2)
local friend=object('BP_AI /Game/Maps/Gameplay/LVL_Quarry.LVL_Quarry:PersistentLevel.Friend',3)
for _,a in ipairs({p,enemy,friend})do a.HealthComponent={IsValid=function()return true end,GetIsDead=function()return false end};a.K2_GetActorLocation=function()return{X=0,Y=0,Z=0}end end
p.TeamComponent={IsValid=function()return true end,Hostiles={ForEach=function(_,fn)fn(1,wrap(enemy))end}}
p.IsA=function()return true end; local pc=object('PC',4);pc.Pawn=p
local function component(owner,id)local c=object('component',id);c.GetOwner=function()return owner end;return c end
local localComp=component(p,10);local enemyComp=component(enemy,11)
local gi=object('GI',12);gi.bShowLoadingScreen=false
package.preload.UEHelpers=function()return{GetPlayerController=function()return pc end,GetGameInstance=function()return gi end}end
local backend={start=function()end,heartbeat=function()end,poll=function(id)return state[id]end,
 play=function()seq=seq+1;state[seq]='done';return seq end,stop=function()seq=seq+1;state[seq]='stopped';return seq end}
dofile=function(path)
 if path:find('backend.lua',1,true)then return{new=function()return backend end}end
 local v=realDofile(path)
 if path:find('config.lua',1,true)then for k in pairs(v.chance)do v.chance[k]=1 end end
 return v
end
StaticFindObject=function(path)
 local o=object(path,99);o.GetRealTimeSeconds=function()return clock end
 o.GetNameByValue=function(_,v)return{ToString=function()return v==0 and 'EAkCallbackType::EndOfEvent'or'EAkCallbackType::Duration'end}end
 return o
end
RegisterHook=function(path,fn)hooks[path]=fn;return 1,2 end
UnregisterHook=function()end
LoopInGameThreadWithDelay=function(_,fn)_tick=fn;return 1 end
CancelDelayedAction=function()end
IsKeyBindRegistered=function()return true end
Key={F7=7,F10=10};ModifierKey={CONTROL=1,ALT=2}
local source=assert(io.open(root..'Scripts/main.lua')):read('*a')
assert(load(source,'@'..root..'Scripts/main.lua'))()
_tick();clock=4;_tick()
local M=RogueWarriorVoices;local s=M.scheduler
assert(M.stats.events==1,'mission entry missing')
local function check(path,args,expected)
 s.pending=nil;local before=M.stats.events
 hooks[path](table.unpack(args))
 assert(M.stats.events-before==(expected and 1 or 0),path..' filtering failed')
 if expected then assert(s.pending and s.pending.category==expected,path..' wrong category')end
 s.pending=nil
end
local reload=object('SGA_Reload_C reload',13)
local ability='/Script/Test_C.GameplayAbilityComponent:OnGameplayAbilityCommitted'
check(ability,{wrap(localComp),wrap(reload)},'playerreload')
check(ability,{wrap(enemyComp),wrap(reload)},nil)
check('/Script/Test_C.WeaponComponent:SingleFireWeapon_MC',{wrap(localComp)},'combat')
check('/Script/Test_C.WeaponComponent:SingleFireWeapon_MC',{wrap(enemyComp)},nil)
check('/Script/Test_C.GrenadeComponent:K2_OnGrenadeThrown',{wrap(localComp)},'grenadeout')
check('/Game/Blueprints/InventorySystem/Components/ItemComponents/BP_WeaponComponent.BP_WeaponComponent_C:K2_HandleMalfunction',{wrap(localComp)},'weaponjam')
local damage='/Game/Blueprints/General/Components/BP_HealthComponent.BP_HealthComponent_C:K2_ReceivedDamage'
check(damage,{wrap(localComp),wrap({Damage=10}),wrap(true)},'playerwounded')
check(damage,{wrap(enemyComp),wrap({Damage=10}),wrap(true)},nil)
check(damage,{wrap(localComp),wrap({Damage=10}),wrap(false)},nil)
local death='/Game/Blueprints/AI/Characters/BP_IRR_AI_BaseCharacter.BP_IRR_AI_BaseCharacter_C:OnDeath_Event'
check(death,{wrap(friend),wrap({DamageInstigator=p})},nil)
check(death,{wrap(enemy),wrap({DamageInstigator=p})},'enemydown')
check(death,{wrap(enemy),wrap({DamageInstigator=p})},nil)
local radio=component(enemy,14)
local tag='AI.Bark.Engaging Enemy'
radio.RadioMessageTag={TagName={ToString=function()return tag end}}
local event=object('AkAudioEvent /Game/VO/VO_UICS_Enemy_1_EngagingEnemy.VO_UICS_Enemy_1_EngagingEnemy',15)
event.GetWwiseShortId=function()return 123 end
local broadcast='/Script/IRRRadioSystem.IRRRadioManager:BroadcastRadioMessage_MC'
local ended='/Script/IRRRadioSystem.IRRRadioComponent:OnBroadcasterEventCallback'
hooks[broadcast](nil,wrap({BroadcasterEvent=event}),wrap(radio));assert(not s.pending,'reply started before enemy finished')
local info=object('callback',16);info.EventId=999
check(ended,{wrap(radio),wrap(0),wrap(info)},nil)
info.EventId=123
check(ended,{wrap(radio),wrap(3),wrap(info)},nil)
check(ended,{wrap(radio),wrap(0),wrap(info)},'replytoenemy')
-- Ambient speech never produces a reply.
tag='AI.Bark.Idle';event.GetFullName=function()return 'AkAudioEvent /Game/VO/VO_Idle_Solo.VO_Idle_Solo'end
hooks[broadcast](nil,wrap({BroadcasterEvent=event}),wrap(radio))
check(ended,{wrap(radio),wrap(0),wrap(info)},nil)
-- Overlapping/replaced enemy broadcasts are ambiguous and skipped.
tag='AI.Bark.Engaging Enemy'
hooks[broadcast](nil,wrap({BroadcasterEvent=event}),wrap(radio));hooks[broadcast](nil,wrap({BroadcasterEvent=event}),wrap(radio))
check(ended,{wrap(radio),wrap(0),wrap(info)},nil)
assert(M.stats.errors==0)
-- A new world's clock starts at zero. Mission entry must still become due.
local before=M.stats.events
p.GetFullName=function()return 'BP_Player /Game/Maps/Gameplay/LVL_New.LVL_New:PersistentLevel.Player'end
clock=0;_tick();clock=4;_tick()
assert(M.stats.events==before+1,'world clock reset suppressed mission start')
-- The menu lives below /Gameplay/ too, but is never a raid.
p.GetFullName=function()return 'BP_Lobby /Game/Maps/Gameplay/LVL_Menu.LVL_Menu:PersistentLevel.Menu'end
p.IsA=function()return false end
before=M.stats.events;clock=0;_tick();clock=8;_tick()
assert(M.stats.events==before,'menu triggered automatic mission voice')
print('PASS: adapter mission, local ownership, reload, shot, grenade, jam, wound, kill attribution, duplicate death, combat-only reply, actual-end gate, event ID, ambient exclusion, interrupted speech')

