"""Paths/tool discovery shared by portable V15 lobby development scripts."""
from pathlib import Path
import os, shutil, tempfile
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
def output_dir(value=None):
 path=Path(value).resolve() if value else Path(tempfile.mkdtemp(prefix='hab-lobby-v15-'))
 path.mkdir(parents=True,exist_ok=True)
 return path

def luau_binary(value=None):
 choices=[value,os.environ.get('LUAU_BINARY'),shutil.which('luau'),str(REPO.parent/'.cloud-tools/bin/luau')]
 for choice in choices:
  if choice and Path(choice).is_file():return str(Path(choice).resolve())
 raise RuntimeError('Luau CLI not found. Set LUAU_BINARY or pass --luau /path/to/luau.')
