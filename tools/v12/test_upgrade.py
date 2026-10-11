"""Run V11 -> V12 transactional upgrade checks using the published V11 installer."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import test_install as base
from assemble import payload, REPO, literal

MODES = ['upgrade', 'rootServerMain', 'missingEconomy', 'customHUD', 'customCatalog',
         'wrongShopVersion', 'sourceWriteFailure', 'lobbyCommitFailure', 'versionWriteFailure',
         'repeatV12', 'repairOwnerModule', 'repairSkinModule', 'repeatBrokenShop',
         'ownedChatCommand', 'conflictingChatCommand', 'clonedLobbyScript']
STUB_SHOP = base.SHOP_STUB.replace("function S.Validate(lobby) assert", "function S.Validate(lobby) assert(not lobby:GetAttribute('BrokenFixtureShop'),'Broken shop fixture');assert")
STUB_SHOP = STUB_SHOP.replace("function S.Apply(lobby) lobby:SetAttribute", "function S.Apply(lobby) assert(lobby:GetAttribute('HussShopVersion')==nil or lobby:GetAttribute('HussShopVersion')==12,'Unsupported existing shop version');lobby:SetAttribute")
PREPARE = r'''
 end
 check(pcall(installLegacy),'Published V11 installer succeeds before upgrade')
 if mode=='rootServerMain' then objects.MAIN.Parent=sss end
 if mode=='missingEconomy' then sf.EconomyServiceV9:Destroy() end
 if mode=='customHUD' then objects.HUD.Source..='\n-- preserved user customization' end
 if mode=='customCatalog' then rs.HussCatalogV11.Source..='\n-- preserved user customization' end
 if mode=='wrongShopVersion' then workspace.Lobby:SetAttribute('HussShopVersion',99) end
 if mode=='conflictingChatCommand' then local c=make('TextChatCommand',services.TextChatService,'Other');c.PrimaryAlias='/gRaNt';c.SecondaryAlias='' end
 if mode=='clonedLobbyScript' then make('Script',workspace.Lobby,'CustomBehavior','print("preserve")') end
 local baseline={lobby=workspace.Lobby,library=ss.MapLibrary,arena=maps.Arena01,previews=rs.BombTagV6Previews,version=workspace:GetAttribute('HussExpansionVersion'),chosen=workspace:GetAttribute('CurrentVotedMap'),sources={},parents={}}
 for _,root in ipairs({sss,sp,rs}) do for _,o in ipairs(root:GetDescendants()) do if o:IsA('LuaSourceContainer') then baseline.sources[o]=o.Source;baseline.parents[o]=o.Parent end end end
 local baselineBackupCount=#ss:GetChildren()
 local originalNewIndex,originalSetAttribute=mt.__newindex,methods.SetAttribute
 local failArmed=true
 mt.__newindex=function(o,k,v)
  if failArmed and ((mode=='sourceWriteFailure' and o==objects.BOMB and k=='Source' and v~=baseline.sources[o]) or (mode=='lobbyCommitFailure' and o.Name=='Lobby' and o~=baseline.lobby and k=='Parent' and v==workspace)) then failArmed=false;error('Injected V12 source or lobby failure') end
  return originalNewIndex(o,k,v)
 end
 methods.SetAttribute=function(o,k,v)
  if failArmed and mode=='versionWriteFailure' and o==workspace and k=='HussExpansionVersion' and v==12 then failArmed=false;error('Injected V12 version failure') end
  return originalSetAttribute(o,k,v)
 end
 requires=0
 local function install()
'''
POST = r'''
 end
 local ok,err=pcall(install)
 mt.__newindex=originalNewIndex;methods.SetAttribute=originalSetAttribute
 local rejected={customHUD=true,customCatalog=true,wrongShopVersion=true,sourceWriteFailure=true,lobbyCommitFailure=true,versionWriteFailure=true,conflictingChatCommand=true,clonedLobbyScript=true}
 check(ok~=not not rejected[mode],mode..': '..tostring(err))
 check(ss.MapLibrary==baseline.library and maps.Arena01==baseline.arena and rs.BombTagV6Previews==baseline.previews,'Existing V11 maps, active arena and previews retain identity: '..mode)
 if ok then
  check(workspace.Lobby~=baseline.lobby,'Only lobby cloned for shop installation')
  check(baseline.lobby.Parent and baseline.lobby.Parent.Name=='World','Original lobby archived in backup')
  check(workspace:GetAttribute('HussExpansionVersion')==12 and workspace.Lobby:GetAttribute('HussShopVersion')==12,'V12 verified markers committed')
  check(objects.MAIN.Parent==baseline.parents[objects.MAIN],'Actual ServerMain location preserved')
  check(objects.ROUND.Source==baseline.sources[objects.ROUND] and objects.MOVEMENT.Source==baseline.sources[objects.MOVEMENT] and objects.EFFECTS.Source==baseline.sources[objects.EFFECTS],'Existing round, movement and effects sources unchanged')
  for _,name in ipairs(newNames) do check(destination(name,rs,sp,sf):FindFirstChild(name)~=nil,'Installed expected V12 source '..name) end
  check(requires>=24,'All V12 outputs and dependencies syntax checked')
  local currentLobby=workspace.Lobby
  local backupCount=#ss:GetChildren()
  if mode=='repairOwnerModule' then sf.OwnerCommandsV12:Destroy() end
  if mode=='repairSkinModule' then rs.BombSkinBuilderV12:Destroy() end
  if mode=='repeatBrokenShop' then workspace.Lobby:SetAttribute('BrokenFixtureShop',true) end
  if mode=='ownedChatCommand' then local c=make('TextChatCommand',services.TextChatService,'HussOwnerGrantV12');c.PrimaryAlias='/grant';c.SecondaryAlias='/hussgrant';c:SetAttribute('HussOwnerCommandVersion',12) end
  if mode=='repeatV12' or mode=='repairOwnerModule' or mode=='repairSkinModule' or mode=='repeatBrokenShop' or mode=='ownedChatCommand' then
   local again,message=pcall(install)
   check(again==(mode~='repeatBrokenShop' and mode~='ownedChatCommand'),'V12 rerun: '..tostring(message))
   check(workspace.Lobby==currentLobby and ss.MapLibrary==baseline.library,'Rerun never replaces intact geometry')
   check(sf:FindFirstChild('OwnerCommandsV12') and rs:FindFirstChild('BombSkinBuilderV12'),'Missing owned modules repaired')
   if mode=='repeatV12' or mode=='ownedChatCommand' or mode=='repeatBrokenShop' then check(#ss:GetChildren()==backupCount,'No-op/rejected rerun creates no backup') end
  end
 else
  check(workspace.Lobby==baseline.lobby and workspace:GetAttribute('HussExpansionVersion')==baseline.version and workspace:GetAttribute('CurrentVotedMap')==baseline.chosen,'V11 world and marker restored')
  for o,source in pairs(baseline.sources) do check(o.Source==source and o.Parent==baseline.parents[o],'Existing source fully preserved: '..o.Name) end
  check(#ss:GetChildren()==baselineBackupCount,'Failed V12 leaves no staged objects or extra backup')
  for _,name in ipairs({'OwnerCommandsV12','BombSkinBuilderV12','StandShopV12','CarrierPanicV12','OwnerFeedbackV12'}) do check(not destination(name,rs,sp,sf):FindFirstChild(name),'Failed install removes newly staged '..name) end
 end
 check(services.Lighting.TimeOfDay=='08:45:00' and sky.SkyboxBk=='preserved','Lighting preserved')
 table.insert(summaries,{mode=mode,result=ok and 'upgraded' or 'originals preserved',requires=requires,error=ok and '' or tostring(err)})
end
for _,mode in ipairs(modes) do runCase(mode) end
print('UPGRADE_REPORT '..json({assertions=assertions,cases=#modes,results=summaries}))
'''


def main():
    full = '--full-world' in sys.argv
    selected = ['upgrade','repeatV12','sourceWriteFailure','lobbyCommitFailure'] if full else MODES
    setup = base.SETUP
    prefix = base.PREFIX
    if full:
        prefix += '\nlocal ColorSequence={new=function(a,b) return {_kind="ColorSequence",A=a,B=b or a} end}\n'
        for name,file in [('OldMaps','MovementMapBuilder.luau'),('OldLobby','LobbyBuilderV7.luau')]:
            prefix += '\nlocal '+name+'=(function()\n'+(REPO/file).read_text()+'\nend)()\n'
        start=setup.index(" local library=make('Folder',ss,'MapLibrary')");end=setup.index(" local anchor=make('Part',workspace,'ActiveArenaAnchor')",start)
        setup=setup[:start]+" local library=make('Folder',ss,'MapLibrary');OldMaps.BuildInto(library)\n local lobby=OldLobby.Build(workspace,CFrame.new(0,0,240));local spawn=lobby.LobbySpawn\n"+setup[end:]
    begin = setup.index('local modes=')
    finish = setup.index('\nlocal newNames=', begin)
    setup = setup[:begin] + 'local modes=' + '{' + ','.join(literal(x) for x in selected) + '}' + setup[finish:]
    setup = setup.replace("for _,name in ipairs(newNames) do table.insert(modes,'conflict_'..name);table.insert(modes,'parent_'..name) end", '')
    setup = setup.replace("for _,name in ipairs({'HUD','MAIN','BOMB','ROUND','MOVEMENT','EFFECTS'}) do table.insert(modes,'write_'..name) end", '')
    setup = setup.replace('local function install()\n', 'local function installLegacy()\n')
    legacy = (REPO / 'Install-Bomb-Expansion-V11.command.luau').read_text()
    if not full:
        begin = legacy.index('\nlocal worldBuilder=(function()\n')
        finish = legacy.index('\nlocal placementBuilder=', begin)
        legacy = legacy[:begin] + '\nlocal worldBuilder=(function()\n' + base.STUB + '\nend)()\n' + legacy[finish:]
    body = prefix + '\n' + base.FIXTURE + ''.join('local ' + k + '_SOURCE=' + literal(p.read_text()) + '\n' for k, p in base.SOURCES.items())
    body += setup + legacy + PREPARE + payload(None if full else base.STUB, None if full else STUB_SHOP) + POST
    suffix='-full' if full else ''
    target = base.ROOT / ('test-upgrade'+suffix+'.luau')
    target.write_text(body)
    result = subprocess.run([os.environ.get('LUAU') or shutil.which('luau') or '/workspace/.cloud-tools/bin/luau', str(target)], text=True, capture_output=True)
    (base.ROOT / ('test-upgrade'+suffix+'.output')).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise SystemExit(result.stdout[-2000:] + result.stderr)
    report = json.loads(next(line.split(' ', 1)[1] for line in result.stdout.splitlines() if line.startswith('UPGRADE_REPORT ')))
    report['scope'] = ('Actual authored V4 maps/V7 lobby followed by published V11 installer and full V12; no native Studio engine.' if full else 'Published V11 installer followed by actual V12 source payload, deterministic geometry fixture; no native Studio engine.')
    (base.ROOT / ('upgrade'+suffix+'.validation.json')).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'results'}))


if __name__ == '__main__':
    main()
