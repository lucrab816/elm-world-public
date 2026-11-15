"""Deterministic original procedural textures; Python standard library only.
No input images. Seed 153. Run from any directory to reproduce public assets.
"""
from pathlib import Path
import math, random, struct, zlib
ROOT = Path(__file__).resolve().parents[1] / 'project/assets'
def png(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=b''.join(b'\0'+bytes(pixels[y*width*4:(y+1)*width*4]) for y in range(height))
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
def atlas():
    pixels=bytearray(); base=(144,157,96)
    # 64 slices of a continuous 3D grain function, matching shader atlas layout.
    for row in range(1024):
        flipped=1023-row; tile_y,py=divmod(flipped,128)
        for col in range(1024):
            tile_x,px=divmod(col,128); z=(tile_y*8+tile_x)*8/63; x=px*8/127; y=py*8/127
            warp=.32*math.sin(y*.57+z*.9)+.11*math.sin(y*1.7-z*.6)
            phase=x*4.1+z*2.6+warp
            value=1+.022*math.sin(phase)+.012*math.sin(phase*2.13+y*.19)-.025*max(0,math.sin(phase*.63+.7))**18
            pixels.extend((*[round(c*value) for c in base],255))
    png(ROOT/'patio_grain.png',1024,1024,pixels)
def stone(name, polygon):
    rng=random.Random(153); pits=[(rng.randrange(22,106),rng.randrange(35,88),rng.choice((1,2))) for _ in range(13)]
    def inside(x,y):
        result=False; j=len(polygon)-1
        for i,(xi,yi) in enumerate(polygon):
            xj,yj=polygon[j]
            if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi: result=not result
            j=i
        return result
    pixels=bytearray()
    for y in range(128):
        for x in range(128):
            if not inside(x,y): pixels.extend((0,0,0,0)); continue
            edge=not inside(x,y+5); top=not inside(x,y-2)
            shade=-22 if edge else 9 if top else 0
            shade+=2*math.sin(x*.13+y*.17)
            if any((x-a)**2+(y-b)**2<r*r for a,b,r in pits): shade-=10
            pixels.extend((*[int(c+shade) for c in (198,181,147)],255))
    png(ROOT/'build_catalog'/name,128,128,pixels)
if __name__=='__main__':
    atlas()
    stone('limestone.png',[(19,39),(88,30),(114,49),(109,82),(43,99),(13,76)])
    stone('stepping_stone.png',[(31,34),(75,27),(105,43),(114,67),(89,92),(46,101),(16,77),(18,50)])
