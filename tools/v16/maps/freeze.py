"""Publish reviewed map geometry and hash-bound reports for root integration."""
from pathlib import Path
import argparse,hashlib,json,shutil
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[2]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def freeze(scratch):
 scratch=Path(scratch);export=json.loads((scratch/'export-validation.json').read_text());routes=json.loads((scratch/'route-validation.json').read_text());regression=json.loads((scratch/'regression-validation.json').read_text())
 assert export['builderSHA256']==sha(REPO/'MapBuilderV16.luau')
 assert export['geometrySHA256']==sha(scratch/'generated.rbxl')
 assert export['geometryRawSHA256']==routes['geometryRawSHA256']==regression['geometryRawSHA256']==sha(scratch/'generated.raw.json')
 assert routes['mapCount']==15 and regression['rejectedBrokenFixtures']==5
 for name in ['generated.rbxl','export-validation.json','route-validation.json','regression-validation.json']:shutil.copy2(scratch/name,HERE/name)
 manifest={'version':16,'baseSHA256':export['basePlaceSHA256'],'builder':'MapBuilderV16.luau','sourceSHA256':export['builderSHA256'],'geometry':'tools/v16/maps/generated.rbxl','geometry_sha256':export['geometrySHA256'],'backupFolder':'OriginalMaps','newRoots':{'MapLibrary':'ServerStorage','BombTagV6Previews':'ReplicatedStorage','BombTagPreviewGalleryV5':'ReplicatedStorage','Maps':'Workspace'},'archiveOriginal':{'85931':'ServerStorage/MapLibrary','8680':'ReplicatedStorage/BombTagV6Previews','8587':'ReplicatedStorage/BombTagPreviewGalleryV5','3':'Workspace/Maps'},'preservePaths':['Workspace/Lobby','Workspace/ActiveArenaAnchor'],'notes':['All15 map/vote identities retained; original map and voting scripts are unchanged.','Floor direct child and PrimaryPart has topY0 in each template; each direct Spawns folder has16 clear invisible markers.','Two ramp entrances per raised deck, width22–24studs, grades under14degrees. Every pair of spawns connects without jumping in the analytic route check.','Active map preserves configured alias Sky Garden and voted/display identity Sunset Docks, floor top at(0,-27,-190). Anchor mutation belongs to the lobby manifest.','Four folder roots are replaced only after original roots are archived. Builder itself only creates detached instances.','Native geometry and highresolution SurfaceGui lettering only; no scripts, sound IDs, particles, decals or imported art in generated maps.','Preview images are offline renders of generated geometry, not Roblox Studio captures. Live Humanoid and multiplayer playtesting remains necessary.']}
 (HERE/'world-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 validation={'version':16,'baseSHA256':export['basePlaceSHA256'],'builderSHA256':export['builderSHA256'],'geometrySHA256':export['geometrySHA256'],'geometryRoundTrip':export['geometryRoundTrip'],'routes':routes,'mutations':regression,'visualReview':{'offline':True,'fixed':['Coplanar floor shell','Coplanar crossing road paint','Hidden bomb enamel'], 'preview':'MapsV16-Preview.png'},'studioPlaytestRun':False}
 (REPO/'MapsV16.validation.json').write_text(json.dumps(validation,indent=2)+'\n')
 return manifest
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('scratch');a=p.parse_args();print(json.dumps(freeze(a.scratch),indent=2))
