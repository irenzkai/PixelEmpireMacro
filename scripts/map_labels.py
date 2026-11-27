"""Deduplicated map-label observations and explicit manual OCR corrections."""
import hashlib
import json
from pathlib import Path
import re
import tkinter as tk
from tkinter import ttk


def record(root,text,image=None,score=0):
    text=re.sub(r'\s+',' ',text).strip()[:160]
    if not text:return
    folder=Path(root)/'map_labels';folder.mkdir(exist_ok=True)
    key=hashlib.sha256(text.casefold().encode()).hexdigest()
    path=folder/(key+'.json')
    if path.exists():return
    reference=None
    if image is not None:
        import cv2
        reference=key+'.png';cv2.imwrite(str(folder/reference),image)
    data=dict(observed=text,label=text,confidence=score,status='needs_review',reference=reference)
    temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');temporary.replace(path)


def edit_labels(parent,root):
    dialog=tk.Toplevel(parent);dialog.title('Map labels: correct uncertain OCR');dialog.geometry('620x380')
    paths=list((Path(root)/'map_labels').glob('*.json'))
    rows=[(p,json.loads(p.read_text(encoding='utf-8'))) for p in paths]
    listing=tk.Listbox(dialog);listing.pack(fill='both',expand=True)
    for _,r in rows:listing.insert('end',r['label']+' ['+r['status']+']')
    value=tk.StringVar();ttk.Entry(dialog,textvariable=value).pack(fill='x')
    def select(*_):
        if listing.curselection():value.set(rows[listing.curselection()[0]][1]['label'])
    def save():
        if not listing.curselection() or not value.get().strip():return
        idx=listing.curselection()[0];path,data=rows[idx]
        data.update(label=value.get().strip(),status='corrected')
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        listing.delete(idx);listing.insert(idx,data['label']+' [corrected]')
    listing.bind('<<ListboxSelect>>',select)
    ttk.Button(dialog,text='Save correction',command=save).pack()

def corrected(root,text):
    normalized=re.sub(r'\s+',' ',text).strip()[:160]
    key=hashlib.sha256(normalized.casefold().encode()).hexdigest()
    try:
        data=json.loads((Path(root)/'map_labels'/(key+'.json')).read_text(encoding='utf-8'))
        return data['label'] if data['status']=='corrected' else text
    except (OSError,ValueError,KeyError):return text
