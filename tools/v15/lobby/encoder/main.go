// Encode only newly generated geometry with the authoritative rbxfile writer.
package main

import (
    "encoding/json"
    "fmt"
    "os"
    "reflect"
    "github.com/robloxapi/rbxfile"
    rbxjson "github.com/robloxapi/rbxfile/json"
    "github.com/robloxapi/rbxfile/rbxl"
)

type Property struct { Type string `json:"type"`; Value interface{} `json:"value"` }
type Node struct { ID string `json:"id"`; Class string `json:"class"`; Properties map[string]Property `json:"properties"`; Children []Node `json:"children"` }
type Document struct { Instances []Node `json:"instances"` }
type Ref struct { Instance *rbxfile.Instance; Key string; Target string }

func main() {
    if len(os.Args)!=3 { panic("usage: geometryrbxl input.json output.rbxl") }
    data,e:=os.ReadFile(os.Args[1]);if e!=nil{panic(e)}
    var document Document;if e=json.Unmarshal(data,&document);e!=nil{panic(e)}
    refs:=map[string]*rbxfile.Instance{};pending:=[]Ref{};count:=0
    var build func(Node)*rbxfile.Instance
    build=func(n Node)*rbxfile.Instance{
        count++
        inst:=rbxfile.NewInstance(n.Class);refs[n.ID]=inst
        for key,p:=range n.Properties {
            if p.Type=="Reference" {
                target,_:=p.Value.(string);pending=append(pending,Ref{inst,key,target});continue
            }
            var v rbxfile.Value
            if p.Type=="Font" {
                f:=p.Value.(map[string]interface{})
                v=rbxfile.ValueFont{Family:rbxfile.ValueContent(f["family"].(string)),Weight:rbxfile.FontWeight(uint16(f["weight"].(float64))),Style:rbxfile.FontStyle(uint8(f["style"].(float64)))}
            }else{
                v=rbxjson.ValueFromJSONInterface(rbxfile.TypeFromString(p.Type),p.Value)
            }
            if v==nil{panic(fmt.Sprintf("unsupported %s.%s type %s",n.Class,key,p.Type))}
            inst.Properties[key]=v
        }
        for _,child:=range n.Children{inst.Children=append(inst.Children,build(child))}
        return inst
    }
    root:=rbxfile.NewRoot()
    for _,n:=range document.Instances{root.Instances=append(root.Instances,build(n))}
    for _,r:=range pending{
        target:=refs[r.Target]
        if r.Target!="" && target==nil{panic("unknown reference "+r.Target)}
        r.Instance.Properties[r.Key]=rbxfile.ValueReference{Instance:target}
    }
    f,e:=os.Create(os.Args[2]);if e!=nil{panic(e)}
    warning,e:=(rbxl.Encoder{Mode:rbxl.Place,Uncompressed:true}).Encode(f,root)
    if e!=nil{panic(e)};if warning!=nil{panic(warning)}
    if e=f.Close();e!=nil{panic(e)}
    input,e:=os.Open(os.Args[2]);if e!=nil{panic(e)}
    decoded,warning,e:=(rbxl.Decoder{Mode:rbxl.Place}).Decode(input)
    if e!=nil{panic(e)};if warning!=nil{panic(warning)}
    verified:=0
    var visit func(*rbxfile.Instance)
    visit=func(n *rbxfile.Instance){verified++;for _,c:=range n.Children{visit(c)}}
    for _,n:=range decoded.Instances{visit(n)}
    if count!=verified{panic("round trip count mismatch")}
    paired:=map[*rbxfile.Instance]*rbxfile.Instance{}
    var pair func(*rbxfile.Instance,*rbxfile.Instance)
    pair=func(a,b *rbxfile.Instance){
        if a.ClassName!=b.ClassName || len(a.Children)!=len(b.Children){panic("roundtrip hierarchy mismatch")}
        paired[a]=b
        for i,c:=range a.Children{pair(c,b.Children[i])}
    }
    if len(root.Instances)!=len(decoded.Instances){panic("roundtrip root mismatch")}
    for i,a:=range root.Instances{pair(a,decoded.Instances[i])}
    checked:=0
    for a,b:=range paired{
        if len(a.Properties)!=len(b.Properties){panic(fmt.Sprintf("roundtrip property count mismatch %s",a.ClassName))}
        for key,av:=range a.Properties{
            bv,exists:=b.Properties[key]
            if !exists{panic("missing roundtrip property "+key)}
            if ref,ok:=av.(rbxfile.ValueReference);ok{
                actual:=bv.(rbxfile.ValueReference)
                if paired[ref.Instance]!=actual.Instance{panic("roundtrip Reference mismatch "+key)}
            }else if av.String()!=bv.String() && !reflect.DeepEqual(av,bv){panic(fmt.Sprintf("roundtrip property mismatch %s.%s expected %s got %s",a.ClassName,key,av.String(),bv.String()))}
            checked++
        }
    }
    fmt.Printf("Encoded and independently decoded %d new instances; %d property values match.\n",count,checked)
}
