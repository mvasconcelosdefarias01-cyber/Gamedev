#!/usr/bin/env python3
"""Original deterministic raster and sound sources for Fazenda Entre Ecos."""
from __future__ import annotations
import argparse, hashlib, json, math, random, subprocess, wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve().parent
OUT = ROOT / 'assets'
PREVIEW = TOOL / 'preview'
SOURCE = TOOL / 'source'
PAL = {'ink':'#243C47','paper':'#F7F4EB','soil':'#AA865F','soil_light':'#C6A57B',
       'soil_dark':'#806044','leaf':'#80916C','leaf_light':'#A8B883','leaf_dark':'#536B50',
       'gold':'#E2B55F','gold_light':'#F2D890','gold_dark':'#AE7B44',
       'water':'#6B9293','water_light':'#A8C9C4','water_dark':'#497578',
       'wood':'#B58A65','wood_light':'#D7AF81','wood_dark':'#745740',
       'stone':'#9BA6A2','stone_light':'#D6D8C9','stone_dark':'#6A7B78',
       'skin':'#D9AC88','skin_light':'#EDD0AA','shirt':'#B5715E','shirt_dark':'#814B47',
       'blue':'#7694B7','linen':'#E0E0CE','violet':'#B2ABC2'}
ASSETS = {}
DIRS = ['S','SW','W','NW','N','NE','E','SE']

def rgba(color, alpha=255):
    if isinstance(color, tuple): return color
    value=PAL.get(color,color).lstrip('#')
    return tuple(int(value[i:i+2],16) for i in (0,2,4))+(alpha,)

def canvas(w,h): return Image.new('RGBA',(w,h),(0,0,0,0))
def rect(draw,box,c): draw.rectangle(box,fill=rgba(c))
def line(draw,points,c,width=1): draw.line(points,fill=rgba(c),width=width)
def poly(draw,pts,c): draw.polygon(pts,fill=rgba(c))
def ell(draw,box,c): draw.ellipse(box,fill=rgba(c))
def outline(draw,box,c='ink',fill=None): draw.rectangle(box,outline=rgba(c),fill=rgba(fill) if fill else None)

def export(asset_id,path,frames,pivot,animations=None,directions=None,extra=None):
    rows=len(directions) if directions else 1
    cols=len(frames)//rows
    w,h=frames[0].size
    sheet=canvas(w*cols,h*rows)
    for i,f in enumerate(frames): sheet.alpha_composite(f,((i%cols)*w,(i//cols)*h))
    dest=OUT/path;dest.parent.mkdir(parents=True,exist_ok=True);sheet.save(dest,optimize=True)
    meta={'id':asset_id,'path':'res://assets/'+path,'frame_size':[w,h],'pivot':list(pivot),
          'columns':cols,'rows':rows,'frame_count':len(frames),
          'animations':animations or {'idle':{'frames':[0],'fps':1,'loop':False}},
          'directions':directions or [],'filter':'nearest','license':'CC0-1.0',
          'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
    if extra:meta.update(extra)
    ASSETS[asset_id]=meta
    dest.with_suffix('.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
    return sheet

def diamond(draw,c,edge='soil_dark',offset=0):
    pts=[(31,offset),(63,15+offset),(32,31+offset),(0,16+offset)]
    poly(draw,pts,c);line(draw,pts+[pts[0]],edge)

def tile(kind,index=0):
    im=canvas(64,32);d=ImageDraw.Draw(im);rng=random.Random(1000+index)
    color={'grass':'leaf','path':'soil_light','soil':'soil','water':'water','stone':'stone'}[kind]
    diamond(d,color,{'grass':'leaf_dark','path':'soil','soil':'soil_dark','water':'water_dark','stone':'stone_dark'}[kind])
    if kind=='soil':
        for k in range(4):line(d,[(10+k*7,15-k*3),(31+k*7,25-k*3)],'soil_dark')
        for k in range(3):line(d,[(12+k*7,13-k*3),(29+k*7,21-k*3)],'soil_light')
    elif kind=='water':
        for x,y in [(15,14),(34,10),(33,23),(48,17)]:line(d,[(x,y),(x+7,y)],'water_light')
    else:
        for _ in range(11):
            x=rng.randrange(10,54);y=rng.randrange(7,25)
            if abs(x-32)/32+abs(y-16)/16<.85:rect(d,(x,y,x+1,y),{'grass':'leaf_light','path':'soil','stone':'stone_light'}[kind])
    return im

def crop(crop_id,stage,phase=0):
    im=canvas(32,40);d=ImageDraw.Draw(im)
    ell(d,(7,32,25,38),(36,60,71,70))
    if stage==0:
        ell(d,(13,30,19,34),'soil_light');rect(d,(15,29,16,30),'wood_dark');return im
    if stage==1:
        line(d,[(16,34),(16,27)],'leaf_dark',2)
        poly(d,[(16,29),(8,25),(10,29),(15,31)],'leaf')
        poly(d,[(16,28),(22,24),(23,27),(17,30)],'leaf_light');return im
    shift=phase if stage>=3 else 0
    def stem(x,y,bottom=35):line(d,[(x,bottom),(x+shift,y)],'leaf_dark',2)
    def leaf(pts,col='leaf'):poly(d,pts,col)
    if crop_id=='C1':
        if stage>=3:
            poly(d,[(9,28),(13,23),(21,24),(24,30),(20,35),(17,38),(14,35)],'ink')
            poly(d,[(11,28),(14,25),(20,25),(22,29),(19,34),(17,36),(15,33)],'linen')
            rect(d,(13,28,16,29),'paper');rect(d,(20,30,21,32),'stone')
        stem(16,20 if stage==2 else 16,28)
        leaf([(16,25),(6,19+shift),(7,15+shift),(11,17+shift),(15,22)],'leaf_light')
        leaf([(16,24),(17,13+shift),(21,12+shift),(21,19+shift)],'leaf')
        leaf([(17,24),(27,17+shift),(26,23+shift),(20,27)],'leaf_dark')
    elif crop_id=='C2':
        stem(15,12 if stage>=3 else 21)
        leaf([(15,28),(7,24),(8,20),(13,22)],'leaf_light')
        leaf([(15,22),(23,17+shift),(25,19+shift),(20,24)],'leaf')
        leaf([(15,18),(9,14+shift),(10,11+shift),(15,14)],'leaf_light')
        if stage>=3:
            line(d,[(22+shift,16),(25+shift,21),(23+shift,26),(20+shift,27)],'gold_dark',3)
            line(d,[(11+shift,20),(8+shift,25),(9+shift,29)],'leaf_light',2)
    elif crop_id=='C3':
        stem(16,5 if stage>=3 else 15)
        leaf([(16,31),(4,26),(3,20),(13,27)],'leaf')
        leaf([(16,23),(25,12+shift),(27,11+shift),(24,21),(17,28)],'leaf_light')
        leaf([(16,17),(9,9+shift),(10,7+shift),(17,14)],'leaf_dark')
        if stage>=3:
            outline(d,(17,18,21,28),fill='gold_dark');rect(d,(17,18,19,25),'gold')
            for y in (19,22,25):rect(d,(18,y,20,y),'gold_light')
            for x in (13,16,19):line(d,[(16,10),(x+shift,4+abs(x-16))],'gold')
    elif crop_id=='C4':
        line(d,[(7,33),(13,27),(25,29)],'leaf_dark',2)
        leaf([(9,30),(3,26),(4,22),(10,25),(15,23),(16,27)],'leaf')
        leaf([(22,26),(25,20),(29,23),(28,28)],'leaf_light')
        if stage>=3:
            ell(d,(10,24,25,35),'ink');ell(d,(11,24,24,34),'gold_dark')
            ell(d,(12,24,20,33),'gold');line(d,[(17,25),(16,30),(17,33)],'gold_light')
            line(d,[(19,25),(21,29),(21,32)],'gold_dark');rect(d,(17,21,19,24),'leaf_dark')
    elif crop_id=='C5':
        for x,top in [(10,15),(16,9),(22,16)]:
            stem(x,top+shift)
            leaf([(x,27),(x-4,23),(x-3,21),(x,24)],'leaf_light')
            if stage>=3:
                ell(d,(x-3,top-3+shift,x+3,top+3+shift),'blue')
                rect(d,(x-1,top-3+shift,x+1,top+3+shift),'violet')
                rect(d,(x-3,top-1+shift,x+3,top+1+shift),'blue');rect(d,(x,top+shift,x,top+shift),'gold_light')
    elif crop_id=='C6':
        line(d,[(13,35),(13,19),(16,10+shift),(21,9+shift),(24,14+shift)],'leaf_dark',2)
        leaf([(13,28),(6,22),(6,18),(12,22)],'leaf')
        leaf([(13,29),(22,25),(24,26),(18,31)],'leaf_light')
        if stage>=3:
            poly(d,[(21,13+shift),(26,13+shift),(29,21+shift),(20,21+shift)],'ink')
            poly(d,[(22,14+shift),(25,14+shift),(27,19+shift),(21,19+shift)],'linen')
            rect(d,(22,20+shift,26,21+shift),'water_light');rect(d,(24,22+shift,24,23+shift),'gold')
    return im

def crop_icon(crop_id):
    im=canvas(24,24);d=ImageDraw.Draw(im)
    if crop_id=='C1':
        poly(d,[(7,11),(12,7),(18,10),(18,17),(13,22),(7,17)],'ink')
        poly(d,[(8,11),(12,9),(16,11),(16,16),(13,20),(9,16)],'linen')
        poly(d,[(11,10),(4,6),(5,3),(10,7)],'leaf');poly(d,[(12,9),(13,2),(17,3),(15,8)],'leaf_light')
    elif crop_id=='C2':
        line(d,[(6,6),(9,3),(17,8),(18,14),(14,21)],'ink',5)
        line(d,[(7,6),(10,5),(15,9),(16,14),(13,19)],'leaf_light',3)
        for p in [(9,7),(12,10),(14,14),(13,17)]:ell(d,(p[0],p[1],p[0]+2,p[1]+2),'leaf')
    elif crop_id=='C3':
        poly(d,[(10,3),(15,4),(18,17),(13,22),(7,19),(7,8)],'leaf_dark')
        poly(d,[(11,4),(14,5),(15,16),(11,20),(8,15),(9,7)],'gold')
        for y in range(6,18,3):rect(d,(10,y,13,y),'gold_light')
        poly(d,[(13,21),(15,14),(20,10),(18,18)],'leaf');poly(d,[(9,21),(4,15),(3,9),(8,15)],'leaf_light')
    elif crop_id=='C4':
        ell(d,(3,8,21,22),'ink');ell(d,(4,8,20,21),'gold_dark');ell(d,(6,9,15,20),'gold')
        line(d,[(12,9),(10,14),(12,19)],'gold_light');line(d,[(15,10),(17,15),(16,19)],'gold_dark')
        rect(d,(11,4,14,8),'leaf_dark');line(d,[(13,4),(17,3),(20,6)],'leaf')
    elif crop_id=='C5':
        for x,y in [(8,8),(15,6),(13,14)]:
            line(d,[(12,23),(x,y)],'leaf_dark')
            for box in [(x-3,y-2,x+3,y+2),(x-2,y-3,x+2,y+3)]:ell(d,box,'blue')
            rect(d,(x,y,x,y),'gold_light')
    else:
        line(d,[(7,22),(8,7),(12,3),(17,4),(19,8)],'leaf_dark',2)
        poly(d,[(16,7),(21,7),(23,16),(13,16)],'ink');poly(d,[(17,8),(20,8),(22,14),(15,14)],'linen')
        rect(d,(15,15,21,16),'water_light');rect(d,(18,17,18,19),'gold')
    return im

def actor(direction,state,frame,shirt='shirt',npc=None,echo=False):
    im=canvas(32,48);d=ImageDraw.Draw(im)
    rear=direction in ('NW','N','NE');side=direction in ('W','E')
    sign=-1 if direction in ('SW','W','NW') else 1
    bob=[0,0,-1,-1,0,0][frame%6] if state=='walk' else (-1 if state=='idle' and frame==1 else 0)
    cx=16;cy=29+bob
    ell(d,(7,42,26,47),(36,60,71,75))
    leg_a=[0,2,2,0,-2,-2][frame%6] if state=='walk' else 0
    rect(d,(11+leg_a,34,14+leg_a,43),'ink');rect(d,(18-leg_a,34,21-leg_a,43),'ink')
    rect(d,(10+leg_a,43,15+leg_a,46),'wood_dark');rect(d,(17-leg_a,43,22-leg_a,46),'wood_dark')
    outline(d,(9,23+bob,23,36+bob),fill=shirt)
    rect(d,(10,24+bob,12,34+bob),{'shirt':'shirt_dark','gold':'gold_dark','blue':'water_dark'}.get(shirt,'shirt_dark'))
    rect(d,(19,24+bob,22,29+bob),shirt)
    rect(d,(13,24+bob,14,35+bob),'wood_light');rect(d,(18,24+bob,19,35+bob),'wood_light')
    rect(d,(13,30+bob,19,36+bob),'leaf_dark')
    rect(d,(12,34+bob,21,36+bob),'ink')
    outline(d,(10,11+bob,22,24+bob),fill='skin')
    rect(d,(11,12+bob,15,20+bob),'skin_light')
    if rear:rect(d,(10,13+bob,22,20+bob),'wood_dark')
    else:
        if side:rect(d,(20,17+bob,20,18+bob),'ink')
        else:
            offset=2 if direction in ('SW','SE') else 0
            rect(d,(13+offset,17+bob,13+offset,18+bob),'ink');rect(d,(19+offset,17+bob,19+offset,18+bob),'ink')
        rect(d,(16,21+bob,17,21+bob),'gold_dark')
    if npc=='Lia':
        rect(d,(9,23+bob,12,39+bob),'blue');rect(d,(21,23+bob,24,39+bob),'blue')
        line(d,[(11,24+bob),(22,35+bob)],'wood_dark',2)
        outline(d,(21,31+bob,28,38+bob),fill='wood');rect(d,(22,32+bob,26,34+bob),'wood_light')
        ell(d,(9,8+bob,23,14+bob),'wood_dark')
    elif npc=='Rui':
        rect(d,(12,25+bob,20,37+bob),'linen');line(d,[(27,43),(28,7),(24,4)],'wood_dark')
        rect(d,(10,9+bob,23,13+bob),'leaf_dark');rect(d,(8,13+bob,25,15+bob),'leaf')
    else:
        poly(d,[(10,9+bob),(21,9+bob),(23,15+bob),(8,15+bob)],'gold_dark')
        rect(d,(10,9+bob,20,13+bob),'wood_light');rect(d,(7,14+bob,25,16+bob),'gold')
        rect(d,(10,14+bob,20,14+bob),'gold_light')
    arm_y=cy+2
    action=state not in ('idle','walk')
    if action:
        arm_y=cy-5+([2,0,5,7,3,2][frame%6])
    rect(d,(7,26+bob,10,arm_y+6),'skin');rect(d,(23,26+bob,26,arm_y+5),'skin')
    if state in ('seed','interact','talk'):
        line(d,[(24,arm_y+3),(27,arm_y+2)],'skin_light',2)
        if state=='seed':rect(d,(27,arm_y+7,28,arm_y+8),'gold')
    elif state=='water':
        outline(d,(24,arm_y,30,arm_y+7),fill='water');line(d,[(28,arm_y+1),(31,arm_y+1),(31,arm_y+3)],'ink')
        if frame>=2:
            for x,y in [(27,arm_y+12),(30,arm_y+14),(24,arm_y+10)]:rect(d,(x,y,x,y+1),'water_light')
    elif state=='harvest':
        angle=[-1,-.3,.6,1.1,.8,.2][frame%6]
        x2=int(23+7*math.sin(angle));y2=int(arm_y+10*math.cos(angle))
        line(d,[(22,arm_y),(x2,y2)],'wood_light',2)
        line(d,[(x2-4,y2-1),(x2+2,y2-3),(x2+5,y2)],'stone_light',2)
    elif not npc:
        line(d,[(11,24+bob),(23,39+bob)],'wood_dark',2);line(d,[(20,36+bob),(25,33+bob)],'stone')
    if side:
        for yy in range(10,40):
            for xx in (7,8):im.putpixel((xx,yy),(0,0,0,0))
        rect(d,(10,23+bob,13,34+bob),'shirt_dark' if shirt=='shirt' else 'wood_dark')
    if direction in ('NW','NE'):
        line(d,[(11,15+bob),(13,23+bob)],'wood_dark',2)
        rect(d,(23,18+bob,24,21+bob),'skin')
    if sign<0:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if echo:
        pix=im.load()
        for y in range(48):
            for x in range(32):
                if pix[x,y][3]:
                    a=0 if (x+y+frame)%11==0 else 145
                    pix[x,y]=rgba('water_light' if (x+y)%4 else 'water',a)
    return im

def state_icon(kind):
    im=canvas(16,16);d=ImageDraw.Draw(im)
    if kind=='dry':
        pts=[(8,1),(3,9),(3,12),(6,14),(10,14),(13,12),(13,9),(8,1)]
        line(d,pts,'ink',3);line(d,pts,'paper');line(d,[(8,5),(6,9),(6,11)],'water_light')
    elif kind=='mature':
        line(d,[(4,13),(12,4)],'ink',3);line(d,[(4,13),(12,4)],'gold')
        for p in [(5,10),(8,7),(11,4)]:
            poly(d,[p,(p[0]-3,p[1]-4),(p[0],p[1]-3),(p[0]+1,p[1]-1)],'gold_light')
            poly(d,[p,(p[0]+4,p[1]+1),(p[0]+3,p[1]+3)],'gold')
    elif kind=='memory':
        line(d,[(2,7),(5,4),(8,7),(11,4),(14,7)],'ink',3)
        line(d,[(2,7),(5,4),(8,7),(11,4),(14,7)],'water_light')
        line(d,[(2,11),(5,8),(8,11),(11,8),(14,11)],'ink',3)
        line(d,[(2,11),(5,8),(8,11),(11,8),(14,11)],'water')
        rect(d,(7,1,8,2),'paper')
    elif kind=='pause':rect(d,(4,3,6,13),'paper');rect(d,(10,3,12,13),'paper')
    elif kind=='coin':
        ell(d,(2,2,14,14),'ink');ell(d,(3,2,13,13),'gold');line(d,[(8,4),(8,11)],'gold_dark');line(d,[(6,6),(10,6)],'gold_light')
    else:
        outline(d,(2,2,13,13),fill='paper');line(d,[(4,8),(7,11),(12,5)],'leaf_dark',2)
    return im

def machine(kind,frame):
    w,h={'sprinkler':(32,32),'collector':(48,40),'seeder':(40,40)}[kind]
    im=canvas(w,h);d=ImageDraw.Draw(im)
    cx=w//2
    ell(d,(cx-12,h-9,cx+12,h-2),(36,60,71,80))
    if kind=='sprinkler':
        poly(d,[(8,24),(16,20),(25,24),(16,29)],'ink')
        poly(d,[(9,24),(16,22),(23,24),(16,27)],'stone')
        rect(d,(14,12,18,24),'water_dark');rect(d,(14,12,16,22),'water_light')
        rect(d,(9,10,23,13),'ink');rect(d,(10,10,21,11),'stone_light')
        rect(d,(15,7,18,11),'gold')
        if frame:
            for sign in [-1,1]:
                points=[(16+sign*6,12),(16+sign*10,7+frame%2),(16+sign*14,11),(16+sign*15,17)]
                line(d,points,'water_light')
                rect(d,(max(0,min(31,16+sign*14)),19+frame,max(0,min(31,16+sign*14)),20+frame),'water')
    elif kind=='collector':
        line(d,[(4,35),(27,23),(45,31)],'stone_dark',2)
        for x,y in [(12,30),(31,33)]:ell(d,(x-3,y-3,x+3,y+3),'ink');rect(d,(x-1,y-1,x+1,y+1),'stone')
        poly(d,[(9,18),(26,10),(39,18),(23,26)],'wood_light')
        poly(d,[(9,18),(23,26),(23,33),(9,25)],'wood_dark')
        poly(d,[(23,26),(39,18),(39,26),(23,33)],'wood')
        line(d,[(10,22),(23,28),(38,22)],'gold_dark')
        line(d,[(34,19),(42,13-frame%3),(45,15-frame%3)],'stone',2)
        if frame:im.alpha_composite(crop_icon('C1').resize((12,12),Image.Resampling.NEAREST),(16,10-frame%2))
    else:
        ell(d,(7,28,14,36),'ink');ell(d,(26,28,33,36),'ink')
        poly(d,[(6,16),(20,8),(34,16),(20,24)],'wood_light')
        poly(d,[(6,16),(20,24),(20,33),(6,25)],'wood_dark')
        poly(d,[(20,24),(34,16),(34,25),(20,33)],'wood')
        poly(d,[(11,16),(20,11),(29,16),(20,20)],'gold_dark')
        for p in [(18,14),(21,16),(22,14)]:rect(d,(p[0],p[1],p[0]+1,p[1]+1),'gold_light')
        line(d,[(30,19),(36,21)],'stone',2)
        pos=[(36,18),(38,21),(36,25),(34,21),(36,18)][frame]
        line(d,[(36,21),pos],'gold',2)
        if frame:rect(d,(21,34+frame%2,22,35+frame%2),'gold')
    return im

def save_manifest():
    OUT.mkdir(parents=True,exist_ok=True)
    payload={'schemaVersion':1,'project':'Fazenda Entre Ecos','producer':'North Asset Forge 2D — local original project',
             'source':'tools/north_asset_forge_2d/forge.py','license':'CC0-1.0','palette':PAL,'assets':ASSETS}
    (OUT/'manifest.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')

def contact_sample():
    PREVIEW.mkdir(parents=True,exist_ok=True)
    im=Image.new('RGBA',(860,470),rgba('paper'));d=ImageDraw.Draw(im)
    d.text((18,12),'FAZENDA ENTRE ECOS - 1 BLOCO / ESTADOS / SILHUETAS',fill=rgba('ink'))
    names=['C1 NABO','C2 FEIJAO','C3 MILHO','C4 ABOBORA','C5 LINHO','C6 FLOR']
    for i,cid in enumerate(['C1','C2','C3','C4','C5','C6']):
        y=38+i*65;d.text((18,y+20),names[i],fill=rgba('ink'))
        for st in range(5):
            x=150+st*115;soil=tile('soil').resize((96,48),Image.Resampling.NEAREST)
            im.alpha_composite(soil,(x-20,y+10));plant=crop(cid,min(st,3),1 if st==4 else 0).resize((48,60),Image.Resampling.NEAREST)
            im.alpha_composite(plant,(x+4,y-14))
        im.alpha_composite(crop_icon(cid).resize((48,48),Image.Resampling.NEAREST),(762,y+6))
    for i,label in enumerate(['Semente','Broto','Crescendo','Madura A','Madura B']):d.text((135+i*115,438),label,fill=rgba('ink'))
    im.save(PREVIEW/'sample_crops.png');im.convert('L').convert('RGBA').save(PREVIEW/'sample_crops_gray.png')
    chars=Image.new('RGBA',(800,520),rgba('paper'));dc=ImageDraw.Draw(chars)
    for i,direction in enumerate(DIRS):
        dc.text((10,i*63+25),direction,fill=rgba('ink'))
        for j,(st,f) in enumerate([('idle',0),('walk',2),('seed',3),('water',3),('harvest',3),('interact',1)]):
            chars.alpha_composite(actor(direction,st,f).resize((48,72),Image.Resampling.NEAREST),(60+j*110,i*63-10))
    chars.save(PREVIEW/'sample_player.png')
    block=Image.new('RGBA',(768,384),rgba('paper'));bd=ImageDraw.Draw(block)
    bd.text((16,12),'Bloco 2x2 - sinais de estado e maquina',fill=rgba('ink'))
    for (x,y),cid,st,icon in [((320,65),'C1',3,'mature'),((384,97),'C2',1,'dry'),((256,97),'C3',2,None),((320,129),'C6',3,'memory')]:
        block.alpha_composite(tile('soil').resize((128,64),Image.Resampling.NEAREST),(x-64,y+40))
        block.alpha_composite(crop(cid,st).resize((64,80),Image.Resampling.NEAREST),(x-32,y-4))
        if icon:block.alpha_composite(state_icon(icon).resize((32,32),Image.Resampling.NEAREST),(x-16,y-36))
    block.alpha_composite(actor('NW','harvest',3).resize((64,96),Image.Resampling.NEAREST),(440,150))
    block.alpha_composite(machine('sprinkler',0).resize((64,64),Image.Resampling.NEAREST),(535,90))
    block.alpha_composite(machine('sprinkler',3).resize((64,64),Image.Resampling.NEAREST),(620,90))
    bd.text((530,163),'Idle',fill=rgba('ink'));bd.text((620,163),'Agua',fill=rgba('ink'))
    bd.text((30,300),'Gota vazada / espiga / ondas: estados nao dependem somente da cor.',fill=rgba('ink'))
    block.save(PREVIEW/'sample_block.png');block.convert('L').convert('RGBA').save(PREVIEW/'sample_block_gray.png')

def sample():
    # Updating the review subset never drops valid full-inventory records.
    if (OUT/'manifest.json').exists():ASSETS.update(json.loads((OUT/'manifest.json').read_text()).get('assets',{}))
    for cid in ['C1','C2','C3','C4','C5','C6']:
        export('crop_'+cid,'crops/crop_'+cid+'.png',[crop(cid,0),crop(cid,1),crop(cid,2),crop(cid,3),crop(cid,3,1)],(16,38),
               {'seed':{'frames':[0],'fps':1,'loop':False},'sprout':{'frames':[1],'fps':1,'loop':False},
                'grow':{'frames':[2],'fps':1,'loop':False},'mature':{'frames':[3,4],'fps':2,'loop':True}})
        export('icon_crop_'+cid,'ui/crop_'+cid+'.png',[crop_icon(cid)],(12,12))
    player_anims={};base=0
    states=[('idle',2,2),('walk',6,10),('seed',4,8),('water',4,8),('harvest',6,12),('interact',3,6)]
    for state,count,fps in states:
        player_anims[state]={'frames':list(range(base,base+count)),'fps':fps,'loop':state in ('idle','walk')};base+=count
    for tag,col in [('', 'shirt'),('_ochre','gold'),('_blue','blue')]:
        frames=[actor(direction,st,i,col) for direction in DIRS for st,n,_ in states for i in range(n)]
        export('player'+tag,'characters/player'+tag+'.png',frames,(16,47),player_anims,DIRS)
    export('plot_empty','terrain/plot_empty.png',[tile('soil')],(32,16))
    wet=tile('soil');wp=wet.load()
    for y in range(32):
        for x in range(64):
            r,g,b,a=wp[x,y]
            if a:wp[x,y]=(int(r*.77),int(g*.78),int(b*.80),a)
    export('plot_wet','terrain/plot_wet.png',[wet],(32,16))
    for k in ['dry','mature','memory','pause','coin','check']:export('state_'+k,'ui/state_'+k+'.png',[state_icon(k)],(8,8))
    export('machine_sprinkler','machines/sprinkler.png',[machine('sprinkler',i) for i in range(5)],(16,28),
           {'idle':{'frames':[0],'fps':1,'loop':False},'active':{'frames':[1,2,3,4],'fps':8,'loop':True}})
    contact_sample();save_manifest()

def structure(kind,restored=True):
    sizes={'house':(192,176),'workshop':(160,144),'cistern':(128,112),'well':(64,80),
           'bridge':(128,80),'channel':(64,32),'field':(128,64),'horta':(128,64),
           'sale_box':(64,64),'block_sign':(32,48),'pier':(128,64),'valve':(32,48),'cupboard':(48,72)}
    w,h=sizes[kind];im=canvas(w,h);d=ImageDraw.Draw(im)
    if kind in ('house','workshop'):
        p=lambda x,y:(int(x*w),int(y*h))
        poly(d,[p(.08,.79),p(.50,.99),p(.98,.79),p(.55,.55)],(36,60,71,60))
        poly(d,[p(.13,.48),p(.52,.65),p(.52,.94),p(.13,.76)],'wood_dark')
        poly(d,[p(.52,.65),p(.89,.47),p(.89,.75),p(.52,.94)],'wood')
        for k in range(6):
            yy=.50+k*.055
            line(d,[p(.14,yy),p(.51,yy+.17)],'wood')
            line(d,[p(.53,yy+.17),p(.88,yy)],'wood_light' if k%2 else 'wood_dark')
        poly(d,[p(.07,.48),p(.46,.12),p(.62,.39),p(.52,.67)],'ink')
        poly(d,[p(.09,.47),p(.46,.15),p(.59,.40),p(.52,.64)],'leaf_dark' if kind=='house' else 'gold_dark')
        poly(d,[p(.46,.12),p(.93,.32),p(.93,.49),p(.52,.67),p(.62,.39)],'ink')
        poly(d,[p(.49,.16),p(.91,.34),p(.91,.47),p(.53,.64),p(.62,.38)],'leaf' if kind=='house' else 'wood')
        for k in range(5):
            line(d,[p(.24+k*.04,.35-k*.035),p(.53+k*.01,.55-k*.029)],'leaf_light' if kind=='house' else 'wood_light')
        for k in range(5):
            line(d,[p(.64+k*.05,.25+k*.021),p(.58+k*.055,.61-k*.026)],'leaf_dark' if kind=='house' else 'wood_dark')
        rect(d,(int(w*.74),int(h*.10),int(w*.82),int(h*.32)),'stone_dark')
        rect(d,(int(w*.74),int(h*.10),int(w*.78),int(h*.28)),'stone')
        outline(d,(int(w*.73),int(h*.08),int(w*.83),int(h*.12)),fill='stone_light')
        poly(d,[p(.59,.71),p(.74,.65),p(.74,.83),p(.59,.90)],'ink')
        if restored:
            poly(d,[p(.60,.72),p(.72,.67),p(.72,.81),p(.60,.87)],'wood_light' if kind=='house' else 'gold')
            line(d,[p(.66,.69),p(.66,.84)],'wood_dark')
            rect(d,(int(w*.69),int(h*.78),int(w*.70),int(h*.79)),'gold_light')
        else:
            poly(d,[p(.61,.72),p(.72,.66),p(.71,.82),p(.60,.87)],'wood_dark')
            line(d,[p(.58,.76),p(.76,.78)],'wood_light',3)
            line(d,[p(.60,.85),p(.75,.70)],'wood_light',3)
            poly(d,[p(.70,.38),p(.83,.43),p(.77,.53),p(.69,.49)],'wood_dark')
        poly(d,[p(.23,.61),p(.38,.67),p(.38,.79),p(.23,.73)],'ink')
        poly(d,[p(.24,.63),p(.37,.68),p(.37,.77),p(.24,.72)],'gold_light' if restored else 'water_dark')
        line(d,[p(.30,.64),p(.30,.74)],'wood_dark')
        line(d,[p(.24,.68),p(.37,.73)],'wood_dark')
        poly(d,[p(.55,.94),p(.76,.84),p(.81,.88),p(.60,.99)],'stone')
        if kind=='workshop' and restored:
            poly(d,[p(.24,.82),p(.43,.73),p(.53,.78),p(.34,.87)],'wood_light')
            line(d,[p(.28,.84),p(.28,.94)],'wood_dark',3);line(d,[p(.48,.80),p(.48,.88)],'wood_dark',3)
            line(d,[p(.34,.79),p(.44,.80)],'stone_dark',2)
        return im
    if kind=='cistern':
        ell(d,(10,91,118,110),(36,60,71,65));rect(d,(24,44,104,91),'stone_dark')
        ell(d,(24,76,104,105),'stone_dark');rect(d,(25,43,63,88),'stone')
        ell(d,(24,27,104,64),'ink');ell(d,(26,28,102,61),'stone_light');ell(d,(34,32,95,55),'water' if restored else 'water_dark')
        line(d,[(43,42),(58,42),(65,45),(82,45)],'water_light' if restored else 'stone')
        for yy in [62,75,88]:line(d,[(26,yy),(48,yy+5),(77,yy+6),(101,yy)],'stone_dark')
        for xx,yy in [(41,63),(65,77),(83,61),(54,87)]:line(d,[(xx,yy),(xx,yy+11)],'stone_light')
        poly(d,[(53,82),(68,80),(68,100),(53,101)],'ink');poly(d,[(55,84),(66,83),(66,98),(55,99)],'gold' if restored else 'wood_dark')
        line(d,[(16,91),(29,84),(43,85)],'water' if restored else 'stone_dark',4)
        line(d,[(88,87),(109,92),(118,89)],'water' if restored else 'stone_dark',4)
        if not restored:line(d,[(76,45),(68,59),(76,65),(71,75)],'ink')
        else:rect(d,(58,89,61,93),'gold_light')
    elif kind=='well':
        ell(d,(8,63,59,78),(36,60,71,65));rect(d,(11,46,52,64),'stone_dark');ell(d,(11,55,52,72),'stone_dark')
        ell(d,(11,38,52,56),'stone_light');ell(d,(16,41,48,52),'water_dark')
        for x in [12,49]:rect(d,(x,16,x+3,56),'wood_dark');rect(d,(x,16,x+1,54),'wood_light')
        poly(d,[(5,17),(29,4),(59,17),(34,30)],'leaf_dark');poly(d,[(7,16),(29,6),(57,17),(34,27)],'leaf')
        line(d,[(12,28),(51,28)],'wood_light',3);line(d,[(31,28),(31,45)],'linen')
        outline(d,(26,44,37,54),fill='wood')
    elif kind in ('bridge','pier'):
        poly(d,[(4,38),(83,0),(124,24),(44,63)],'wood_dark')
        for k in range(11):
            xx=8+k*8;yy=37-k*3
            if restored or kind=='pier' or k not in (4,5,6):
                poly(d,[(xx,yy),(xx+6,yy-3),(xx+43,yy+17),(xx+38,yy+20)],'wood_light' if k%2 else 'wood')
                line(d,[(xx,yy),(xx+38,yy+20)],'wood_dark')
        for x,y in [(10,39),(47,59),(77,6),(117,27)]:rect(d,(x,y-19,x+3,y+3),'wood_dark');rect(d,(x,y-19,x+1,y),'wood_light')
        line(d,[(12,24),(79,-7)],'wood',3);line(d,[(48,44),(117,13)],'wood',3)
        if kind=='pier':line(d,[(112,38),(119,23),(125,25)],'wood_dark',2)
    elif kind=='channel':
        diamond(d,'soil','soil_dark')
        poly(d,[(0,17),(31,1),(38,5),(8,21)],'stone_dark')
        poly(d,[(8,21),(38,5),(45,9),(16,26)],'water' if restored else 'soil_dark')
        line(d,[(15,21),(35,11)],'water_light' if restored else 'soil_light')
        poly(d,[(16,26),(45,9),(51,12),(23,30)],'stone')
    elif kind in ('field','horta'):
        for x,y in [(0,16),(32,0),(64,16),(32,32)]:im.alpha_composite(tile('soil' if restored else 'grass'),(x,y))
        if not restored:
            for xx,yy in [(21,32),(45,15),(75,39),(59,44),(88,19)]:
                poly(d,[(xx,yy),(xx-5,yy-12),(xx-1,yy-9),(xx+2,yy-17),(xx+5,yy-11),(xx+9,yy-9)],'leaf_dark')
    elif kind=='sale_box':
        poly(d,[(8,34),(32,22),(55,34),(32,46)],'wood_light')
        poly(d,[(8,34),(32,46),(32,59),(8,47)],'wood_dark')
        poly(d,[(32,46),(55,34),(55,48),(32,59)],'wood')
        line(d,[(9,41),(32,52),(54,41)],'gold_dark');line(d,[(15,38),(32,29),(46,37)],'wood_dark',2)
        rect(d,(21,5,41,24),'ink');rect(d,(22,6,40,22),'paper')
        im.alpha_composite(state_icon('coin'),(23,7));rect(d,(30,23,33,31),'wood_dark')
    elif kind=='block_sign':
        rect(d,(14,20,18,45),'wood_dark');rect(d,(14,20,15,43),'wood_light')
        outline(d,(2,8,30,25),fill='wood');rect(d,(3,9,28,11),'wood_light')
        line(d,[(7,16),(13,13),(24,16)],'leaf_dark',2);line(d,[(7,19),(13,22),(24,19)],'leaf_light')
    elif kind=='valve':
        rect(d,(14,23,19,44),'stone_dark');rect(d,(14,23,16,43),'stone')
        ell(d,(3,6,29,30),'ink');ell(d,(5,8,27,28),'gold_dark');ell(d,(8,11,24,25),'wood_dark')
        line(d,[(16,8),(16,28)],'gold',3);line(d,[(5,18),(27,18)],'gold',3);ell(d,(12,14,20,22),'gold_light')
    elif kind=='cupboard':
        poly(d,[(5,15),(28,4),(43,12),(20,23)],'wood_light')
        poly(d,[(5,15),(20,23),(20,68),(5,60)],'wood_dark')
        poly(d,[(20,23),(43,12),(43,59),(20,68)],'wood')
        line(d,[(31,18),(31,63)],'wood_dark',2);rect(d,(26,40,28,43),'gold');rect(d,(34,36,36,39),'gold')
        im.alpha_composite(state_icon('memory'),(22,23))
    return im

def prop(kind):
    size=(80,96) if kind in ('tree_oak','tree_fruit') else ((64,64) if kind=='scarecrow' else (48,48))
    im=canvas(*size);d=ImageDraw.Draw(im);w,h=size;cx=w//2
    ell(d,(cx-16,h-9,cx+16,h-2),(36,60,71,55))
    if kind.startswith('tree'):
        rect(d,(34,44,43,90),'wood_dark');rect(d,(34,44,37,88),'wood')
        line(d,[(37,62),(24,49)],'wood_dark',4)
        for box,col in [((11,21,47,63),'leaf_dark'),((28,8,64,56),'leaf_dark'),((38,23,74,65),'leaf_dark'),((11,18,46,56),'leaf'),((29,8,62,52),'leaf'),((40,24,72,59),'leaf'),((15,20,37,38),'leaf_light'),((34,10,55,27),'leaf_light')]:ell(d,box,col)
        for p in [(19,43),(48,29),(58,50),(39,51)]:rect(d,(p[0],p[1],p[0]+3,p[1]+2),'leaf_dark')
        if kind=='tree_fruit':
            for x,y in [(25,35),(43,25),(55,46),(38,47)]:ell(d,(x,y,x+5,y+5),'gold_dark');rect(d,(x,y,x+2,y+1),'gold')
    elif kind in ('bush','grass','fern'):
        if kind=='bush':
            for box,col in [((6,24,27,41),'leaf_dark'),((17,14,38,39),'leaf'),((9,24,28,36),'leaf_light')]:ell(d,box,col)
        else:
            for dx,dy in [(-13,-5),(-9,-19),(0,-28),(9,-21),(16,-11)]:
                poly(d,[(cx,40),(cx+dx,40+dy),(cx+dx+3,40+dy+2),(cx+3,40)],'leaf_light' if dx<0 else 'leaf')
    elif kind in ('rock','smallrock'):
        poly(d,[(8,35),(12,22),(27,19),(39,29),(35,39),(20,44)],'stone_dark')
        poly(d,[(10,34),(14,24),(26,21),(36,29),(20,36)],'stone')
        poly(d,[(14,24),(25,22),(27,28),(18,31)],'stone_light')
    elif kind in ('log','stump'):
        if kind=='log':
            poly(d,[(5,27),(29,14),(41,22),(17,38)],'wood_dark');ell(d,(5,23,20,39),'wood_light');ell(d,(8,26,17,36),'wood_dark');line(d,[(16,25),(36,16)],'wood')
        else:
            rect(d,(14,25,33,38),'wood_dark');ell(d,(13,17,35,31),'wood_light');ell(d,(17,20,31,28),'wood');ell(d,(21,22,28,26),'wood_dark')
    elif kind in ('crate','barrel','sack','basket'):
        if kind=='barrel':
            rect(d,(14,16,34,35),'wood');ell(d,(14,28,34,41),'wood_dark');ell(d,(14,12,34,23),'wood_light')
            line(d,[(14,24),(19,27),(29,27),(34,24)],'stone_dark',2);line(d,[(14,34),(19,37),(29,37),(34,34)],'stone_dark',2)
        elif kind=='sack':
            ell(d,(13,15,35,41),'wood_light');rect(d,(18,10,29,16),'linen');line(d,[(17,17),(31,17)],'wood_dark',2)
            line(d,[(16,22),(15,33)],'gold');line(d,[(31,21),(33,31)],'wood')
        else:
            poly(d,[(8,22),(23,15),(39,23),(24,30)],'wood_light');poly(d,[(8,22),(24,30),(24,41),(8,33)],'wood_dark');poly(d,[(24,30),(39,23),(39,33),(24,41)],'wood')
            line(d,[(9,26),(24,35),(38,27)],'gold_dark');line(d,[(14,21),(24,27),(31,22)],'wood_dark')
    elif kind=='fence':
        for x,y in [(7,23),(39,7)]:rect(d,(x,y,x+4,y+21),'wood_dark');rect(d,(x,y,x+1,y+20),'wood_light')
        line(d,[(10,26),(40,11)],'wood',4);line(d,[(10,38),(40,23)],'wood',4)
    elif kind=='hook':
        outline(d,(9,8,37,37),fill='wood_dark');line(d,[(20,12),(20,24),(23,27),(26,23)],'stone_light',2)
        rect(d,(12,11,14,34),'wood');line(d,[(31,12),(31,19),(33,22)],'stone')
    elif kind=='footprint':
        for x,y in [(13,22),(28,13)]:
            ell(d,(x,y,x+5,y+9),'soil_dark');rect(d,(x+1,y+11,x+4,y+13),'soil_dark')
    elif kind=='ribbon':
        line(d,[(9,11),(27,19),(21,28),(36,34)],'blue',4);line(d,[(11,12),(26,18),(20,27)],'violet')
    elif kind=='wheel':
        ell(d,(8,8,39,40),'wood_dark');ell(d,(12,12,35,36),'soil');line(d,[(23,12),(23,36)],'wood_light',3);line(d,[(12,24),(35,24)],'wood_light',3);ell(d,(20,20,27,28),'gold_dark')
    elif kind=='bird':
        ell(d,(17,26,31,34),'linen');ell(d,(27,22,33,29),'linen');poly(d,[(33,25),(38,27),(33,28)],'gold');line(d,[(21,31),(13,35)],'stone_dark',3);rect(d,(30,24,30,24),'ink')
    elif kind=='butterfly':
        ell(d,(11,15,23,28),'gold');ell(d,(25,15,37,28),'gold_light');line(d,[(24,20),(24,31)],'ink',2)
    elif kind=='pot':
        poly(d,[(12,29),(36,29),(32,42),(17,42)],'shirt_dark');ell(d,(11,24,37,32),'shirt');ell(d,(14,25,34,29),'soil_dark')
        for x,y in [(20,16),(29,13),(23,9)]:line(d,[(23,27),(x,y)],'leaf_dark');ell(d,(x-3,y-3,x+3,y+3),'gold')
    elif kind=='bench':
        poly(d,[(4,27),(30,14),(45,22),(19,35)],'wood_light');line(d,[(9,27),(36,14)],'wood_dark');line(d,[(14,31),(40,18)],'wood_dark')
        for x,y in [(8,28),(31,21)]:rect(d,(x,y,x+3,y+15),'wood_dark')
        line(d,[(4,17),(31,3)],'wood',5);line(d,[(5,19),(5,31)],'wood_dark',2);line(d,[(33,6),(33,21)],'wood_dark',2)
    elif kind=='banner':
        for x in [4,43]:rect(d,(x,6,x+2,45),'wood_dark')
        line(d,[(5,8),(25,14),(44,8)],'linen')
        for x,y,col in [(10,10,'shirt'),(20,13,'gold'),(30,12,'water')]:poly(d,[(x,y),(x+7,y),(x+4,y+12)],col)
    elif kind=='scarecrow':
        rect(d,(29,14,33,60),'wood_dark');line(d,[(9,26),(54,26)],'wood_dark',4)
        poly(d,[(19,23),(43,23),(49,43),(16,43)],'shirt');rect(d,(27,17,36,22),'skin');rect(d,(22,14,42,17),'gold_dark');rect(d,(25,8,37,13),'gold')
        rect(d,(27,40,29,50),'gold_light');rect(d,(35,40,38,50),'gold_light')
    elif kind=='lantern':
        line(d,[(13,40),(13,10),(27,10),(27,16)],'wood_dark',3)
        outline(d,(19,16,34,33),fill='ink');rect(d,(22,19,31,29),'gold');rect(d,(24,20,26,28),'gold_light')
    elif kind=='sign':
        for x in [9,36]:rect(d,(x,24,x+3,45),'wood_dark')
        outline(d,(3,9,44,27),fill='wood_light');line(d,[(8,16),(39,16)],'wood_dark');line(d,[(14,21),(34,21)],'leaf_dark')
    return im

def clue_icon(number):
    im=canvas(24,24);d=ImageDraw.Draw(im)
    if number in (1,5,7,8):
        poly(d,[(4,3),(17,3),(21,7),(21,22),(4,22)],'ink');poly(d,[(5,4),(16,4),(20,8),(20,21),(5,21)],'paper');poly(d,[(16,4),(16,8),(20,8)],'stone')
        if number==7:ell(d,(9,12,16,19),'shirt');rect(d,(11,14,14,16),'gold')
        elif number==5:
            for yy in [8,11,14]:line(d,[(7,yy),(16,yy)],'water_dark')
            poly(d,[(8,18),(15,16),(17,19)],'gold')
        elif number==8:im.alpha_composite(state_icon('memory'),(4,6))
        else:
            line(d,[(7,9),(17,9)],'wood_dark');line(d,[(7,13),(15,13)],'wood_dark');line(d,[(7,17),(12,17)],'wood_dark')
    elif number==2:
        poly(d,[(4,7),(15,2),(20,5),(9,11)],'wood_light');poly(d,[(4,7),(9,11),(9,22),(4,19)],'wood_dark');poly(d,[(9,11),(20,5),(20,16),(9,22)],'wood')
        for yy in [11,14,17]:line(d,[(12,yy),(18,yy-3)],'ink')
    elif number==4:
        line(d,[(4,3),(18,9),(9,15),(19,21)],'ink',6);line(d,[(4,3),(18,9),(9,15),(19,21)],'blue',4)
        line(d,[(4,3),(18,9)],'violet')
    else:
        for yy in [5,11,17]:line(d,[(2,yy),(7,yy-2),(13,yy+1),(21,yy-2)],'ink',3);line(d,[(2,yy),(7,yy-2),(13,yy+1),(21,yy-2)],'water_light')
        if number==6:line(d,[(12,2),(12,21)],'gold_dark')
    return im

def key_image(number):
    im=Image.new('RGBA',(160,90),rgba('leaf_light'));d=ImageDraw.Draw(im)
    rect(d,(0,0,159,25),'paper');poly(d,[(0,24),(27,15),(53,23),(90,14),(121,21),(159,17),(159,31),(0,31)],'leaf')
    rect(d,(0,27,159,89),'leaf_light')
    for x,y in [(14,53),(39,38),(94,66),(120,44)]:im.alpha_composite(tile('grass'),(x,y))
    def mini(obj,pos,scale=.5):
        img=obj.resize((int(obj.width*scale),int(obj.height*scale)),Image.Resampling.NEAREST);im.alpha_composite(img,pos)
    if number==1:
        mini(structure('house'),(11,-4),.5);mini(prop('tree_oak'),(110,13),.65)
        mini(structure('sale_box'),(78,47),.6);im.alpha_composite(clue_icon(1),(117,62))
    elif number==2:
        for pos in [(-10,50),(20,35),(50,20),(80,5)]:mini(structure('channel',False),pos)
        mini(prop('fence'),(70,38),.85)
        for yy in [35,40,45]:line(d,[(90,yy),(99,yy-4)],'ink')
        mini(clue_icon(2),(128,61),1)
    elif number==3:
        for pos in [(-8,62),(24,46),(56,30),(88,14),(120,-2)]:mini(structure('channel'),pos)
        mini(actor('NW','interact',1,echo=True),(76,15),1)
        mini(prop('tree_oak'),(2,3),.7);im.alpha_composite(state_icon('memory'),(112,56))
    elif number==4:
        mini(structure('workshop'),(7,-4),.6);mini(prop('wheel'),(104,38),.9)
        mini(prop('ribbon'),(109,61),.6);mini(clue_icon(4),(125,62),1)
    elif number==5:
        poly(d,[(0,40),(72,10),(159,52),(71,89)],'water')
        for yy in [37,56,72]:line(d,[(4,yy),(42,yy)],'water_light')
        mini(structure('bridge'),(28,20),.7);mini(structure('sale_box'),(118,51),.5)
        mini(clue_icon(5),(109,61),1)
    elif number==6:
        rect(d,(0,34,159,89),'water');line(d,[(0,43),(159,43)],'water_light',2)
        mini(structure('channel',False),(22,43),.7);mini(structure('channel'),(71,11),.7)
        ghost=actor('NE','water',2,echo=True).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        mini(ghost,(79,49),.75);mini(prop('tree_oak'),(2,-12),.65)
        for xx in [20,55,110]:line(d,[(xx,76),(xx+12,76)],'water_light')
    elif number==7:
        rect(d,(0,27,159,89),'wood_dark');rect(d,(12,19,148,85),'wood')
        for yy in [29,45,61,77]:line(d,[(13,yy),(147,yy)],'wood_dark')
        mini(structure('cupboard'),(50,7),1);mini(prop('lantern'),(112,35),.8);mini(clue_icon(7),(24,59),1)
    else:
        mini(structure('cistern'),(30,6),.75)
        for pos in [(-1,64),(31,48),(95,48),(127,64)]:mini(structure('channel'),pos)
        mini(actor('SE','interact',2,echo=True),(107,22),1)
        mini(clue_icon(8),(18,59),1);line(d,[(111,58),(138,58)],'water_light')
    outline(d,(0,0,159,89))
    return im

def portrait(kind):
    im=canvas(80,80);d=ImageDraw.Draw(im)
    ell(d,(4,4,75,75),'leaf_dark');ell(d,(6,6,73,73),'leaf_light')
    poly(d,[(12,77),(19,57),(29,51),(52,51),(62,59),(70,77)],'blue' if kind=='Lia' else 'shirt')
    poly(d,[(24,62),(35,54),(47,55),(56,64),(55,78),(24,78)],'linen' if kind=='Rui' else 'leaf_dark')
    outline(d,(25,20,54,55),fill='skin');rect(d,(27,21,36,44),'skin_light')
    rect(d,(25,22,30,34),'stone_dark' if kind=='Tomas' else 'wood_dark');rect(d,(49,22,54,34),'stone_dark' if kind=='Tomas' else 'wood_dark')
    rect(d,(32,35,35,38),'ink');rect(d,(45,35,48,38),'ink');line(d,[(38,46),(43,46)],'wood_dark')
    if kind=='Tomas':
        poly(d,[(28,43),(35,48),(48,47),(52,42),(50,56),(41,61),(29,54)],'stone')
        rect(d,(28,44,31,47),'stone_light');rect(d,(50,44,52,47),'stone_light');rect(d,(36,47,44,49),'wood_dark')
        poly(d,[(25,24),(28,14),(49,12),(54,25),(49,20),(29,22)],'stone_dark')
        rect(d,(28,17,43,21),'stone_light')
    elif kind=='Lia':
        poly(d,[(23,28),(26,13),(34,8),(49,11),(58,24),(53,25),(48,19),(31,21)],'wood_dark')
        line(d,[(53,26),(57,51)],'wood_dark',5);rect(d,(57,47,62,52),'gold')
        line(d,[(27,55),(59,71)],'wood_dark',4)
    elif kind=='Rui':
        rect(d,(27,12,52,21),'leaf_dark');rect(d,(21,21,59,25),'leaf');rect(d,(25,21,54,22),'leaf_light')
        rect(d,(31,45,49,50),'wood_dark');rect(d,(36,45,43,47),'skin')
    else:
        poly(d,[(25,15),(50,15),(56,28),(20,28)],'gold_dark');rect(d,(27,14,48,23),'wood_light');rect(d,(18,26,61,30),'gold')
    return im

def ui_icon(kind):
    im=canvas(24,24);d=ImageDraw.Draw(im)
    if kind in ('seed','harvest'):
        im.alpha_composite(crop_icon('C1' if kind=='harvest' else 'C2'),(0,0))
    elif kind=='water':
        outline(d,(4,8,15,19),fill='water');line(d,[(14,10),(20,6),(22,9)],'ink',2);line(d,[(4,10),(1,10),(1,15),(4,15)],'stone',2);rect(d,(19,15,20,18),'water_light')
    elif kind=='move':
        for pts in [[(11,1),(7,6),(15,6)],[(11,23),(7,18),(15,18)],[(1,11),(6,7),(6,15)],[(23,11),(18,7),(18,15)]]:poly(d,pts,'ink')
        rect(d,(9,9,13,13),'gold')
    elif kind=='interact':
        outline(d,(3,2,20,21),fill='wood');line(d,[(11,6),(7,6),(7,16),(11,16)],'paper',2);line(d,[(7,11),(11,11)],'paper',2)
    elif kind in ('notebook','save'):
        outline(d,(3,2,21,22),fill='wood_dark' if kind=='notebook' else 'water_dark');rect(d,(6,4,19,20),'paper')
        if kind=='save':rect(d,(7,4,17,9),'gold');rect(d,(8,15,17,20),'stone')
        else:
            for yy in [7,11,15]:line(d,[(9,yy),(17,yy)],'ink')
            line(d,[(5,3),(5,21)],'gold')
    elif kind=='inspect':
        ell(d,(2,2,16,16),'ink');ell(d,(4,4,14,14),'water_light');line(d,[(14,14),(21,21)],'wood_dark',4);line(d,[(6,6),(10,6)],'paper')
    elif kind=='sell':im.alpha_composite(state_icon('coin').resize((24,24),Image.Resampling.NEAREST))
    elif kind=='repair':line(d,[(5,22),(16,5)],'wood_dark',4);poly(d,[(9,5),(16,1),(22,4),(16,9)],'stone');line(d,[(9,4),(17,1)],'stone_light')
    elif kind=='upgrade':
        poly(d,[(3,12),(11,3),(20,12),(16,12),(16,21),(7,21),(7,12)],'ink');poly(d,[(6,11),(11,6),(17,11),(13,11),(13,18),(10,18),(10,11)],'gold')
    elif kind in ('options','tree_Engenho'):
        ell(d,(5,5,19,19),'stone_dark')
        for x,y in [(10,2),(19,10),(10,19),(2,10)]:rect(d,(x,y,x+3,y+3),'stone')
        ell(d,(9,9,15,15),'paper')
    elif kind=='tree_Cultivo':
        poly(d,[(4,18),(5,7),(18,2),(21,11),(16,20)],'leaf_dark');poly(d,[(5,16),(7,8),(17,4),(19,10),(15,18)],'leaf_light');line(d,[(3,22),(17,7)],'ink')
    elif kind=='tree_Escuta':im.alpha_composite(state_icon('memory').resize((24,24),Image.Resampling.NEAREST))
    return im

def full():
    sample()
    for terrain,n in [('grass',6),('path',6),('soil',4),('water',4),('stone',4)]:
        for i in range(n):export(f'terrain_{terrain}_{i+1:02}',f'terrain/{terrain}_{i+1:02}.png',[tile(terrain,i)],(32,16),extra={'terrain_kind':terrain})
    for i in range(12):
        im=tile('grass',i);d=ImageDraw.Draw(im);edge=i%4
        pts=[[(0,16),(31,0),(31,6),(7,19)],[(31,0),(63,16),(57,19),(31,6)],[(63,16),(32,31),(32,25),(57,13)],[(32,31),(0,16),(7,13),(32,25)]][edge]
        poly(d,pts,'soil_light' if i<8 else 'water');line(d,pts[:2],'soil_dark')
        export(f'border_{i+1:02}',f'terrain/border_{i+1:02}.png',[im],(32,16),extra={'edge_direction':['NW','NE','SE','SW'][edge]})
    for name,npc,col in [('Lia','Lia','blue'),('Rui','Rui','shirt')]:
        frames=[actor(dr,st,i,col,npc) for dr in ['S','W','N','E'] for st,count in [('idle',2),('talk',3)] for i in range(count)]
        export('npc_'+name,'characters/npc_'+name+'.png',frames,(16,47),{'idle':{'frames':[0,1],'fps':2,'loop':True},'talk':{'frames':[2,3,4],'fps':4,'loop':True}},['S','W','N','E'])
    frames=[actor(dr,st,i,echo=True) for dr in ['NW','SE'] for st in ['water','harvest','interact'] for i in range(4)]
    export('echo_Tomas','characters/echo_Tomas.png',frames,(16,47),
           {st:{'frames':list(range(i*4,i*4+4)),'fps':4,'loop':True} for i,st in enumerate(['water','harvest','interact'])},['NW','SE'])
    for who in ['player','Lia','Rui','Tomas']:export('portrait_'+who,'portraits/'+who+'.png',[portrait(who)],(40,40))
    for k,pivot in [('sprinkler',(16,28)),('collector',(24,36)),('seeder',(20,36))]:
        export('machine_'+k,'machines/'+k+'.png',[machine(k,i) for i in range(5)],pivot,
               {'idle':{'frames':[0],'fps':1,'loop':False},'active':{'frames':[1,2,3,4],'fps':8,'loop':True}})
    pivots={'house':(96,164),'workshop':(80,135),'cistern':(64,102),'well':(32,72),'bridge':(64,64),'channel':(32,16),
            'field':(64,48),'horta':(64,48),'sale_box':(32,58),'block_sign':(16,45),'pier':(64,55),'valve':(16,44),'cupboard':(24,66)}
    footprints={'house':[3,3],'workshop':[3,2],'cistern':[2,2],'well':[1,1],'bridge':[3,1],'channel':[1,1],
                'field':[2,2],'horta':[2,2],'sale_box':[1,1],'block_sign':[0,0],'pier':[3,1],'valve':[0,0],'cupboard':[1,1]}
    for k in pivots:
        states=[('damaged',False),('restored',True)] if k in ('workshop','cistern','bridge','channel') else ([('locked',False),('open',True)] if k in ('field','horta') else [('',True)])
        for name,rest in states:
            aid=k+('_'+name if name else '');export(aid,'structures/'+aid+'.png',[structure(k,rest)],pivots[k],extra={'footprint_tiles':footprints[k],'structure_state':name})
    props=['tree_oak','tree_fruit','grass','fern','rock','smallrock','stump','log','bush','fence','crate','barrel','hook','footprint','ribbon','wheel','sack','basket','bird','butterfly']
    for k in props:
        im=prop(k);export('prop_'+k,'decoration/'+k+'.png',[im],(im.width//2,im.height-4),extra={'decorative':True})
    for k in ['pot','bench','banner','scarecrow','lantern','sign']:
        im=prop(k);export('cosmetic_'+k,'decoration/cosmetic_'+k+'.png',[im],(im.width//2,im.height-4),extra={'decorative':True,'coin_cost':200})
    for i in range(1,9):
        export(f'clue_P{i}',f'ui/clue_P{i}.png',[clue_icon(i)],(12,12))
        export(f'key_P{i}',f'narrative/key_P{i}.png',[key_image(i)],(80,45))
    for k in ['move','interact','inspect','notebook','seed','water','harvest','sell','repair','upgrade','save','options']:
        export('action_'+k,'ui/action_'+k+'.png',[ui_icon(k)],(12,12))
    for k in ['Cultivo','Engenho','Escuta']:export('tree_'+k,'ui/tree_'+k+'.png',[ui_icon('tree_'+k)],(12,12))
    for n,k in enumerate(['horta','channel','workshop','bridge','field','cistern'],1):
        img=structure(k).copy();img.thumbnail((24,24),Image.Resampling.NEAREST);icon=canvas(24,24);icon.alpha_composite(img,((24-img.width)//2,(24-img.height)//2))
        export(f'repair_R{n}',f'ui/repair_R{n}.png',[icon],(12,12))
    for i in range(3):
        fish=canvas(24,24);fd=ImageDraw.Draw(fish);col=['leaf_light','stone_light','water'][i]
        ell(fd,(3,7,18,17),'ink');ell(fd,(4,8,18,16),col);poly(fd,[(16,12),(22,6),(22,19)],col);rect(fd,(6,10,7,11),'ink');line(fd,[(8,14),(13,14)],'paper')
        export(f'fish_{i+1}',f'ui/fish_{i+1}.png',[fish],(12,12))
    for cid,k in [('wood','log'),('stone','rock'),('fiber','ribbon'),('compost','sack')]:
        img=prop(k);img.thumbnail((24,24),Image.Resampling.NEAREST);export('item_'+cid,'ui/item_'+cid+'.png',[img],(12,12))
    generate_audio();save_manifest();full_contact()

def full_contact():
    imgs=[(aid,Image.open(OUT/meta['path'].removeprefix('res://assets/')).crop((0,0,*meta['frame_size']))) for aid,meta in ASSETS.items() if meta.get('frame_size')]
    cellw,cellh=190,188;cols=6;rows=math.ceil(len(imgs)/cols)
    im=Image.new('RGBA',(cols*cellw,rows*cellh),rgba('paper'));d=ImageDraw.Draw(im)
    for i,(aid,img) in enumerate(imgs):
        x=i%cols*cellw;y=i//cols*cellh
        img.thumbnail((178,158),Image.Resampling.NEAREST);im.alpha_composite(img,(x+(cellw-img.width)//2,y+5))
        d.text((x+6,y+164),aid,fill=rgba('ink'))
    im.save(PREVIEW/'full_inventory.png')
    narrative=Image.new('RGBA',(640,360),rgba('paper'))
    for i in range(4):narrative.alpha_composite(key_image(i+1).resize((320,180),Image.Resampling.NEAREST),((i%2)*320,(i//2)*180))
    narrative.save(PREVIEW/'narrative_P1_P4.png')
    narrative=Image.new('RGBA',(640,360),rgba('paper'))
    for i in range(4):narrative.alpha_composite(key_image(i+5).resize((320,180),Image.Resampling.NEAREST),((i%2)*320,(i//2)*180))
    narrative.save(PREVIEW/'narrative_P5_P8.png')
    buildings=Image.new('RGBA',(720,480),rgba('paper'));bd=ImageDraw.Draw(buildings)
    for i,(k,state) in enumerate([('house',True),('workshop',False),('workshop',True),('cistern',False),('cistern',True),('well',True)]):
        img=structure(k,state);buildings.alpha_composite(img,(i%3*240+(240-img.width)//2,i//3*240+15));bd.text((i%3*240+20,i//3*240+204),k+(' repaired' if state else ' damaged'),fill=rgba('ink'))
    buildings.save(PREVIEW/'structures.png')

def envelope(length,attack=.03,release=.2):
    env=np.ones(length);a=min(length//2,max(1,int(attack*22050)));r=min(length//2,max(1,int(release*22050)))
    env[:a]=np.linspace(0,1,a);env[-r:]=np.linspace(1,0,r);return env

def tone(freq,duration,volume=.15,kind='bell'):
    t=np.arange(round(duration*22050))/22050
    if kind=='bell':s=np.sin(2*np.pi*freq*t)+.22*np.sin(2*np.pi*2*freq*t)+.07*np.sin(2*np.pi*3*freq*t)
    elif kind=='soft':s=np.sin(2*np.pi*freq*t)+.1*np.sin(2*np.pi*2*freq*t)
    else:s=np.sin(2*np.pi*freq*t)+.3*np.sin(2*np.pi*1.5*freq*t)
    return s*volume*envelope(len(t),.025,.22)*np.exp(-t*(1.7 if kind=='bell' else .25))

def audio_export(aid,samples,group,loop=False):
    samples=np.asarray(samples,dtype=np.float64)
    if len(samples)==0 or not np.isfinite(samples).all():raise ValueError(aid)
    peak=float(np.max(np.abs(samples)))
    if peak>.84:samples*=.84/peak;peak=.84
    src=SOURCE/'audio'/group/(aid+'.wav');src.parent.mkdir(parents=True,exist_ok=True)
    # Mono sources intentionally keep spatial playback predictable.
    pcm=(samples*32767).astype('<i2')
    with wave.open(str(src),'wb') as wf:wf.setnchannels(1);wf.setsampwidth(2);wf.setframerate(22050);wf.writeframes(pcm.tobytes())
    dst=OUT/'audio'/group/(aid+('.ogg' if loop else '.wav'));dst.parent.mkdir(parents=True,exist_ok=True)
    if loop:subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(src),'-map_metadata','-1','-c:a','libvorbis','-flags:a','+bitexact','-fflags','+bitexact','-q:a','4',str(dst)],check=True)
    else:dst.write_bytes(src.read_bytes())
    ASSETS[aid]={'id':aid,'path':'res://assets/'+str(dst.relative_to(OUT)),'source':str(src.relative_to(ROOT)),
                 'type':'audio','loop':loop,'bus':{'music':'Music','ambient':'Ambient','machines':'Ambient','ui':'UI'}.get(group,'SFX'),
                 'duration':round(len(samples)/22050,3),'sample_rate':22050,'channels':1,'peak':round(peak,6),
                 'license':'CC0-1.0','sha256':hashlib.sha256(dst.read_bytes()).hexdigest()}

def generate_audio():
    sr=22050;rng=np.random.default_rng(3718)
    for name,duration in [('seed',.20),('water',.50),('grow',.36),('harvest',.26),('sale',.40),('purchase',.48)]:
        t=np.arange(round(duration*sr))/sr
        if name=='seed':s=rng.normal(0,.075,len(t))*np.exp(-t*27)+tone(110,duration,.08,'soft')
        elif name=='water':
            raw=rng.normal(0,.04,len(t));s=np.convolve(raw,np.ones(6)/6,mode='same')*envelope(len(t),.02,.12)
            s+=np.sin(2*np.pi*(500*t+130*t*t))*.018*envelope(len(t))
        elif name=='harvest':s=rng.normal(0,.055,len(t))*np.exp(-t*13)+tone(440,duration,.05)
        else:
            s=np.zeros(len(t));notes={'grow':[440,660],'sale':[523.25,659.25,783.99],'purchase':[392,523.25,659.25]}[name]
            for i,f in enumerate(notes):
                off=int(i*.085*sr);v=tone(f,duration-i*.085,.1);s[off:off+len(v)]+=v
        audio_export('sfx_'+name,s,'cultivation')
    for name in ['sprinkler','collector','seeder']:
        duration=2.;t=np.arange(int(duration*sr))/sr
        if name=='sprinkler':s=rng.normal(0,.008,len(t));s=np.convolve(s,np.ones(6)/6,mode='same')
        else:
            s=np.zeros(len(t))
            for off in np.arange(0,2,.5 if name=='collector' else .4):
                start=int(off*sr);v=tone(140 if name=='collector' else 220,.08,.05,'soft');s[start:start+len(v)]+=v
        # Tiny crossfade makes the sampled loop seam continuous.
        s[-300:]=np.linspace(s[-301],s[0],300)
        audio_export('machine_'+name+'_loop',s,'machines',True)
    for name in ['wind','birds','water']:
        dur=8.;t=np.arange(int(dur*sr))/sr
        s=rng.normal(0,.007,len(t));s=np.convolve(s,np.ones(30 if name=='wind' else 7)/ (30 if name=='wind' else 7),mode='same')
        if name=='wind':s*=.6+.3*np.sin(2*np.pi*t/8)
        elif name=='birds':
            for off in [1.3,3.4,5.9]:
                length=int(.35*sr);tt=np.arange(length)/sr;v=np.sin(2*np.pi*(1450*tt+450*tt*tt))*.018*envelope(length,.05,.12)
                start=int(off*sr);s[start:start+length]+=v
        else:s+=.007*np.sin(2*np.pi*97*t)*np.sin(2*np.pi*.75*t)
        s[-600:]=np.linspace(s[-601],s[0],600)
        audio_export('ambient_'+name,s,'ambient',True)
    for i,name in enumerate(['canal','reflection','letter','final']):
        duration=1.5 if name!='final' else 2.8;s=np.zeros(round(duration*sr))
        for j,f in enumerate([293.66,440,587.33] if name!='final' else [261.63,329.63,392,523.25]):
            off=round((.10+j*.13)*sr);v=tone(f*(1+.01*i),duration-off/sr,.08,'soft');s[off:off+len(v)]+=v
        audio_export('memory_'+name,s,'mystery')
    for name in ['focus','confirm','unavailable','panel']:
        f={'focus':660,'confirm':783.99,'unavailable':196,'panel':523.25}[name]
        audio_export('ui_'+name,tone(f,.10 if name=='focus' else .19,.045,'soft'),'ui')
    # Three original 32-second pentatonic sketches; repeated harmonic phrases, no copied recording.
    for song,root,melody in [('arrival',261.63,[0,2,4,7,4,2,0,9,7,4,2,0,2,4,7,9]),
                              ('restoring',293.66,[0,4,7,9,7,4,2,4,0,2,4,7,9,7,4,2]),
                              ('ending',261.63,[7,9,12,9,7,4,2,0,4,7,9,7,4,2,0,0])]:
        s=np.zeros(32*sr)
        for beat in range(32):
            offset=beat*sr;note=melody[beat%16]
            v=tone(root*2**(note/12),1.8,.045,'bell');end=min(len(s),offset+len(v));s[offset:end]+=v[:end-offset]
            if beat%4==0:
                for sem in [0,7,12]:
                    bass=tone(root/2*2**(sem/12),4.,.018,'soft');end=min(len(s),offset+len(bass));s[offset:end]+=bass[:end-offset]
        # Ease at both boundaries while the game crossfades tracks.
        s[:int(.5*sr)]*=np.linspace(0,1,int(.5*sr));s[-int(.5*sr):]*=np.linspace(1,0,int(.5*sr))
        audio_export('music_'+song,s,'music',True)

def validate():
    manifest=json.loads((OUT/'manifest.json').read_text());errors=[];raster=audio_count=frames=0;audio_checks=[]
    for aid,meta in manifest['assets'].items():
        dest=OUT/meta['path'].removeprefix('res://assets/')
        if not dest.is_file():errors.append(aid+': missing');continue
        if hashlib.sha256(dest.read_bytes()).hexdigest()!=meta['sha256']:errors.append(aid+': hash mismatch')
        if meta.get('type')=='audio':
            audio_count+=1
            check=subprocess.run(['ffprobe','-v','error','-show_entries','stream=sample_rate,channels','-show_entries','format=duration','-of','json',str(dest)],capture_output=True,text=True)
            if check.returncode:errors.append(aid+': invalid audio')
            else:
                info=json.loads(check.stdout);actual=float(info['format']['duration'])
                if abs(actual-meta['duration'])>.1:errors.append(aid+': duration mismatch')
            decoded=subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(dest),'-f','s16le','-ac','1','-ar','22050','-'],capture_output=True)
            if decoded.returncode:errors.append(aid+': decode error')
            else:
                signal=np.frombuffer(decoded.stdout,dtype='<i2').astype(float)/32768
                actual_peak=float(np.max(np.abs(signal))) if len(signal) else 0
                rms=float(np.sqrt(np.mean(signal**2))) if len(signal) else 0
                clipped=int(np.count_nonzero(np.abs(signal)>=.999))
                if actual_peak>=.99 or clipped:errors.append(aid+': decoded clipping')
                if rms==0:errors.append(aid+': silent file')
                audio_checks.append({'id':aid,'decoded_peak':round(actual_peak,6),'rms':round(rms,6),'clipped_samples':clipped,'duration':meta['duration']})
            continue
        raster+=1;fw,fh=meta['frame_size'];cols,rows=meta['columns'],meta['rows'];frames+=meta['frame_count']
        img=Image.open(dest)
        if img.mode!='RGBA':errors.append(aid+': missing RGBA')
        if img.size!=(fw*cols,fh*rows):errors.append(aid+': dimensions')
        if not (0<=meta['pivot'][0]<fw and 0<=meta['pivot'][1]<fh):errors.append(aid+': invalid pivot')
        for k,anim in meta['animations'].items():
            if not anim['frames'] or any(f<0 or f>=cols for f in anim['frames']):errors.append(aid+': animation '+k)
        if not np.asarray(img)[:,:,3].max():errors.append(aid+': empty image')
        if not meta['id'].startswith('key_') and not (np.asarray(img)[:,:,3]==0).any():errors.append(aid+': missing real transparency')
    required={**{f'crop_C{i}':5 for i in range(1,7)},'player':200,'npc_Lia':20,'npc_Rui':20,'echo_Tomas':24,
              'machine_sprinkler':5,'machine_collector':5,'machine_seeder':5}
    for aid,num in required.items():
        if aid not in manifest['assets']:errors.append(aid+': missing required inventory')
        elif manifest['assets'][aid].get('frame_count')!=num:errors.append(aid+': required frame count')
    prefix_counts={'terrain_':24,'border_':12,'icon_crop_':6,'portrait_':4,'clue_':8,'key_':8,'tree_':3,'repair_':6,'action_':12,'cosmetic_':6,'prop_':20}
    for prefix,count in prefix_counts.items():
        actual=sum(k.startswith(prefix) for k in manifest['assets'])
        if actual!=count:errors.append(prefix+': inventory '+str(actual)+' expected '+str(count))
    for aid,size in [('house',[192,176]),('workshop_damaged',[160,144]),('workshop_restored',[160,144]),('cistern_damaged',[128,112]),('cistern_restored',[128,112])]:
        if manifest['assets'].get(aid,{}).get('frame_size')!=size:errors.append(aid+': required size')
    if audio_count!=23:errors.append('audio inventory: '+str(audio_count)+' expected 23')
    for aid in ['music_arrival','music_restoring','music_ending']:
        if manifest['assets'].get(aid,{}).get('duration',0)<30:errors.append(aid+': music too short')
    # Damaged/restored footprints and pivots are identical, independently of visible pixels.
    for st in ['workshop','cistern','bridge','channel']:
        a=manifest['assets'].get(st+'_damaged');b=manifest['assets'].get(st+'_restored')
        if a and b and any(a[k]!=b[k] for k in ['pivot','frame_size','footprint_tiles']):errors.append(st+': repair changes footprint')
    report={'passed':not errors,'raster_assets':raster,'audio_assets':audio_count,'raster_frames_including_shirts':frames,
            'errors':errors,'checks':['PNG bytes and RGBA','real transparency','sheet dimensions','animation indices','pivot bounds','stable repair footprints','SHA-256','audio decoding','audio duration','decoded PCM peak below clipping'],
            'audio_verification':audio_checks,
            'visual_review':'sample contact sheets reviewed by art_design before full; integrated review separate','human_test':'not performed'}
    (TOOL/'validation.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(report,ensure_ascii=False))
    if errors:raise SystemExit(1)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['sample','full','validate'])
    args=p.parse_args()
    if args.command=='sample':sample();print(json.dumps({'stage':'sample','assets':len(ASSETS),'preview':str(PREVIEW)}))
    elif args.command=='full':full();validate()
    else:validate()

if __name__=='__main__':main()
