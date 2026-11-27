"""Learn literal notification formats only from manually annotated real examples."""
import json
import re
from scripts.reference_setup_store import connect
FIELDS=('boss_name','spawn_map','spawn_area','defeating_player')
def make_pattern(text,fields):
    text=' '.join(text.split());spans=[]
    if not text:raise ValueError('Supply the actual visible notification text')
    for key in FIELDS:
        value=' '.join(fields.get(key,'').split())
        if not value:continue
        hits=list(re.finditer(re.escape(value),text,re.I))
        if len(hits)!=1:raise ValueError(key+' must appear exactly once in visible text; leave uncertain fields blank')
        spans.append((hits[0].start(),hits[0].end(),key))
    spans.sort();parts=[];position=0
    def literal(s):return re.escape(s).replace(r'\ ',r'\s+')
    for start,end,key in spans:
        if start<position:raise ValueError('Annotated fields overlap')
        parts.extend((literal(text[position:start]),f'(?P<{key}>.+?)'));position=end
    parts.append(literal(text[position:]));return '^'+''.join(parts)+'$'

def parse_notification(text,root=None):
    raw=text;normalized=' '.join(text.split())
    result=dict(raw_text=raw,boss_text=raw,status='UNKNOWN',notification_state='UNKNOWN',boss_name=None,spawn_map=None,spawn_area=None,defeating_player=None,
                uncertain_fields=list(FIELDS),kind='',active=0,defeated=0,you_defeated=0,boss_state='',format_confirmed=0)
    with (connect() if root is None else connect(root)) as c:
        exists=c.execute("SELECT 1 FROM sqlite_master WHERE name='manual_notification_examples'").fetchone()
        rows=c.execute('SELECT * FROM manual_notification_examples WHERE confirmed=1').fetchall() if exists else []
    matches=[];seen=set()
    for row in rows:
        signature=(row['status'],row['pattern'],json.loads(row['fields_json']).get('kind',''))
        if signature in seen:continue
        seen.add(signature)
        found=re.fullmatch(row['pattern'],normalized,re.I)
        if found:matches.append((row,found))
    if len(matches)!=1:
        result['reason']='No confirmed format matches' if not matches else 'Multiple confirmed formats match; supply a clearer example'
        return result
    row,found=matches[0];annotations=json.loads(row['fields_json']);state=row['status']
    result.update(status=state,notification_state=state,kind=annotations.get('kind',''),active=int(state!='DEFEATED'),defeated=int(state=='DEFEATED'),
        boss_state='SPAWN' if state=='APPEARED' else state,format_confirmed=1)
    result.update({key:found.groupdict().get(key) for key in FIELDS})
    result['uncertain_fields']=[key for key in FIELDS if not result.get(key)]
    return result
