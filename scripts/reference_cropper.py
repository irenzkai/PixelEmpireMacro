"""Manual crop selection with original-pixel coordinates and explicit animation frame."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import queue
import tkinter as tk
from tkinter import ttk
from PIL import Image,ImageTk

class CropWindow:
    def __init__(self,parent,path,callback):
        self.path=Path(path);self.callback=callback;self.photo=None;self.start=None;self.box=None;self.dimensions=None
        self.events=queue.Queue();self.worker=ThreadPoolExecutor(max_workers=1);self.closed=False;self.token=0;self.zoom=1
        self.window=tk.Toplevel(parent);self.window.title('Crop reference - drag only the required pixels');self.window.geometry('960x680')
        view=ttk.Frame(self.window);view.pack(fill='both',expand=True)
        view.rowconfigure(0,weight=1);view.columnconfigure(0,weight=1)
        self.canvas=tk.Canvas(view,width=920,height=540,bg='#172033');self.canvas.grid(row=0,column=0,sticky='nsew')
        horizontal=ttk.Scrollbar(view,orient='horizontal',command=self.canvas.xview);horizontal.grid(row=1,column=0,sticky='ew')
        vertical=ttk.Scrollbar(view,orient='vertical',command=self.canvas.yview);vertical.grid(row=0,column=1,sticky='ns')
        self.canvas.configure(xscrollcommand=horizontal.set,yscrollcommand=vertical.set)
        row=ttk.Frame(self.window);row.pack(fill='x',padx=10,pady=6)
        ttk.Label(row,text='Animation frame:').pack(side='left');self.frame=tk.IntVar(value=0)
        ttk.Spinbox(row,from_=0,to=9999,textvariable=self.frame,width=7).pack(side='left')
        ttk.Button(row,text='Load frame',command=self.load).pack(side='left',padx=6)
        for zoom in (1,2,4):ttk.Button(row,text='Fit' if zoom==1 else str(zoom)+'x',command=lambda z=zoom:self.set_zoom(z)).pack(side='left')
        self.status=tk.StringVar(value='Loading selected image...');ttk.Label(row,textvariable=self.status).pack(side='left',fill='x',expand=True)
        ttk.Button(row,text='Use selected crop',command=self.use).pack(side='right')
        self.canvas.bind('<ButtonPress-1>',self.press);self.canvas.bind('<B1-Motion>',self.drag);self.canvas.bind('<ButtonRelease-1>',self.release)
        self.window.protocol('WM_DELETE_WINDOW',self.close);self.load();self.window.after(40,self.poll)
    def set_zoom(self,value):
        self.zoom=value;self.load()
    def load(self):
        try:frame=int(self.frame.get())
        except (ValueError,tk.TclError):self.status.set('Choose a numeric frame');return
        self.token+=1;token=self.token;self.box=None;zoom=self.zoom
        def work():
            try:
                with Image.open(self.path) as image:
                    count=getattr(image,'n_frames',1)
                    if not 0<=frame<count:raise ValueError(f'Frame must be 0-{count-1}')
                    image.seek(frame);dimensions=image.size
                    if image.width*image.height>64_000_000:raise ValueError('Use an image smaller than 64 megapixels')
                    preview=image.convert('RGBA');preview.thumbnail((920*zoom,540*zoom))
                self.events.put((token,preview,dimensions,count,frame))
            except Exception as exc:self.events.put((token,str(exc)))
        self.worker.submit(work)
    def poll(self):
        if self.closed:return
        try:
            while True:
                result=self.events.get_nowait()
                if result[0]!=self.token:continue
                if len(result)==2:self.status.set(result[1]);continue
                _,image,self.dimensions,count,self.loaded_frame=result
                self.photo=ImageTk.PhotoImage(image);self.scale=image.width/self.dimensions[0]
                self.canvas.delete('all');self.canvas.create_image(0,0,anchor='nw',image=self.photo)
                self.canvas.configure(scrollregion=(0,0,image.width,image.height))
                self.status.set(f'{self.dimensions[0]}x{self.dimensions[1]}, {count} frame(s). Drag an arch/center/label crop.')
        except queue.Empty:pass
        self.window.after(40,self.poll)
    def point(self,event):
        return [max(0,min(self.dimensions[0],int(self.canvas.canvasx(event.x)/self.scale))),max(0,min(self.dimensions[1],int(self.canvas.canvasy(event.y)/self.scale)))]
    def press(self,event):
        if self.dimensions:self.start=self.point(event)
    def drag(self,event):
        if self.start is None:return
        x,y=self.point(event);left=min(x,self.start[0]);top=min(y,self.start[1]);w=abs(x-self.start[0]);h=abs(y-self.start[1])
        self.box=[left,top,w,h];self.canvas.delete('crop')
        self.canvas.create_rectangle(left*self.scale,top*self.scale,(left+w)*self.scale,(top+h)*self.scale,outline='#00ff99',width=2,tags='crop')
        self.status.set(f'Crop x,y,w,h: {self.box}')
    def release(self,event):self.drag(event);self.start=None
    def use(self):
        if not self.box or min(self.box[2:])<2:self.status.set('Drag a crop at least 2x2 pixels');return
        self.callback(self.box,self.loaded_frame);self.close()
    def close(self):
        self.closed=True;self.worker.shutdown(wait=False,cancel_futures=True);self.window.destroy()
