"""Map icon verification with background-masked full rendered structure."""
from functools import lru_cache
from pathlib import Path
import cv2
import numpy as np


@lru_cache(maxsize=12)
def aligned_icon(path,stamp):
    image=cv2.imread(path,cv2.IMREAD_COLOR)
    if image is None:return None
    hsv=cv2.cvtColor(image,cv2.COLOR_BGR2HSV)
    cyan=cv2.inRange(hsv,np.array([85,40,100]),np.array([135,255,255]))
    count,_,stats,centers=cv2.connectedComponentsWithStats(cyan)
    # The upper diamond precedes the three body rune bars. This alignment
    # removes screenshot margins, not the rendered object's own geometry.
    options=[i for i in range(1,count) if stats[i,4]>=3 and stats[i,2]>=2 and stats[i,3]>=2 and stats[i,1]<image.shape[0]/2]
    if not options:return None
    index=min(options,key=lambda i:stats[i,1])
    cx=float(centers[index,0]);top=int(stats[index,1])-1
    left=round(cx)-8;right=left+16;bottom=top+27
    if left<0 or top<0 or right>image.shape[1] or bottom>image.shape[0]:return None
    body=image[top:bottom,left:right].copy()
    mask=np.zeros((27,16),np.uint8)
    # Roof, upright sides, rune panel and wide base; surrounding terrain is
    # excluded. The separate top diamond is retained as additional structure.
    polygon=np.int32([[8,5],[12,9],[12,22],[15,22],[15,26],[0,26],[0,22],[3,22],[3,9]])
    cv2.fillPoly(mask,[polygon],255)
    diamond=cyan[top:bottom,left:right].copy();diamond[7:]=0
    mask |= cv2.dilate(diamond,np.ones((3,3),np.uint8))
    return np.dstack((body,mask))


@lru_cache(maxsize=96)
def color_model(raw,bh,bw,w,h):
    image=np.frombuffer(raw,np.uint8).reshape(bh,bw,4)
    rgb=cv2.resize(image[:,:,:3],(w,h),interpolation=cv2.INTER_LINEAR)
    mask=cv2.resize(image[:,:,3],(w,h),interpolation=cv2.INTER_NEAREST)>0
    gray=cv2.cvtColor(rgb,cv2.COLOR_BGR2GRAY)
    hsv=cv2.cvtColor(rgb,cv2.COLOR_BGR2HSV)
    dark=(gray<75)&mask
    cyan=(cv2.inRange(hsv,np.array([85,25,55]),np.array([135,255,255]))>0)&mask
    return rgb,mask,dark,cyan


def verify_colors(patch,model):
    rgb,mask,dark,cyan=model
    difference=np.mean(np.abs(patch.astype(np.float32)-rgb.astype(np.float32)),axis=2)
    color=float(np.exp(-float(difference[mask].mean())/45.)) if mask.any() else 0.
    gray=cv2.cvtColor(patch,cv2.COLOR_BGR2GRAY)
    dark_support=float(np.mean(gray[dark]<95)) if dark.any() else 0.
    hsv=cv2.cvtColor(patch,cv2.COLOR_BGR2HSV)
    query_cyan=cv2.inRange(hsv,np.array([85,25,55]),np.array([135,255,255]))>0
    cyan_support=float(np.mean(query_cyan[cyan])) if cyan.any() else 0.
    return color,dark_support,cyan_support
