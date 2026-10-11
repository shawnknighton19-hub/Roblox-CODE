#!/usr/bin/env python3
"""Execute private owner chat feedback against event, chat and lifecycle mocks."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
PREFIX = r'''
local checks=0
local function check(ok,message) checks+=1;assert(ok,message) end
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local c={fn=fn,Connected=true};function c:Disconnect() self.Connected=false end
  table.insert(self.listeners,c);return c
 end
 function s:Fire(...) for _,c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
 return s
end
local function environment(mode,missing,failLegacy)
 local ctx={chat={},core={},waits=0}
 local rs={children={},ChildAdded=signal(),ChildRemoved=signal()}
 function rs:GetChildren() return self.children end
 local channel={DisplaySystemMessage=function(_,message) table.insert(ctx.chat,message) end}
 local channels={FindFirstChild=function(_,name) return not missing and name=='RBXGeneral' and channel or nil end,FindFirstChildOfClass=function() return nil end}
 local chat={ChatVersion=mode,FindFirstChild=function(_,name) return name=='TextChannels' and channels or nil end}
 local gui={SetCore=function(_,name,data)
  if name=='ChatMakeSystemMessage' and failLegacy then error('Chat not ready') end
  table.insert(ctx.core,{name=name,data=data})
 end}
 local services={ReplicatedStorage=rs,TextChatService=chat,StarterGui=gui}
 local game={GetService=function(_,name) return services[name] end}
 local script={Destroying=signal()}
 local Enum={ChatVersion={TextChatService='Modern'}}
 local Color3={fromRGB=function(r,g,b) return {r,g,b} end}
 local task={spawn=function(fn) fn() end,wait=function() ctx.waits+=1 end}
 local function run()
'''
SUFFIX = r'''
 end
 run()
 function ctx:add(name,class)
  local r={Name=name or 'HussEconomyV9',ClassName=class or 'RemoteEvent',OnClientEvent=signal()}
  function r:IsA(wanted) return self.ClassName==wanted end
  table.insert(rs.children,r);rs.ChildAdded:Fire(r);return r
 end
 function ctx:remove(r)
  local index=table.find(rs.children,r);if index then table.remove(rs.children,index) end
  rs.ChildRemoved:Fire(r)
 end
 function ctx:destroy() script.Destroying:Fire() end
 return ctx
end
local modern=environment('Modern');local remote=modern:add()
remote.OnClientEvent:Fire({kind='OwnerCommand',ok=true,message='Coins < 10 & > 0'})
check(#modern.chat==1 and modern.chat[1]:find('Coins &lt; 10 &amp; &gt; 0',1,true),'modern private message escapes rich text and supports late remote creation')
check(modern.chat[1]:find('#72F5A8',1,true),'successful grant uses confirmation color')
remote.OnClientEvent:Fire({kind='OwnerCommand',ok=false,message='Not ready'})
check(#modern.chat==2 and modern.chat[2]:find('#FFD166',1,true),'owner error is clearly distinguished')
remote.OnClientEvent:Fire({kind='Profile',message='ordinary sync'})
remote.OnClientEvent:Fire({kind='OwnerCommand',message=string.rep('x',2049)})
remote.OnClientEvent:Fire({kind='OwnerCommand',message={}})
remote.OnClientEvent:Fire('invalid')
check(#modern.chat==2,'economy traffic and malformed feedback never spam chat')
modern:remove(remote);remote.OnClientEvent:Fire({kind='OwnerCommand',message='removed'})
check(#modern.chat==2,'removed economy remote disconnects private feedback')
local replacement=modern:add();replacement.OnClientEvent:Fire({kind='OwnerCommand',ok=true,message='replacement'})
check(#modern.chat==3,'replacement economy remote reattaches without timeout')
local decoy=modern:add('Unrelated');decoy.OnClientEvent:Fire({kind='OwnerCommand',message='decoy'})
check(#modern.chat==3,'unrelated remotes cannot inject owner feedback')
modern:destroy();replacement.OnClientEvent:Fire({kind='OwnerCommand',message='destroyed'})
modern:add().OnClientEvent:Fire({kind='OwnerCommand',message='after shutdown'})
check(#modern.chat==3,'destroyed LocalScript removes listeners and never reconnects')
local old=environment('Legacy');old:add().OnClientEvent:Fire({kind='OwnerCommand',ok=true,message='legacy'})
check(#old.core==1 and old.core[1].name=='ChatMakeSystemMessage' and old.core[1].data.Text=='[Owner] legacy','legacy chat uses private client system message')
local absent=environment('Modern',true);absent:add().OnClientEvent:Fire({kind='OwnerCommand',message='fallback'})
check(#absent.core==1 and absent.core[1].name=='SendNotification' and absent.waits==9,'missing channels retry boundedly then show private notification')
local broken=environment('Legacy',false,true);broken:add().OnClientEvent:Fire({kind='OwnerCommand',message='fallback'})
check(#broken.core==1 and broken.core[1].name=='SendNotification' and broken.waits==9,'unready legacy core retries boundedly then shows notification')
print('Owner feedback V12 checks passed:',checks)
'''

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
    args = parser.parse_args()
    source = PREFIX + (ROOT / 'OwnerFeedbackV12.client.luau').read_text() + SUFFIX
    with tempfile.TemporaryDirectory(prefix='huss-owner-feedback-v12-') as directory:
        test = Path(directory) / 'feedback.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        print(result.stdout, end='')
        print(result.stderr, end='')
        raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
