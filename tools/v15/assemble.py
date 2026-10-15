"""Build a complete offline Studio installer for the source-verified HABWAS place."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]
FIXTURES=json.loads((ROOT/'fixtures/scripts.json').read_text())
BYREF={x['ref']:x for x in FIXTURES}
REPLACEMENTS={
8417:'HudControllerV15.luau',8432:'SnappyMovementV15.client.luau',
8443:'CarrierPanicV15.client.luau',8444:'StandShopV15.client.luau',
8445:'HABHalloweenEffectsV15.client.luau',8446:'HABCrateShopClientV15.client.luau',
8447:'HABCombatFXV15.client.luau',8448:'HABActionClientV15.client.luau',8449:'HABExpansionClientV15.client.luau',
27147:'HABRendererV15.luau',27151:'HABHalloweenSettingsV15.luau',
27160:'FXCanvasV15.luau',27161:'HABReferenceThemeV15.luau',
27167:'HABExpansionConfigV15.luau',27168:'CombatRulesV15.luau',
27172:'HABCombatHUDV15.luau',27176:'BombServiceV15.luau',
27183:'PracticeServiceV15.luau',27186:'HABCrateServiceV15.luau',
27187:'HABGemPurchasesV15.luau',27189:'HABActionServiceV15.luau',
27190:'HABPassServiceV15.luau',27217:'DodgeIFrameServerV15.server.luau',
}
ADDITIONS=[
('ReplicatedStorage/HABMonetizationConfigV15','HABMonetizationConfigV15.luau'),
('ReplicatedStorage/HABModalV15','HABModalV15.luau'),
('ReplicatedStorage/HABUILayoutV15','HABUILayoutV15.luau'),
('ReplicatedStorage/HABExpansion/HABActionAnimationsV15','HABActionAnimationsV15.luau'),
('ReplicatedStorage/HABExpansion/HABAbilityEffectsV15','HABAbilityEffectsV15.luau'),
('ReplicatedStorage/HABHalloween/HABCleanCosmeticsV15','HABCleanCosmeticsV15.luau'),
]
DISABLES=[8450,8481]
# Runtime boot, dependencies, preserved movement, cosmetics and saved-data guards.
PRESERVE=[8427,8428,8431,8433,8437,8438,8439,8440,8441,8442,8452,8482,
8523,8524,8525,8527,8679,27143,27145,27146,27152,27153,27154,27155,27156,
27157,27158,27159,27162,27163,27164,27165,27177,27178,27179,27180,27181,
27182,27184,27185,27188,27191,27219,27221]

def literal(s):
    for n in range(2,40):
        end=']'+'='*n+']'
        if end not in s:return '['+'='*n+'['+s+end
    raise ValueError('Source cannot be safely quoted')

def lua(v):
    if v is None:return 'nil'
    if v is True:return 'true'
    if v is False:return 'false'
    if isinstance(v,str):return literal(v)
    if isinstance(v,(int,float)):return repr(v)
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    if isinstance(v,dict):return '{'+','.join('[ '+lua(k)+' ]='+lua(x) for k,x in v.items())+'}'
    raise TypeError(type(v))

def compiler():
    return os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile') or '/workspace/.cloud-tools/bin/luau-compile'

def records():
    out=[]
    for ref in list(REPLACEMENTS)+DISABLES+PRESERVE:
        f=BYREF[ref];assert hashlib.sha256((REPO/f['source']).read_bytes()).hexdigest()==f['sha256'],f['path']
        r={'path':f['path'],'class':f['class'],'old':(REPO/f['source']).read_text(),'disabled':f['disabled']}
        if ref in REPLACEMENTS:r['target']=(REPO/REPLACEMENTS[ref]).read_text()
        if ref in DISABLES:r['disable']=True
        out.append(r)
    for path,source in ADDITIONS:
        out.append({'path':path,'class':'ModuleScript','target':(REPO/source).read_text(),'add':True,'config':source=='HABMonetizationConfigV15.luau'})
    return out

def payload():
    return ((ROOT/'installer_head.luau').read_text()+'\nlocal entries='+lua(records())+'\n'
      +'local ConfigAdapter=(function()\n'+(ROOT/'monetization_adapter.luau').read_text()+'\nend)()\n'
      +'local LobbyBuilder=(function()\n'+(REPO/'LobbyBuilderV15.luau').read_text()+'\nend)()\n'
      +(ROOT/'installer_tail.luau').read_text())

def manifest():
    data={'input_sha256':'c354d8c3', 'edits':[], 'additions':[], 'disables':[],
      'workspace_attributes':{'HABPolishVersion':15},'backup_path':'ServerStorage/HABPolishV15FileBackup',
      'lobby_manifest':'tools/v15/lobby/world-manifest.json'}
    # Fixed input identity from independently captured audit; not from a mutable output file.
    audit=json.loads((REPO/'V15-InputAudit.validation.json').read_text())
    data['input_sha256']=audit.get('input_sha256') or audit.get('input',{}).get('sha256')
    assert data['input_sha256'] and len(data['input_sha256'])==64,audit.keys()
    for ref,source in REPLACEMENTS.items():
        f=BYREF[ref];data['edits'].append({'path':f['path'],'source':source,'original_sha256':f['sha256']})
    for path,source in ADDITIONS:data['additions'].append({'path':path,'class':'ModuleScript','source':source})
    for ref in DISABLES:
        f=BYREF[ref];data['disables'].append({'path':f['path'],'original_sha256':f['sha256'],'original_disabled':f['disabled']})
    (ROOT/'place_patch.json').write_text(json.dumps(data,indent=2)+'\n')
    return data

def assemble():
    text=payload();out=REPO/'Install-Polish-V15.command.luau';out.write_text(text)
    subprocess.run([compiler(),'--binary',str(out)],stdout=subprocess.DEVNULL,check=True)
    for name in ['Huss-A-Bomb-V15.txt','Install-Polish-V15.txt']:(REPO/name).write_bytes(text.replace('\n','\r\n').encode())
    data=manifest()
    components=list(REPLACEMENTS.values())+[s for _,s in ADDITIONS]+['LobbyBuilderV15.luau']
    for name in components:subprocess.run([compiler(),'--binary',str(REPO/name)],stdout=subprocess.DEVNULL,check=True)
    report={'status':'passed','bytes':len(text.encode()),'sha256':hashlib.sha256(text.encode()).hexdigest(),
       'changed_scripts':len(REPLACEMENTS),'added_modules':len(ADDITIONS),'disabled_legacy_scripts':len(DISABLES),
       'preserved_source_dependencies':len(PRESERVE),'source_sha256':{n:hashlib.sha256((REPO/n).read_bytes()).hexdigest() for n in components},
       'scope':'Offline syntax checks only; transaction and component behavioral reports are separate.'}
    (ROOT/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='source_sha256'}))
    return text
if __name__=='__main__':assemble()
