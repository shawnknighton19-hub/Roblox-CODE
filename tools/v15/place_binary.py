"""Inspect and surgically patch a single Source string in a Roblox binary place.
Untouched chunks are preserved byte-for-byte, including unknown properties.
"""
from pathlib import Path
import struct, json, hashlib, sys
import zstandard as zstd

class Reader:
    def __init__(self,data): self.data=data; self.off=0
    def read(self,n):
        out=self.data[self.off:self.off+n]; assert len(out)==n; self.off+=n; return out
    def u32(self): return struct.unpack('<I',self.read(4))[0]
    def byte(self): return self.read(1)[0]
    def string(self): return self.read(self.u32())
    def refs(self,n):
        data=self.read(n*4); result=[]; last=0
        for i in range(n):
            v=int.from_bytes(bytes(data[j*n+i] for j in range(4)), 'big')
            delta=(v>>1)^-(v&1); last+=delta; result.append(last)
        return result

class Place:
    def __init__(self,path):
        self.path=Path(path); self.data=self.path.read_bytes(); self.chunks=[]; self.classes={};self.instances={};self.source_chunks={}
        assert self.data[:14]==b'<roblox!\x89\xff\r\n\x1a\n'
        assert struct.unpack_from('<H',self.data,14)[0]==0
        self.class_count,self.instance_count=struct.unpack_from('<II',self.data,16)
        off=32
        while off<len(self.data):
            start=off;typ,compressed_len,raw_len,reserved=struct.unpack_from('<4sIII',self.data,off); off+=16
            stored=self.data[off:off+(compressed_len or raw_len)];off+=len(stored)
            if compressed_len:
                assert stored[:4]==b'\x28\xb5\x2f\xfd',f'unsupported compression {stored[:4].hex()}'
                raw=zstd.ZstdDecompressor().decompress(stored,max_output_size=raw_len)
            else: raw=stored
            assert len(raw)==raw_len
            chunk={'type':typ,'raw':raw,'start':start,'end':off,'reserved':reserved,'compressed':bool(compressed_len),'bytes':self.data[start:off]}
            self.chunks.append(chunk)
            reader=Reader(raw)
            if typ==b'INST':
                class_id=reader.u32(); name=reader.string().decode(); fmt=reader.byte(); count=reader.u32(); refs=reader.refs(count)
                self.classes[class_id]={'name':name,'format':fmt,'refs':refs}
                for ref in refs: self.instances[ref]={'class':name,'name':name,'parent':None,'props':{}}
            elif typ==b'PROP':
                class_id=reader.u32();name=reader.string().decode();dtype=reader.byte();refs=self.classes[class_id]['refs']
                chunk.update({'class_id':class_id,'property':name,'dtype':dtype,'payload_offset':reader.off})
                if dtype==1:
                    values=[reader.string() for _ in refs]
                    assert reader.off==len(raw)
                    for ref,val in zip(refs,values):
                        self.instances[ref]['props'][name]=val
                        if name=='Name':self.instances[ref]['name']=val.decode()
                    if name=='Source':
                        for i,ref in enumerate(refs):self.source_chunks[ref]=(len(self.chunks)-1,i,values)
                elif dtype==2:
                    values=list(reader.read(len(refs)))
                    for ref,val in zip(refs,values): self.instances[ref]['props'][name]=bool(val)
            elif typ==b'PRNT':
                version=reader.byte();assert version==0
                count=reader.u32();refs=reader.refs(count);parents=reader.refs(count)
                assert reader.off==len(raw)
                for ref,parent in zip(refs,parents):self.instances[ref]['parent']=parent
            elif typ==b'END\x00': assert raw==b'</roblox>' and off==len(self.data)
        assert off==len(self.data);assert len(self.instances)==self.instance_count;assert len(self.classes)==self.class_count
    def path_of(self,ref):
        obj=self.instances[ref]; parent=obj['parent'];return (self.path_of(parent)+'/' if parent in self.instances else '')+obj['name']
    def extract(self,dest):
        dest=Path(dest);dest.mkdir(parents=True,exist_ok=True)
        scripts=[]
        for ref,(ci,idx,values) in self.source_chunks.items():
            obj=self.instances[ref];path=self.path_of(ref);file=dest/(str(ref)+'_'+obj['name']+'.luau');file.write_bytes(values[idx]);scripts.append({'ref':ref,'path':path,'class':obj['class'],'bytes':len(values[idx]),'file':str(file),'disabled':obj['props'].get('Disabled')})
        (dest/'scripts.json').write_text(json.dumps(scripts,indent=2))
        hierarchy=[{'ref':ref,'path':self.path_of(ref),'class':obj['class']} for ref,obj in self.instances.items()]
        (dest/'hierarchy.json').write_text(json.dumps(hierarchy,indent=2))
        return scripts
    def patch(self,target_path,source_file,output):
        refs=[ref for ref in self.source_chunks if self.path_of(ref)==target_path];assert len(refs)==1,refs
        ref=refs[0];ci,idx,values=self.source_chunks[ref];chunk=self.chunks[ci];src=Path(source_file).read_bytes();values=values.copy();values[idx]=src
        new_raw=chunk['raw'][:chunk['payload_offset']]+b''.join(struct.pack('<I',len(value))+value for value in values)
        compressed=zstd.ZstdCompressor(level=3).compress(new_raw)
        replacement=struct.pack('<4sIII',chunk['type'],len(compressed),len(new_raw),chunk['reserved'])+compressed
        out=self.data[:chunk['start']]+replacement+self.data[chunk['end']:]
        output=Path(output);assert output.resolve()!=self.path.resolve();assert not output.exists(),'Refuse to overwrite existing output';output.write_bytes(out)
        revised=Place(output);assert len(self.chunks)==len(revised.chunks)
        changed=[i for i,(a,b) in enumerate(zip(self.chunks,revised.chunks)) if a['bytes']!=b['bytes']];assert changed==[ci]
        assert self.data[:32]==revised.data[:32]
        assert set(self.instances)==set(revised.instances)
        for instance_ref,obj in self.instances.items():
            new_obj=revised.instances[instance_ref]
            assert obj['name']==new_obj['name'] and obj['parent']==new_obj['parent'] and obj['class']==new_obj['class']
            for prop,val in obj['props'].items():assert new_obj['props'][prop]==(src if instance_ref==ref and prop=='Source' else val),(instance_ref,prop)
        report={'original':str(self.path),'output':str(output),'changed_path':target_path,'changed_property':'Source','changed_chunk':ci,'chunks_preserved_byte_for_byte':len(self.chunks)-1,'instances':len(self.instances),'original_sha256':hashlib.sha256(self.data).hexdigest(),'output_sha256':hashlib.sha256(out).hexdigest(),'source_sha256':hashlib.sha256(src).hexdigest(),'verified':True}
        output.with_suffix('.validation.json').write_text(json.dumps(report,indent=2));return report

if __name__=='__main__':
    place=Place(sys.argv[2])
    if sys.argv[1]=='inspect': print(json.dumps(place.extract(sys.argv[3]),indent=2))
    elif sys.argv[1]=='patch': print(json.dumps(place.patch(sys.argv[3],sys.argv[4],sys.argv[5]),indent=2))
