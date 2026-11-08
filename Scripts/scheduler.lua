local M={}
function M.new(config,manifest,backend,random)
 local s={pending=nil,flight=nil,nextAllowed=0,last={},lastClip={},enabled=true,stats={played=0,dropped=0,failed=0}}
 local priority={combat=1,missionstart=2,enemydown=3,replytoenemy=4,playerreload=5,grenadeout=6,weaponjam=7,playerwounded=8}
 random=random or math.random
 function s:offer(category,t,delay,ttl,force)
  if not self.enabled or not manifest[category]then return false end
  if not force and ((t-(self.last[category] or -1e9))<config.cooldown[category] or random()>config.chance[category])then return false end
  local e={category=category,due=t+(delay or 0),expires=t+(delay or 0)+(ttl or 1.5),priority=priority[category],force=force}
  if self.pending and self.pending.expires>=t and self.pending.priority>e.priority then self.stats.dropped=self.stats.dropped+1;return false end
  self.pending=e;return true
 end
 function s:tick(t)
  if self.flight then
   local result=backend.poll(self.flight.id)
   if result=='done' or result=='stopped' or result=='error' or result=='dropped'then
    if result=='error'or result=='dropped'then self.stats.failed=self.stats.failed+1 end
    self.flight=nil;self.nextAllowed=t+config.gap
   elseif t-self.flight.start>30 then
    -- Never unlock a possibly still-playing channel on a guessed duration.
    self.enabled=false;self.pending=nil;backend.stop();self.stats.failed=self.stats.failed+1
   end
  end
  local e=self.pending
  if e and t>e.expires then self.pending=nil;self.stats.dropped=self.stats.dropped+1;return end
  if not self.enabled or self.flight or not e or t<e.due or t<self.nextAllowed then return end
  if not e.force and t-(self.last[e.category] or -1e9)<config.cooldown[e.category]then self.pending=nil;return end
  local list=manifest[e.category];local n=#list;local idx=random(n)
  if n>1 and idx==self.lastClip[e.category]then idx=idx%n+1 end
  local id=backend.play(list[idx].file,config.volume)
  if not id then return end
  self.pending=nil;self.flight={id=id,start=t};self.last[e.category]=t;self.lastClip[e.category]=idx;self.stats.played=self.stats.played+1
 end
 function s:clear(t)
  self.pending=nil;self.last={};self.nextAllowed=t+config.gap;self.enabled=true
  local id=backend.stop()
  if id then self.flight={id=id,start=t}end
 end
 return s
end
return M
