#!/usr/bin/env python3
"""Read-only independent decode of original and final binary places, without projection."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('original',type=Path)
parser.add_argument('finished',type=Path)
parser.add_argument('--decoder',type=Path,default=ROOT/'tools/v15/modern-verify/target/release'/('hab-rbxl-verify.exe' if os.name=='nt' else 'hab-rbxl-verify'))
parser.add_argument('--report',type=Path,default=ROOT/'ModernRBXLV15.validation.json')
args=parser.parse_args()

def digest(path):
 return hashlib.sha256(path.read_bytes()).hexdigest()

def decode(path):
 before=digest(path)
 result=subprocess.run([str(args.decoder),str(path)],text=True,capture_output=True)
 if result.returncode: raise SystemExit(result.stderr or result.stdout)
 data=json.loads(result.stdout)
 assert data['read_only'] and data['file_sha256']==before==digest(path), 'Input changed during read-only decoding'
 assert data['instance_count']>0 and data['script_count']==len(data['scripts'])
 return data

original=decode(args.original)
finished=decode(args.finished)
assert original['warnings']==finished['warnings'], 'Final file introduced a new decoder warning'
report={
 'raw_binary_decoded':True, 'input_projection_or_property_removal':False,
 'native_studio_tested':False, 'new_decoder_warnings':False,
 'original':original, 'finished':finished,
 'limitations':['The decoder does not interpret a property type named in warnings; original binary chunks are retained by the packager.',
                'Structural decoding and source hashes do not establish Roblox runtime behavior.'],
 'source_sha256':{str(path.relative_to(ROOT)):digest(path) for path in [
  ROOT/'tools/v15/modern-verify/src/main.rs', ROOT/'tools/v15/modern-verify/Cargo.toml',
  ROOT/'tools/v15/modern-verify/Cargo.lock',Path(__file__).resolve()]},
}
args.report.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({
 'decoder':finished['decoder'], 'original_instances':original['instance_count'],
 'finished_instances':finished['instance_count'], 'original_scripts':original['script_count'],
 'finished_scripts':finished['script_count'], 'unchanged_baseline_warnings':finished['warnings'],
 'finished_sha256':finished['file_sha256'], 'report':str(args.report),
},indent=2))
