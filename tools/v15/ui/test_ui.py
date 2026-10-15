#!/usr/bin/env python3
"""Execute V15 HUD, modal ownership and controls in standalone Luau GUI doubles."""
from pathlib import Path
import hashlib,json,subprocess,tempfile,os,shutil,re
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
FILES=['HABModalV15.luau','HABUILayoutV15.luau','HABReferenceThemeV15.luau','HudControllerV15.luau','HABCombatHUDV15.luau','HABExpansionClientV15.client.luau','HABCrateShopClientV15.client.luau','StandShopV15.client.luau','HABCombatFXV15.client.luau']
luau=os.environ.get('LUAU') or shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'
compiler=luau+'-compile'
fixture=(ROOT/'tools/v12/tests/shop_fixture.luau.in').read_text().split('local productionCatalog=')[0]
fixture=fixture.replace('function instanceMethods:FireServer(...)',"function instanceMethods:InvokeServer(action,key) table.insert(serverCalls,{remote=self.Name,args=table.pack(action,key)});return self._response and self._response(action,key) or {OK=false} end\nfunction instanceMethods:FireServer(...)")
fixture=fixture.replace('local Enum =','local warn=print\nlocal Enum =')
fixture=fixture.replace('_props={Name=class,Visible=true','_props={ZIndex=1,Name=class,Visible=true')
fixture=fixture.replace('local signals={','local signals={Event=true,')
fixture+=(HERE/'fixture.luau').read_text()
for f in FILES:
 subprocess.run([compiler,str(ROOT/f)],check=True,stdout=subprocess.DEVNULL)
 fixture=fixture.replace('{{'+f+'}}','\n'+(ROOT/f).read_text()+'\n')
fixture=fixture.replace('{{CATALOG}}','\n'+(ROOT/'HussCatalogV14.luau').read_text()+'\n')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ui.luau';p.write_text(fixture)
 r=subprocess.run([luau,str(p)],capture_output=True,text=True)
 snapshots=[line for line in r.stdout.splitlines() if line.startswith('UI_SNAPSHOT ')]
 (HERE/'snapshots.json').write_text(json.dumps([json.loads(line[12:]) for line in snapshots]))
 print('\n'.join(line for line in r.stdout.splitlines() if not line.startswith('UI_SNAPSHOT ')));print(r.stderr,end='')
 if r.returncode: raise SystemExit(r.returncode)
report={'status':'passed','assertions':int(re.search(r'UI_V15 (\d+) assertions passed',r.stdout).group(1)),'sourceSha256':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in FILES},'output':r.stdout.strip().splitlines()[-1], 'checks':['Actual five UI owners and kill feed execute in standalone GUI doubles','Modal transfer among core HUD, ability picker, store, collection and physical booth','Modal close/reopen, round start, teardown and input suppression attribute contract','Ability/tag/owned throw visibility; real callback actions and cooldown states','Lobby four-entry dock; all secondary pages reachable; retired emotes stay retired','Shared responsive layout bounds and overlap across desktop, portrait and short landscape safe areas','Pass prices require server verified availability and retain local metadata query','Physical stand proximity and purchase remote preserved','HUD map voting, AFK, stats and settings callbacks retained'], 'limitations':['Standalone Luau GUI doubles do not render native Studio, measure actual glyphs, emulate Marketplace, or certify touch playtesting.']}
(ROOT/'UIV15.validation.json').write_text(json.dumps(report,indent=2)+'\n')
