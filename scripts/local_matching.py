"""Local alpha-aware scoring of a single configured detection reference."""
import cv2
import numpy as np
from PIL import Image


def match_template(query,template,mirror=True):
    query=query.convert('RGB');query.thumbnail((192,192))
    template=template.convert('RGBA');screenshot=np.array(query).astype('float32')
    best=(-1,None,False,0)
    ratio=min(query.width/template.width,query.height/template.height)
    scales=sorted({ratio*k for k in (.35,.5,.7,.85,1.)}|{s for s in (.5,1,1.5,2) if s<=ratio})
    for scale in scales:
        tw,th=round(template.width*scale),round(template.height*scale)
        if min(tw,th)<6 or tw>query.width or th>query.height:continue
        rgba=np.array(template.resize((tw,th),Image.Resampling.BILINEAR))
        if rgba[:,:,:3].std(axis=(0,1)).mean()<3:continue
        for flipped in ((False,True) if mirror else (False,)):
            data=rgba[:,::-1].copy() if flipped else rgba
            mask=data[:,:,3].astype('float32')/255
            if (mask>.1).sum()<16:continue
            scores=cv2.matchTemplate(screenshot,data[:,:,:3].astype('float32'),cv2.TM_SQDIFF_NORMED,mask=mask)
            scores=np.nan_to_num(scores,nan=2,posinf=2,neginf=2)
            minimum,_,where,_=cv2.minMaxLoc(scores)
            score=max(0.,1-float(minimum))
            # A tiny similar-colored fragment is weak evidence for a large selected object/map.
            coverage=tw*th/(query.width*query.height)
            score*=min(1.,coverage/.12)**.5
            if score>best[0]:best=(score,[*where,tw,th],flipped,scale)
    return best
