"""Convert executed Luau geometry to explicit Roblox serialization types.

Uses the pinned authoritative rbx-dom reflection database for enum values,
serialized aliases and defaults. No geometry in existing places is reserialized.
"""
import base64, json, math, struct
from pathlib import Path
SCHEMA=json.loads(Path(__file__).with_name('geometry-schema.json').read_text())
CLASSES,ENUMS=SCHEMA['classes'],SCHEMA['enums']

def descriptor(cls,key):
    while cls:
        data=CLASSES[cls]
        if key in data[3]:return data[3][key]
        cls=data[2]
    raise ValueError(f'Unknown property {cls}.{key}')

def alias(cls,key):
    desc=descriptor(cls,key);behavior=desc[4]
    if 'Alias' in behavior:return alias(cls,behavior['Alias'][0])
    serial=behavior['Canonical'][0]
    if serial=='DoesNotSerialize':return None
    if isinstance(serial,dict):
        if 'SerializesAs' in serial:return serial['SerializesAs']
        if key=='Font':return 'FontFace'
        raise ValueError(f'Unimplemented migration {cls}.{key}: {serial}')
    return key

def encoded_attributes(values):
    def string(v):
        data=v.encode('utf8');return struct.pack('<I',len(data))+data
    out=struct.pack('<I',len(values))
    for key,value in sorted(values.items()):
        out+=string(key)
        if isinstance(value,bool):out+=b'\x03'+bytes([value])
        elif isinstance(value,str):out+=b'\x02'+string(value)
        elif isinstance(value,(int,float)):out+=b'\x06'+struct.pack('<d',value)
        elif value['_kind']=='Vector3':out+=b'\x11'+struct.pack('<fff',value['X'],value['Y'],value['Z'])
        elif value['_kind']=='Color3':out+=b'\x0f'+struct.pack('<fff',value['R'],value['G'],value['B'])
        else:raise ValueError(f'Attribute {key} has unsupported value {value}')
    return base64.b64encode(out).decode()

def prop(cls,key,value):
    target=alias(cls,key)
    if target is None:return None
    dtype=descriptor(cls,key)[2]
    if key=='Font':
        name=value['Name']
        choices={'GothamBold':('GothamSSm',700),'GothamBlack':('GothamSSm',900),'Gotham':('GothamSSm',400),'GothamMedium':('GothamSSm',500),'BuilderSansBold':('BuilderSans',700),'BuilderSans':('BuilderSans',400),'SourceSansBold':('SourceSansPro',700)}
        family,weight=choices[name]
        return target,{'type':'Font','value':{'family':f'rbxasset://fonts/families/{family}.json','weight':weight,'style':0}}
    if 'Enum' in dtype:
        assert value['_kind']=='EnumItem',(cls,key,value)
        return target,{'type':'Token','value':ENUMS[value['EnumType']][1][value['Name']]}
    kind=dtype['Value']
    primitive={'Bool':'Bool','String':'String','Float32':'Float','Float64':'Double','Int32':'Int','Int64':'Int64'}
    if kind in primitive:return target,{'type':primitive[kind],'value':value}
    if kind=='Vector3':out={c.lower():value[c] for c in 'XYZ'}
    elif kind=='Vector2':out={c.lower():value[c] for c in 'XY'}
    elif kind=='Color3':
        if target=='Color3uint8':return target,{'type':'Color3uint8','value':{c.lower():round(max(0,min(1,value[c]))*255) for c in 'RGB'}}
        out={c.lower():value[c] for c in 'RGB'}
    elif kind=='CFrame':out={'position':{c.lower():value['p'][c] for c in 'XYZ'},'rotation':value['m']}
    elif kind=='UDim2':out={c.lower():{'scale':value[c]['Scale'],'offset':value[c]['Offset']} for c in 'XY'}
    elif kind=='UDim':out={'scale':value['Scale'],'offset':value['Offset']}
    elif kind=='Ref':return target,{'type':'Reference','value':str(value['id']) if value else ''}
    else:raise ValueError(f'Unsupported property {cls}.{key} type {kind}')
    return target,{'type':kind,'value':out}

def default_prop(cls,key):
    # Official defaults are flattened onto each concrete class.
    if key=='AttributesSerialize':return {'type':'BinaryString','value':encoded_attributes({})}
    desc=descriptor(cls,key)
    if desc[2].get('Value')=='Ref':return {'type':'Reference','value':''}
    canonical=desc[4].get('Alias',[key])[0]
    default=CLASSES[cls][4].get(canonical)
    assert default is not None,(cls,key,canonical,'Missing default')
    kind,value=next(iter(default.items()))
    if kind=='Enum':return {'type':'Token','value':value}
    if kind=='Ref':return {'type':'Reference','value':''}
    if kind in {'Bool','String'}:return {'type':kind,'value':value}
    if kind in {'Float32','Float64','Int32','Int64'}:return {'type':{'Float32':'Float','Float64':'Double','Int32':'Int','Int64':'Int64'}[kind],'value':value}
    if kind=='Vector3':return {'type':'Vector3','value':dict(zip('xyz',value))}
    if kind=='Vector2':return {'type':'Vector2','value':dict(zip('xy',value))}
    if kind=='Color3':return {'type':'Color3','value':dict(zip('rgb',value))}
    if kind=='Color3uint8':return {'type':'Color3uint8','value':dict(zip('rgb',value))}
    if kind=='CFrame':return {'type':'CFrame','value':{'position':dict(zip('xyz',value[0])),'rotation':[n for row in value[1] for n in row]}}
    if kind=='UDim2':return {'type':'UDim2','value':{'x':dict(zip(['scale','offset'],value[0])),'y':dict(zip(['scale','offset'],value[1]))}}
    if kind=='Font':
        # Reflection font defaults are family/weight/style/cached face id.
        return {'type':'Font','value':{'family':value[0],'weight':value[1],'style':value[2]}}
    raise ValueError(f'Unsupported default {cls}.{key}: {default}')

def convert(document):
    by_class={}
    def node(n):
        properties={}
        for key,value in n['props'].items():
            converted=prop(n['class'],key,value)
            if converted:properties[converted[0]]=converted[1]
        properties['AttributesSerialize']={'type':'BinaryString','value':encoded_attributes(n.get('attributes',{}))}
        out={'id':str(n['id']),'class':n['class'],'properties':properties,'children':[node(c) for c in n.get('children',[])]}
        by_class.setdefault(n['class'],[]).append(out)
        return out
    out={'instances':[node(n) for n in document['instances']]}
    for cls,nodes in by_class.items():
        union=set().union(*(n['properties'] for n in nodes))
        for n in nodes:
            for key in union-n['properties'].keys():n['properties'][key]=default_prop(cls,key)
    return out

if __name__=='__main__':
    import sys
    source=Path(sys.argv[1]);output=Path(sys.argv[2])
    output.write_text(json.dumps(convert(json.loads(source.read_text())),separators=(',',':')))
    print(output)
