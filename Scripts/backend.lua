local M={}
function M.new(root,log)
 local b={seq=0,ready=false,started=false,generation=0,session=tostring(os.time())..'-'..tostring(math.random(100000,999999))}
 local runtime=root..'Runtime/'
 local function write(path,s)local f=assert(io.open(path,'w'));f:write(s);f:close()end
 function b.start()
  if b.started then return end;b.started=true
  b.generation=b.generation+1;b.launched=os.time();b.ready=false
  b.session=tostring(os.time())..'-'..tostring(math.random(100000,999999))
  assert(not root:find('["%%!%^&|<>\r\n]'),'Unsupported shell character in mod path')
  write(runtime..'heartbeat.txt',b.session)
  write(runtime..'command.txt','')
  os.execute('start "" /b "'..root:gsub('/','\\')..'VoiceHost.exe" "'..b.session..'"')
  log('Audio host launched')
 end
 function b.heartbeat()
  write(runtime..'heartbeat.txt',b.session)
  if os.time()-(b.launched or os.time())>20 then
   local f=io.open(runtime..'alive.txt','r');local token,stamp
   if f then token,stamp=f:read('*l','*l');f:close()end
   if token~=b.session or os.time()-(tonumber(stamp)or 0)>10 then
    b.started=false;b.start();log('Audio host reconnected')
   end
  end
 end
 function b.poll(id)
  local f=io.open(runtime..'status.txt','r');if not f then return end
  local token,seq,state=f:read('*l','*l','*l');f:close()
  if token~=b.session then return end
  if state=='ready' or state=='done' or state=='stopped'then b.ready=true end
  if tostring(id)==seq then return state end
 end
 local function send(file,volume)
  b.seq=b.seq+1
  write(runtime..'command.txt',b.session..'\n'..b.seq..'\n'..file..'\n'..volume..'\nEND\n')
  return b.seq
 end
 function b.play(file,volume)b.poll(0);if not b.ready then return nil end;return send(file,volume)end
 function b.stop()if not b.started then return end;return send('STOP',0)end
 return b
end
return M
