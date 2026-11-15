"""Replace embedded A03/A07 PNGs with original deterministic procedural pixels.
Preserves every non-image buffer view byte-for-byte and all geometry/accessors.
No external image sources; material hex names specify the established palette.
"""
import json, math, struct, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'project/assets'
def image_bytes(hex_color, cloth):
    rgb=tuple(int(hex_color[i:i+2],16) for i in (0,2,4)); rows=[]
    for y in range(128):
        row=bytearray([0])
        for x in range(128):
            delta=(.008*math.sin(x*1.5)*math.sin(y*1.5) if cloth else .018*math.sin(x*.22+.3*math.sin(y*.04))+.009*math.sin(x*.51+y*.007))
            row.extend((*[round(c*(1+delta)) for c in rgb],255))
        rows.append(bytes(row))
    def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
def rebuild(path):
    original=path.read_bytes(); n=struct.unpack_from('<I',original,12)[0]
    data=json.loads(original[20:20+n]); start=20+n; size,kind=struct.unpack_from('<II',original,start); binary=original[start+8:start+8+size]
    replacements={}
    for material in data['materials']:
        tex=material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        if not tex: continue
        image=data['images'][data['textures'][tex['index']]['source']]
        replacements[image['bufferView']]=image_bytes(material['name'],material['name']=='F1D6AA')
        image['name']='Public procedural '+material['name']
    packed=bytearray()
    for i,view in enumerate(data['bufferViews']):
        old=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        new=replacements.get(i,old)
        while len(packed)%4: packed.append(0)
        view['byteOffset']=len(packed); view['byteLength']=len(new); packed.extend(new)
        if i not in replacements: assert new==old
    data['buffers'][0]['byteLength']=len(packed)
    while len(packed)%4: packed.append(0)
    meta=json.dumps(data,separators=(',',':')).encode(); meta+=b' '*((-len(meta))%4)
    body=struct.pack('<II',len(meta),0x4e4f534a)+meta+struct.pack('<II',len(packed),0x004e4942)+packed
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+len(body))+body)
    print(path.name, 'replaced images:',len(replacements))
if __name__=='__main__':
    for filename in ('a03_dining_chair.glb','a07_forest_bench.glb'): rebuild(ROOT/filename)
