"""Map-local red arrow shape evidence with per-component rejection diagnostics."""
from functools import lru_cache
from pathlib import Path
import cv2
import numpy as np


def _normalized(mask):
    points=cv2.findNonZero(mask)
    if points is None:
        return None
    x,y,w,h=cv2.boundingRect(points)
    return cv2.resize(mask[y:y+h,x:x+w],(32,32),interpolation=cv2.INTER_NEAREST)>0


ROOT=Path(__file__).resolve().parents[1]


def arrow_models():
    folder=ROOT/'public/world_map_arrow_live'
    signature=tuple((str(p),p.stat().st_mtime_ns,p.stat().st_size) for p in sorted(folder.glob('*.png')) if not p.is_symlink())
    return _arrow_models(signature)


@lru_cache(maxsize=4)
def _arrow_models(signature):
    models=[]
    for path,_,_ in signature:
        image=cv2.imread(path,cv2.IMREAD_COLOR)
        if image is None:
            continue
        hsv=cv2.cvtColor(image,cv2.COLOR_BGR2HSV)
        red=((hsv[:,:,0]<=12)|(hsv[:,:,0]>=168))&(hsv[:,:,1]>=150)&(hsv[:,:,2]>=210)
        if np.count_nonzero(red)<35:
            continue
        # Use the actual dominant rendered fill, not labels or background.
        colors,counts=np.unique(image[red],axis=0,return_counts=True)
        fill=colors[counts.argmax()]
        same=np.max(np.abs(image.astype(np.int16)-fill.astype(np.int16)),axis=2)<=12
        mask=np.uint8(red & same)*255
        count,labels,stats,_=cv2.connectedComponentsWithStats(mask)
        if count<2:
            continue
        index=1+int(np.argmax(stats[1:,cv2.CC_STAT_AREA]))
        x,y,w,h,pixels=stats[index]
        if pixels<35 or not .65<=w/h<=1.5:
            continue
        isolated=np.uint8(labels==index)*255
        contours,_=cv2.findContours(isolated,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
        contour=max(contours,key=cv2.contourArea)
        models.append(dict(shape=_normalized(isolated),contour=contour,
                           fill=fill.astype(np.int16),aspect=float(w/h),name=Path(path).name))
    return models


def _same(a,b):
    iw=max(0,min(a['x']+a['w'],b['x']+b['w'])-max(a['x'],b['x']))
    ih=max(0,min(a['y']+a['h'],b['y']+b['h'])-max(a['y'],b['y']))
    small=min(a['w']*a['h'],b['w']*b['h'])
    return iw*ih>.5*small and abs(a['ax']-b['ax'])<.4*max(a['w'],b['w']) and abs(a['ay']-b['ay'])<.4*max(a['h'],b['h'])


def find_arrows(query,ui_scale,occluded=None):
    hsv=cv2.cvtColor(query,cv2.COLOR_BGR2HSV)
    broad=cv2.inRange(hsv,np.array([0,150,140]),np.array([12,255,255])) | cv2.inRange(hsv,np.array([168,150,140]),np.array([180,255,255]))
    core=cv2.inRange(hsv,np.array([0,150,210]),np.array([12,255,255])) | cv2.inRange(hsv,np.array([168,150,210]),np.array([180,255,255]))
    models=arrow_models()
    if not models:
        return [],[dict(x=0,y=0,w=0,h=0,accepted=False,reason='Complete arrow references unavailable')]
    shapes=[model['shape'] for model in models]
    accepted=[];diagnostics=[]
    for tier,red in (('bright core',core),('broad red',broad)):
        red[:round(90*ui_scale),max(0,red.shape[1]-round(48*ui_scale)):]=0
        if occluded is not None:
            red[occluded>0]=0
        contours,_=cv2.findContours(red,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            x,y,w,h=cv2.boundingRect(contour);area=cv2.contourArea(contour)
            # Skip only insignificant noise in preview output, not genuine candidates.
            if area<4*ui_scale*ui_scale:
                continue
            row=dict(x=x,y=y,w=w,h=h,tier=tier,area=round(area,1),accepted=False,reference_count=len(models))
            reasons=[]
            if not (8*ui_scale<=w<=100*ui_scale and 8*ui_scale<=h<=110*ui_scale):
                reasons.append('size')
            if not 35*ui_scale*ui_scale<=area<=5000*ui_scale*ui_scale:
                reasons.append('red area')
            if not .65<=w/h<=1.5:
                reasons.append('aspect')
            if reasons:
                row['reason']=', '.join(reasons);diagnostics.append(row);continue
            hull=cv2.convexHull(contour)
            solidity=area/max(1.,cv2.contourArea(hull));fill=area/(w*h)
            polygon=cv2.approxPolyDP(contour,.025*cv2.arcLength(contour,True),True)
            row.update(solidity=round(solidity,3),fill=round(fill,3),vertices=len(polygon))
            patch=np.zeros((h,w),np.uint8)
            shifted=contour-np.int32([[[x,y]]])
            cv2.drawContours(patch,[shifted],-1,255,-1)
            normalized=_normalized(patch)
            overlaps=[float(np.count_nonzero(normalized & shape))/max(1,np.count_nonzero(normalized | shape)) for shape in shapes]
            model=models[int(np.argmax(overlaps))]
            best_shape=model['shape']
            iou=max(overlaps)
            # Foreground overlap alone lets a filled square resemble any solid
            # silhouette. Verify the empty shoulder/corner space independently.
            foreground=float(np.count_nonzero(normalized & best_shape))/max(1,np.count_nonzero(best_shape))
            negative=float(np.count_nonzero(~normalized & ~best_shape))/max(1,np.count_nonzero(~best_shape))
            hu=float(cv2.matchShapes(contour,model['contour'],cv2.CONTOURS_MATCH_I1,0.))
            pixels=query[y:y+h,x:x+w].astype(np.int16)
            fill_support=float(np.mean(np.max(np.abs(pixels-model['fill']),axis=2)[patch>0]<=35))
            aspect_error=abs(float(np.log((w/h)/model['aspect'])))
            row.update(shape_iou=round(iou,3),hu_distance=round(hu,3),foreground_coverage=round(foreground,3),negative_space=round(negative,3),fill_support=round(fill_support,3),aspect_error=round(aspect_error,3),reference=model['name'])
            if not (.30<=fill<=.93 and .65<=solidity<=.92):
                reasons.append('fill/solidity')
            # Shape evidence replaces brittle polygon/hull vertex counts. A red
            # road/triangle does not pass solely because more colors are admitted.
            if fill_support<.70:
                reasons.append('rendered arrow fill color')
            if aspect_error>.25:
                reasons.append('rendered arrow proportions')
            if iou<.65 or hu>.8:
                reasons.append('arrow silhouette')
            if foreground<.70 or negative<.55:
                reasons.append('missing arrow shoulders/negative space')
            moments=cv2.moments(contour)
            if moments['m00']<=0:
                reasons.append('zero area')
            if reasons:
                row['reason']=', '.join(reasons);diagnostics.append(row);continue
            ax,ay=moments['m10']/moments['m00'],moments['m01']/moments['m00']
            score=.85*iou+.15*negative
            accepted.append(dict(x=x,y=y,w=w,h=h,ax=ax,ay=ay,score=score,shape_iou=iou,negative_space=negative,reference=model['name'],reference_count=len(models)))
            row.update(accepted=True,score=round(score,3),reason='shape/color passed')
            diagnostics.append(row)
    groups=[]
    for candidate in sorted(accepted,key=lambda c:c['score'],reverse=True):
        group=next((g for g in groups if _same(g[0],candidate)),None)
        if group is None:groups.append([candidate])
        else:group.append(candidate)
    candidates=[dict(g[0],hypotheses=len(g)) for g in groups]
    return candidates,diagnostics
