"""Freeze official descriptors needed by V16 map geometry, including Folder.

Input is the rbx-dom reflection database pinned by its content hash. No invented
property defaults or enum ordinals are used in generated binary geometry.
"""
from pathlib import Path
import argparse,base64,hashlib,json,msgpack
HERE=Path(__file__).resolve().parent
EXPECTED='cca78d6aba8d3daadcf129e6a607c48d063aed2fe48948955755c83d83187178'
def freeze(path):
 data=Path(path).read_bytes();assert hashlib.sha256(data).hexdigest()==EXPECTED
 version,classes,enums=msgpack.unpackb(data)
 keep={}
 for name in ['Model','Folder','Part','WedgePart','SurfaceGui','Frame','TextLabel']:
  chain=[];key=name
  while key:
   chain.append(classes[key]);key=classes[key][2]
  props={};defaults={}
  for cls in reversed(chain):props.update(cls[3]);defaults.update(cls[4])
  keep[name]=[name,classes[name][1],None,props,defaults]
 chosen={}
 for cls in keep.values():
  for p in cls[3].values():
   if 'Enum' in p[2]:chosen[p[2]['Enum']]=enums[p[2]['Enum']]
 out={'provenance':{'source':'rbx-dom/rbx_reflection_database/database.msgpack','sha256':EXPECTED,'version':version},'classes':keep,'enums':chosen}
 (HERE/'geometry-schema.json').write_text(json.dumps(out,separators=(',',':'),default=lambda value:base64.b64encode(value).decode() if isinstance(value,bytes) else None)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('database');a=p.parse_args();freeze(a.database)
