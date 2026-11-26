#!/usr/bin/env python3
# Art preview without Xcode: renders the ASCII pixel maps from TownArt.swift using the
# same positions as TownScene. NOT a screenshot of the app (no SpriteKit, approximate night tint).
#   python3 scripts/render-art-preview.py Sources/OddlyTown/Town/TownArt.swift docs/art-preview.png [docs/season-preview.png]
# Panels: L1 day | L3 + all activity features | same at night | L3 without activity. Needs Pillow.
# Optional third path: seasons sheet (spring | summer | autumn / winter | winter night | winter L1),
# using the palettes in TownArt+Seasons.swift next to TownArt.swift and the same snow-cap rule.
import os, re, sys
from PIL import Image
src = open(sys.argv[1]).read()
season_src = open(os.path.join(os.path.dirname(sys.argv[1]), 'TownArt+Seasons.swift')).read()
def season_table(name):
    m = re.search(r'static let %s: \[Character: UInt32\] = \[(.*?)\]' % name, season_src, re.S)
    return {k: int(v,16) for k, v in re.findall(r'"(.)": 0x([0-9A-Fa-f]{6})', m.group(1))}
SEASON_CHANGES = {(se, role): season_table(se + role.capitalize())
                  for se in ('spring','autumn','winter') for role in ('ground','foliage')}
def snow_capped(rs):
    # Same rule as PixelArt.snowCapped: top opaque pixel per column, or the one under an outline.
    g=[list(r) for r in rs]; w=max(map(len,g))
    op=lambda x,y: y<len(g) and x<len(g[y]) and g[y][x]!='.'
    for x in range(w):
        top=next((y for y in range(len(g)) if op(x,y)), None)
        if top is None: continue
        y=top+1 if g[top][x]=='k' else top; n=0
        while n<2 and op(x,y) and g[y][x] not in 'ky': g[y][x]='*'; y+=1; n+=1
    return [''.join(r) for r in g]
SEASON='summer'
def seasonal(rs, p, role):
    # Mirrors TownArt.seasonal: summer = base art; winter adds snow except on the ground.
    if SEASON=='summer' or role is None: return rs, p
    q=dict(p); q.update(SEASON_CHANGES.get((SEASON, role), {}))
    return (snow_capped(rs) if SEASON=='winter' and role!='ground' else rs), q
def rows(name):
    m = re.search(r'static let %s = \[([^\]]*)\]' % name, src)
    return re.findall(r'"([^"]*)"', m.group(1))
pal = {k: int(v,16) for k, v in re.findall(r'"(.)": 0x([0-9A-Fa-f]{6})', src.split('static let palette')[1].split('\n    ]')[0])}
W,H,S = 140,60,2
def ground():
    ins=[2,1,0,0,0,0,0,0,0,0,0,0,0,0,1,3,6]; out=[]
    for r in range(17):
        i=ins[r]; row=''
        for x in range(140):
            if x<i or x>=140-i: c='.'
            elif x==i or x==140-i-1: c='k'
            elif r>=14: c='m' if (x+r)%5==0 else 'M'
            elif r==0: c='L' if (x*11)%13==0 else 'l'
            elif r in (8,11): c='Q' if (x*5+r)%9<4 else ('s' if (x*7+r*3)%23==0 else 'P')
            elif 9<=r<=10: c='s' if (x*7+r*3)%23==0 else 'P'
            elif r==1 and (x*7)%19==0: c='l'
            else: c='G' if (x*13+r*5)%37==0 else 'g'
            row+=c
        out.append(row)
    return out
def outlined(rs):
    # Same rule as TownArt.outlined: 1 px outline outside the silhouette, none under the feet.
    w=max(map(len,rs))+2
    g=[['.']*w]+[list('.'+r.ljust(w-2,'.')+'.') for r in rs]; h=len(g)
    op=lambda x,y:g[y][x]!='.'
    out=[[False]*w for _ in range(h)]; st=[(x,0) for x in range(w)]+[(0,y) for y in range(h)]+[(w-1,y) for y in range(h)]
    while st:
        x,y=st.pop()
        if not(0<=x<w and 0<=y<h) or out[y][x] or op(x,y): continue
        out[y][x]=True; st+=[(x+1,y),(x-1,y),(x,y+1),(x,y-1)]
    res=[r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if out[y][x] and ((x>0 and op(x-1,y)) or (x<w-1 and op(x+1,y)) or (y<h-1 and op(x,y+1)) or (y>0 and op(x,y-1))): res[y][x]='o'
    return [''.join(r) for r in res]
def draw(img, rs, left, base, p=pal, only=None, role=None):
    rs, p = seasonal(rs, p, role)
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
    draw(img, ground(), 0, 0, role='ground')
    tree=rows('treeRows'); draw(img,tree,8-5,12,role='foliage'); draw(img,tree,39-5,12,role='foliage')
    cot=rows('cottageRows'); draw(img,['PP']*6,21,8,role='ground'); draw(img,cot,14,13,role='structure')
    draw(img, rows('mailboxRows'),31,12,role='structure'); draw(img, rows('rockRows'),132,12,role='structure')
    if level3:
        draw(img, rows('youngTreeRows'),74-3,13,role='foliage')
        draw(img, rows('fenceRows'),112,3,role='structure'); draw(img, rows('fenceRows'),123,3,role='structure')
        draw(img, rows('wildflowerRows'),6,2); draw(img, rows('wildflowerRows'),62,2)
        draw(img, rows('lamppostRows'),95,13)
        blue=dict(pal); blue.update({'b':0x5B7FC4,'B':0x3F5E9A,'w':0xEDE7DA,'W':0xD3CABA})
        draw(img,['PP']*6,85,8,role='ground'); draw(img,rows('blueHouseRows'),78,13,blue,role='structure')
        draw(img, rows('wellRows'),62,13,role='structure')
    if activity:
        draw(img,['PP']*6,108,8,role='ground'); draw(img, rows('workshopRows'),99,13,role='structure')
        draw(img, rows('easelRows'),49,12); draw(img, rows('flowerBedRows'),46,9)
        teal=dict(pal); teal.update({'B':0x2F7F7A,'b':0x4FA89F})
        draw(img,['PP']*6,124,8,role='ground'); draw(img, rows('readingNookRows'),118,13,teal,role='structure')
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
    # Default decorations: bench in spot 1, flower box in spot 3.
    draw(img,["MMMMMMMM", "mmmmmmmm", "M......M", "M......M"],30,2)
    draw(img,[".p.Y.v.", "pgYgvgp", "MMMMMMM", ".M...M."],88,2)
    res={'n':0x4A3326,'h':0xF1C7A0,'s':0xE07A5F,'k':0x3D405B,'e':0x2A1F26,'o':0x2A1F26}
    top=["..nnn..", ".nnheh.", "..hhh..", ".sssss.", ".hsssh.", "..sss.."]
    draw(img, outlined(top+["..k.k..",".k...k."]), 39, 6, res)
    res2=dict(res); res2.update({'s':0x4FA3C7,'n':0xC0703A}); draw(img, outlined(top+["..k.k..","..k.k.."]), 65, 6, res2)
    if night:
        px=img.load()
        for y in range(H):
            for x in range(W):
                r,g,b,a=px[x,y]
                if a: px[x,y]=(int(r*.5+41*.5),int(g*.5+51*.5),int(b*.5+107*.5),a)
        for left,rs in [(14,cot),(78,rows('blueHouseRows')),(99,rows('workshopRows')),(118,rows('readingNookRows'))]:
            draw(img, rs, left, 13, {'y':0xFFD36E}, only={'y'})
    return img.resize((W*S,H*S), Image.NEAREST)
out=Image.new("RGBA",(280*2+20, 120*2+20),(236,236,240,255))
dark=Image.new("RGBA",(280,120),(40,44,52,255))
out.paste(scene(False,False), (0,0), scene(False,False))
out.paste(scene(True,True), (300,0), scene(True,True))
out.paste(dark,(0,140)); out.paste(scene(True,True,night=True),(0,140),scene(True,True,night=True))
out.paste(dark,(300,140)); out.paste(scene(True,False),(300,140),scene(True,False))
out.save(sys.argv[2])

if len(sys.argv) > 3:
    def panel(season, night=False, level3=True):
        global SEASON
        SEASON=season; img=scene(level3, level3, night=night); SEASON='summer'
        return img
    sheet=Image.new("RGBA",(280*3+40, 120*2+20),(236,236,240,255))
    cells=[(panel('spring'),0,0),(panel('summer'),300,0),(panel('autumn'),600,0),
           (panel('winter'),0,140),(panel('winter',night=True),300,140),(panel('winter',level3=False),600,140)]
    for img,x,y in cells:
        sheet.paste(dark if (x,y)==(300,140) else Image.new("RGBA",(280,120),(236,236,240,255)),(x,y))
        sheet.paste(img,(x,y),img)
    sheet.save(sys.argv[3])
