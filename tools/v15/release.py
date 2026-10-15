"""Bind the finished artifacts to their final component and transaction reports."""
from pathlib import Path
import hashlib,json,subprocess
from assemble import REPO,ROOT,REPLACEMENTS,ADDITIONS,payload

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    reports=['ActionsV15.validation.json','CleanFXV15.validation.json','CombatV15.validation.json',
      'FXCanvasV15.validation.json','Install-Polish-V15.validation.json','LobbyInstallerV15.validation.json',
      'LobbyV15.validation.json','LobbyGeometryV15.validation.json','MonetizationV15.validation.json','UIV15.validation.json',
      'V15-APIReview.validation.json','V15-InputAudit.validation.json','Huss-A-Bomb-V15.validation.json',
      'ModernRBXLV15.validation.json','V15-FinalPlaceReview.validation.json']
    artifacts=['Huss-A-Bomb-V15.rbxl','Install-Polish-V15.command.luau','Huss-A-Bomb-V15.txt','Install-Polish-V15.txt']
    components=set(REPLACEMENTS.values())|{source for _,source in ADDITIONS}|{'LobbyBuilderV15.luau'}
    verified=set()
    loaded={}
    for name in reports:
        data=json.loads((REPO/name).read_text());loaded[name]=data
        assert data.get('passed',True) is not False,name
        assert data.get('status','passed')=='passed',name
        for key in ('source_sha256','sha256','sourceSha256'):
            hashes=data.get(key,{})
            if isinstance(hashes,dict):
                for file,digest in hashes.items():
                    path=REPO/file
                    if isinstance(digest,str) and path.is_file():
                        assert sha(path)==digest,f'Stale evidence: {name} -> {file}'
                        verified.add(file)
        if isinstance(data.get('sourceSHA256'),str):
            assert sha(REPO/'LobbyBuilderV15.luau')==data['sourceSHA256'],name
            verified.add('LobbyBuilderV15.luau')
    assert components<=verified,f'Untested or unbound sources: {components-verified}'
    command=REPO/artifacts[1]
    assert command.read_text()==payload(),'Assembly out of date'
    assert sha(command)==loaded['Install-Polish-V15.validation.json']['installer_sha256'],'Installer tests out of date'
    for name in artifacts[2:]:
        data=(REPO/name).read_bytes()
        assert data.replace(b'\r\n',b'\n')==command.read_bytes(),f'Windows payload mismatch: {name}'
        assert b'\n' not in data.replace(b'\r\n',b''),'TXT is not CRLF'
    binary=loaded['Huss-A-Bomb-V15.validation.json']
    assert sha(REPO/artifacts[0])==binary['output_sha256'],'File validation hash mismatch'
    assert binary['input_sha256']==loaded['V15-InputAudit.validation.json']['input_sha256'],'Wrong input place'
    result={'version':15,'status':'passed','base_place':'HABWAS.rbxl','input_sha256':binary['input_sha256'],
      'artifacts':{name:{'bytes':(REPO/name).stat().st_size,'sha256':sha(REPO/name)} for name in artifacts},
      'runtime_sources':{name:sha(REPO/name) for name in sorted(components)},
      'reports':{name:sha(REPO/name) for name in reports},
      'installer_scenarios':loaded['Install-Polish-V15.validation.json']['scenario_count'],
      'native_studio_tested':False,'official_roblox_offer_ids_configured':False,
      'limits':['Component and installation execution used deterministic Roblox API adapters.',
        'Independent binary decode and original-property preservation do not prove native Studio behavior.',
        'Native multiplayer, rendering, existing animation permissions, purchases and save/rejoin require playtesting.']}
    (REPO/'V15-Release.validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('runtime_sources','reports')},indent=2))
if __name__=='__main__':main()
