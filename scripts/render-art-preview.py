#!/usr/bin/env python3
# Art preview without Xcode: renders the ASCII pixel maps from TownArt.swift using the
# same positions as TownScene. NOT a screenshot of the app (no SpriteKit, approximate night tint).
#   python3 scripts/render-art-preview.py Sources/OddlyTown/Town/TownArt.swift docs/art-preview.png
# Panels: L1 day | L3 + all activity features | same at night | L3 without activity. Needs Pillow.
import re, sys
from PIL import Image
src = open(sys.argv[1]).read()
def rows(name):
    m = re.search(r'static let %s = \[([^\]]*)\]' % name, src)
    return re.findall(r'"([^"]*)"', m.group(1))
pal = {k: int(v,16) for k, v in re.findall(r'"(.)": 0x([0-9A-Fa-f]{6})', src.split('static let palette')[1].split('\n    ]')[0])}
W,H,S = 140,60,3
def ground():
    ins=[2,1,0,0,0,0,0,0,0,0,0,0,0,0,1,3,6]; out=[]
    for r in range(17):
        i=ins[r]; row=''
        for x in range(140):
            if x<i or x>=140-i: c='.'
            elif x==i or x==140-i-1: c='k'
            elif r>=14: c='m' if (x+r)%5==0 else 'M'
            elif r==0: c='l'
            elif 8<=r<=11: c='s' if (x*7+r*3)%23==0 else 'P'
            else: c='G' if (x*13+r*5)%37==0 else 'g'
            row+=c
        out.append(row)
    return out
def draw(img, rs, left, base, p=pal, only=None):
    h=len(rs)
    for ry,row in enumerate(rs):
        for rx,ch in enumerate(row):
            if only and ch not in only: continue
            if ch in p:
                x=int(left)+rx; y=H-1-(int(base)+h-1-ry)
                if 0<=x<W and 0<=y<H: img.putpixel((x,y),(p[ch]>>16,(p[ch]>>8)&255,p[ch]&255,255))
def scene(level3=True, activity=True, night=False):
    img=Image.new('RGBA',(W,H),(0,0,0,0))
    draw(img, rows('sunRows') if not night else rows('moonRows'), 126, 49, pal if not night else {'c':0xF4F1DE})
    draw(img, rows('cloudRows'), 18, 47); draw(img, rows('smallCloudRows'), 82, 53)
    draw(img, ground(), 0, 0)
    tree=rows('treeRows'); draw(img,tree,8-5,12); draw(img,tree,39-5,12)
    cot=rows('cottageRows'); draw(img,['PP']*6,21,8); draw(img,cot,14,13)
    draw(img, rows('mailboxRows'),31,12); draw(img, rows('rockRows'),132,12)
    if level3:
        draw(img, rows('youngTreeRows'),74-3,13)
        draw(img, rows('fenceRows'),112,3); draw(img, rows('fenceRows'),123,3)
        draw(img, rows('wildflowerRows'),6,2); draw(img, rows('wildflowerRows'),62,2)
        draw(img, rows('lamppostRows'),95,13)
        blue=dict(pal); blue.update({'r':0x5B7FC4,'R':0x3F5E9A})
        draw(img,['PP']*6,85,8); draw(img,cot,78,13,blue)
        draw(img, rows('wellRows'),62,13)
    if activity:
        draw(img,['PP']*6,108,8); draw(img, rows('workshopRows'),99,13)
        draw(img, rows('easelRows'),49,12); draw(img, rows('flowerBedRows'),46,9)
        teal=dict(pal); teal.update({'B':0x2F7F7A,'b':0x4FA89F})
        draw(img,['PP']*6,124,8); draw(img, rows('readingNookRows'),118,13,teal)
        pole=['kk']+['MM']*23; draw(img,pole,2,13); draw(img,pole,136,13)
        cols=[0xD0644A,0xF6D55C,0x5B8FD0,0xF29AB5,0xF2A541,0x9B6BD3]; w=134; mid=(w-1)/2
        sag=lambda x:int(round((1-((x-mid)/mid)**2)*3))
        for x in range(w):
            for y in range(7):
                c=None
                if y==sag(x): c=0x3B2A33
                else:
                    slot,off=x//7,x%7
                    if 1<=off<=3:
                        ay=sag(slot*7+2)
                        if y==ay+1 or (y==ay+2 and off==2): c=cols[slot%6]
                if c is not None:
                    px=3+x; py=H-1-(30+6-y)
                    img.putpixel((px,py),(c>>16,(c>>8)&255,c&255,255))
    res={'n':0x4A3326,'h':0xF1C7A0,'s':0xE07A5F,'k':0x3D405B}
    top=[".nnn.", "nnhhh", ".hhh.", "sssss", "hsssh", ".sss."]
    draw(img, top+[".k.k.","k...k"], 28, 6, res)
    res2=dict(res); res2.update({'s':0x81B29A,'n':0xC0703A}); draw(img, top+[".k.k.",".k.k."], 98, 6, res2)
    if night:
        px=img.load()
        for y in range(H):
            for x in range(W):
                r,g,b,a=px[x,y]
                if a: px[x,y]=(int(r*.5+41*.5),int(g*.5+51*.5),int(b*.5+107*.5),a)
        for left,rs in [(14,cot),(78,cot),(99,rows('workshopRows')),(118,rows('readingNookRows'))]:
            draw(img, rs, left, 13, {'y':0xFFD36E}, only={'y'})
    return img.resize((W*S,H*S), Image.NEAREST)
out=Image.new('RGBA',(420*2+20, 180*2+20),(236,236,240,255))
dark=Image.new('RGBA',(420,180),(40,44,52,255))
out.paste(scene(False,False), (0,0), scene(False,False))
out.paste(scene(True,True), (440,0), scene(True,True))
out.paste(dark,(0,200)); out.paste(scene(True,True,night=True),(0,200),scene(True,True,night=True))
out.paste(dark,(440,200)); out.paste(scene(True,False),(440,200),scene(True,False))
out.save(sys.argv[2])
