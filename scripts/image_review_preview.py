"""Bounded viewport geometry and Tk interactions; raster rendering runs on a worker."""
import math
import time
import tkinter as tk
from PIL import Image


class Viewport:
    def __init__(self,width,height,image_width,image_height):
        self.width=width;self.height=height;self.iw=image_width;self.ih=image_height
        self.zoom=1.;self.x=0.;self.y=0.
    @property
    def scale(self):return min(self.width/self.iw,self.height/self.ih)*self.zoom
    def clamp(self):
        dx=max(0,(self.iw*self.scale-self.width)/2)
        dy=max(0,(self.ih*self.scale-self.height)/2)
        self.x=max(-dx,min(dx,self.x));self.y=max(-dy,min(dy,self.y))
    def reset(self):self.zoom=1.;self.x=self.y=0.
    def zoom_at(self,factor,x,y):
        old=self.scale
        ix=(x-self.width/2-self.x)/old;iy=(y-self.height/2-self.y)/old
        self.zoom=max(1.,min(16.,self.zoom*factor))
        self.x=x-self.width/2-ix*self.scale;self.y=y-self.height/2-iy*self.scale
        self.clamp()
    def pan(self,x,y):self.x=x;self.y=y;self.clamp()
    def transform(self):
        left=self.width/2+self.x-self.iw*self.scale/2
        top=self.height/2+self.y-self.ih*self.scale/2
        return (1/self.scale,0,-left/self.scale,0,1/self.scale,-top/self.scale)


def raster(master,size,transform):
    return master.transform(size,Image.Transform.AFFINE,transform,Image.Resampling.BILINEAR,
                            fillcolor=(35,39,47,255))


class ZoomPreview(tk.Canvas):
    def __init__(self,parent,request,zoom_label):
        super().__init__(parent,bg='#23272f',highlightthickness=0,width=770,height=400)
        self.request=request;self.zoom_label=zoom_label;self.master_image=None;self.image=None
        self.model=None;self.render_token=0;self.drag=None;self.dragged=False;self.last_drag=0;self.scheduled=None
        self.bind('<Configure>',self.resize)
        self.bind('<Double-Button-1>',self.double)
        self.bind('<MouseWheel>',self.wheel)
        self.bind('<ButtonPress-1>',self.press)
        self.bind('<B1-Motion>',self.motion)
        self.bind('<ButtonRelease-1>',self.release)
    def show_message(self,text):
        self.render_token+=1;self.master_image=None;self.model=None;self.image=None
        self.delete('all');self.create_text(max(1,self.winfo_width())//2,max(1,self.winfo_height())//2,
            text=text,fill='white',width=700)
        self.zoom_label.set('Zoom: 100% (fit)')
    def set_image(self,master):
        self.master_image=master
        self.model=Viewport(max(1,self.winfo_width()),max(1,self.winfo_height()),*master.size)
        self.drag=None;self.dragged=False;self.last_drag=0
        self.render()
    def render(self):
        if self.model is None:return
        self.render_token+=1
        self.zoom_label.set(f'Zoom: {self.model.zoom*100:.0f}% of fit')
        if self.scheduled:self.after_cancel(self.scheduled)
        token=self.render_token
        def submit():
            self.scheduled=None
            if self.model and token==self.render_token:
                self.request(token,self.master_image,(self.model.width,self.model.height),self.model.transform())
        self.scheduled=self.after(16,submit)
    def display(self,photo,token):
        if token!=self.render_token:return
        self.delete('all');self.image=photo
        self.create_image(0,0,anchor='nw',image=photo)
    def resize(self,event):
        if self.model:
            self.model.width=max(1,event.width);self.model.height=max(1,event.height)
            self.model.clamp();self.render()
    def double(self,event):
        if not self.model or time.monotonic()-self.last_drag<.3:return 'break'
        self.drag=None
        if self.model.zoom>1:self.model.reset()
        else:self.model.zoom_at(2,event.x,event.y)
        self.render();return 'break'
    def wheel(self,event):
        if self.model:
            self.model.zoom_at(1.2 if event.delta>0 else 1/1.2,event.x,event.y);self.render()
        return 'break'
    def press(self,event):
        self.drag=(event.x,event.y,self.model.x,self.model.y) if self.model else None
        self.dragged=False
    def motion(self,event):
        if not self.drag or not self.model or self.model.zoom<=1:return
        x,y,px,py=self.drag
        if math.hypot(event.x-x,event.y-y)>=4:self.dragged=True
        if self.dragged:self.model.pan(px+event.x-x,py+event.y-y);self.render()
    def release(self,event):
        if self.dragged:self.last_drag=time.monotonic()
        self.drag=None
