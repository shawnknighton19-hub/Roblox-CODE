--!nonstrict
-- HAB_CRATE_GUI_4. Data-only, size-bounded modules; no downloaded code.
local pieces={}
for i=1,4 do
 local child=assert(script.Parent:WaitForChild(string.format('ExtraFXPart%02d',i),20),'Missing VFX data segment')
 pieces[i]=require(child)
 assert(type(pieces[i])=='string' and #pieces[i]<=56000,'Invalid VFX segment')
end
local E=game:GetService('EncodingService')
local H=game:GetService('HttpService')
local packed=E:Base64Decode(buffer.fromstring(table.concat(pieces)))
local size=E:GetDecompressedBufferSize(packed,Enum.CompressionAlgorithm.Zstd)
assert(size==2611230,'VFX archive integrity check failed')
local data=H:JSONDecode(buffer.tostring(E:DecompressBuffer(packed,Enum.CompressionAlgorithm.Zstd)))
assert(type(data)=='table' and data.Version==3,'Invalid VFX archive')
return data

