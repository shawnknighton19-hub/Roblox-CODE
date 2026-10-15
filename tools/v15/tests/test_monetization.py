#!/usr/bin/env python3
"""Execute actual V15 marketplace modules and the uploaded durable receipt function.

Roblox services are deterministic test doubles; this does not simulate a real payment
or prove DataStore/marketplace availability in a published server.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
LUAU = shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'
SOURCES = ['HABMonetizationConfigV15.luau', 'HABPassServiceV15.luau',
           'HABGemPurchasesV15.luau', 'HABExpansionConfigV15.luau',
           'HABHalloweenSettingsV15.luau', 'HABCrateServiceV15.luau']
FIXTURE = 'tools/v15/fixtures/27181_EconomyServiceV9.luau'

def load(name, path):
    return '\nlocal function '+name+'(env)\n' + '''
local game, require, task, script, Enum, warn, print, os = env.game, env.require, env.task, env.script, env.Enum, env.warn, env.print, env.os
''' + (ROOT/path).read_text() + '\nend\n'

economy = (ROOT/FIXTURE).read_text()
begin = economy.index('local function positiveId(n)')
end = economy.index('\n\n\n', economy.index('return (r.savedRevision or -1)>=needed', begin))
receipt = economy[begin:end]
receipt_loader = '''
local function loadReceipt(env)
local E, records, Players, HABSettings = {}, env.records, env.players, env.settings
local os, task, warn = env.os, env.task, env.warn
local MAX=2147483647
local function integer(n) return type(n)=='number' and n==n and n>=0 and n%1==0 and n<=MAX end
local function writable(r) return r and r.ready and not r.closed and not r.lost end
local function touch(r) r.revision+=1 end
local function sync() end
local function save(r) env.save(r) end
''' + receipt + '\nreturn E\nend\n'
source = (HERE/'monetization_fixture.luau').read_text()
source += load('loadIds', 'HABMonetizationConfigV15.luau')
source += load('loadPasses', 'HABPassServiceV15.luau')
source += load('loadGems', 'HABGemPurchasesV15.luau')
source += receipt_loader
source += (HERE/'monetization_cases.luau').read_text()
for file in SOURCES:
    result=subprocess.run([LUAU+'-compile',str(ROOT/file)],capture_output=True,text=True)
    if result.returncode: raise SystemExit(file+'\n'+result.stderr)
with tempfile.TemporaryDirectory() as directory:
    path=Path(directory)/'monetization.luau'
    path.write_text(source)
    result=subprocess.run([LUAU,str(path)],capture_output=True,text=True)
    if result.returncode: raise SystemExit(result.stdout+result.stderr)
    print(result.stdout,end='')
    checks=int(result.stdout.split('MONETIZATION_ASSERTIONS=')[1].splitlines()[0])
report={'assertions':checks,'actual_source_executed':True,'syntax_checked':True,'native_studio_tested':False,
        'coverage':['central zero/invalid/duplicate IDs','verified on-sale metadata and missing product IsForSale field',
                    'ownership failures and late profile delivery','purchase-complete event validation',
                    'zero-ID deferred receipts','single callback rerun/conflict handling','unknown/malformed/absent-player receipts',
                    'profile loading and departed players','durable ledger deduplication/retry/overlap',
                    'lost lease and failed save never acknowledge','loaded prior receipt and max balance handling'],
        'source_sha256':{file:hashlib.sha256((ROOT/file).read_bytes()).hexdigest() for file in SOURCES+[FIXTURE]}}
(ROOT/'MonetizationV15.validation.json').write_text(json.dumps(report,indent=2)+'\n')
