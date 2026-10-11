#!/usr/bin/env python3
"""Portable actual-source Luau regressions; Roblox Studio/live asset fetch is separate."""
from pathlib import Path
import json, subprocess, tempfile, shutil, hashlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
LUAU = shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'

def quote(s):
    level = '=' * 9
    while ']'+level+']' in s: level += '='
    return '['+level+'[' + s + ']'+level+']'

prefix = '\n'.join('local '+name+' = '+quote((ROOT / path).read_text()) for name,path in [
    ('clientSource','AnimateV13.client.luau'),('serverSource','AnimationRuntimeV13.server.luau'),
    ('adapterSource','tools/v13/animation_adapter.luau'),('oldSource','tools/v13/fixtures/Animate-uploaded.luau'),
    ('v5Source','tools/v13/fixtures/Animate-V5.luau')])
body = (HERE / 'animation_fixture.luau').read_text()
with tempfile.TemporaryDirectory() as temporary:
    test = Path(temporary) / 'animations.luau'
    test.write_text(prefix+'\n'+body)
    result = subprocess.run([LUAU,str(test)],text=True,capture_output=True)
    if result.returncode:
        raise SystemExit(result.stdout+result.stderr)
    print(result.stdout,end='')
    checks = int(result.stdout.split('ANIMATION_ASSERTIONS=')[1].splitlines()[0])
report = {'checks':checks,'actual_source_executed':True,'syntax_checked':True,'native_studio_tested':False,
          'coverage':['R6 custom IDs','R15 rig-matched fallback','one failed state isolation','pcall failure','async zero-Length failure',
                      'delayed playable track replacement','server Animator marker','Workspace startup wait','emote/ragdoll priority',
                      'walk/sprint/fall/idle transitions','death/removal cleanup','stale spawn callback','reviewed source/ID preservation']}
for file in ['AnimateV13.client.luau','AnimationRuntimeV13.server.luau','tools/v13/animation_adapter.luau']:
    compiled = subprocess.run([LUAU+'-compile',str(ROOT/file)],capture_output=True,text=True)
    if compiled.returncode: raise SystemExit(compiled.stderr)
report['source_sha256'] = {file:hashlib.sha256((ROOT/file).read_bytes()).hexdigest() for file in ['AnimateV13.client.luau','AnimationRuntimeV13.server.luau','tools/v13/animation_adapter.luau']}
(ROOT/'AnimationV13.validation.json').write_text(json.dumps(report,indent=2)+'\n')
