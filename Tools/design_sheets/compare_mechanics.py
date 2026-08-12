import json, openpyxl, os, re, difflib, math, csv
base = r'D:\dOCS\test\Tools\design_sheets'
with open(os.path.join(base,'project_mechanics.json'), encoding='utf-8') as f:
    data=json.load(f)

def norm(s):
    s='' if s is None else str(s)
    s=s.lower().replace('ё','е').strip()
    s=s.replace('й','и')
    s=re.sub(r'[^a-zа-я0-9]+',' ',s)
    return re.sub(r'\s+',' ',s).strip()

def clean_cell(v):
    if v is None: return ''
    if isinstance(v,float) and v.is_integer(): return str(int(v))
    return str(v).strip()

def pos_from_bools(arr):
    return ''.join(str(i+1) for i,v in enumerate(arr) if v)

def number_from(v):
    s=clean_cell(v).replace(',','.')
    m=re.search(r'-?\d+(?:\.\d+)?', s)
    return float(m.group()) if m else None

def extract_pos(v):
    s=clean_cell(v)
    if not s: return ''
    # Excel date accident for 1/2/3 -> keep raw impossible value out
    if re.match(r'\d{4}-\d{2}-\d{2}', s): return s
    digs=''.join(ch for ch in s if ch in '1234')
    return ''.join(dict.fromkeys(digs))

def parse_book(path):
    wb=openpyxl.load_workbook(path, data_only=True)
    rows=[]
    for ws in wb.worksheets:
        header=None
        current_unit=''
        for ri,row in enumerate(ws.iter_rows(values_only=True), start=1):
            vals=[clean_cell(v) for v in row]
            if not any(vals):
                continue
            if any('Название' == v for v in vals):
                # choose last/most relevant header; map duplicate loosely
                header={'title': None,'pos':None,'target':None,'damage':None,'effect':None}
                for i,v in enumerate(vals):
                    low=v.lower()
                    if v=='Название': header['title']=i
                    elif 'позиц' in low: header['pos']=i
                    elif 'цель' in low or 'цели' in low: header['target']=i
                    elif 'урон' in low or 'коэффициент' in low: header['damage']=i
                    elif 'эффект' in low: header['effect']=i
                continue
            if not header or header['title'] is None or header['title'] >= len(vals):
                continue
            title=vals[header['title']].strip()
            before=[v for v in vals[:header['title']] if v.strip()]
            if before:
                candidate=before[0]
                if candidate.lower() not in ['пассивка','ии'] and not candidate.lower().startswith('пассивка'):
                    current_unit=candidate
            first_non=next((v for v in vals if v.strip()), '')
            if first_non.lower().startswith('пассивка'):
                if current_unit:
                    rows.append({'sheet':ws.title,'unit':current_unit,'kind':'passive','ability':'Пассивка','pos':'','target':'','damage':'','effect':' '.join(v for v in vals if v and not v.lower().startswith('пассивка')),'row':ri})
                continue
            if first_non.lower()=='ии':
                continue
            if title and current_unit and title != 'Название':
                rows.append({'sheet':ws.title,'unit':current_unit,'kind':'ability','ability':title,'pos': clean_cell(vals[header['pos']]) if header['pos'] is not None and header['pos']<len(vals) else '', 'target':clean_cell(vals[header['target']]) if header['target'] is not None and header['target']<len(vals) else '', 'damage':clean_cell(vals[header['damage']]) if header['damage'] is not None and header['damage']<len(vals) else '', 'effect':clean_cell(vals[header['effect']]) if header['effect'] is not None and header['effect']<len(vals) else '', 'row':ri})
    return rows

def build_units(kind):
    units=data[kind]
    return units

def best_match(name, choices, key=lambda x:x):
    n=norm(name)
    best=None; score=0
    for c in choices:
        cn=norm(key(c))
        sc=difflib.SequenceMatcher(None,n,cn).ratio()
        # substring bonus
        if n and cn and (n in cn or cn in n): sc=max(sc,0.82)
        if sc>score:
            score=sc; best=c
    return best,score

def compare(rows, kind):
    units=build_units(kind)
    out=[]
    for r in rows:
        if r['kind']!='ability': continue
        unit,us=best_match(r['unit'], units, lambda u:u['unit_name'])
        if not unit or us<0.55:
            out.append([kind,r['sheet'],r['unit'],r['ability'],'NO_UNIT',round(us,2),'','','','',''])
            continue
        abilities=unit['abilities'] + ([unit['ultimate']] if unit.get('ultimate') else [])
        ab,ascore=best_match(r['ability'], abilities, lambda a:a['name'])
        if not ab or ascore<0.46:
            out.append([kind,r['sheet'],r['unit'],r['ability'],'NO_ABILITY',unit['unit_name'],round(ascore,2),'','','',''])
            continue
        issues=[]
        sheet_pos=extract_pos(r['pos'])
        proj_pos=pos_from_bools(ab['usable_from_positions'])
        if sheet_pos and sheet_pos != proj_pos:
            issues.append(f'позиции таблица {sheet_pos}, проект {proj_pos}')
        sheet_dmg=number_from(r['damage'])
        # ignore if damage cell actually contains text like mark/stance/cost
        if sheet_dmg is not None and sheet_dmg < 10:
            proj_dmg=float(ab['damage_modifier'])
            if abs(sheet_dmg-proj_dmg)>0.051:
                issues.append(f'урон таблица {sheet_dmg:g}, проект {proj_dmg:g}')
        # cost mentions
        text=(r['target']+' '+r['damage']+' '+r['effect']).lower().replace(',','.')
        cm=re.search(r'(\d+)\s*(?:слав|велич)', text)
        if cm:
            scost=int(cm.group(1)); pcost=int(ab['majesty_cost'])
            if scost != pcost:
                issues.append(f'стоимость таблица {scost}, проект {pcost}')
        # target numeric positions
        sheet_tpos=extract_pos(r['target'])
        if sheet_tpos and not re.search(r'слав|велич', r['target'].lower()):
            proj_tpos=pos_from_bools(ab['targetable_positions'])
            if sheet_tpos != proj_tpos:
                issues.append(f'цели таблица {sheet_tpos}, проект {proj_tpos}/{ab["target_type"]}')
        # stance mismatch
        if 'стойк' in text and not ab['is_stance']:
            issues.append('в таблице стойка, в ресурсе не stance')
        if issues:
            out.append([kind,r['sheet'],r['unit'],r['ability'],'PARAM',unit['unit_name'],ab['name'],'; '.join(issues),r['effect'],ab.get('description',''),ab.get('ability_marker','')])
    return out

god_rows=parse_book(os.path.join(base,'gods.xlsx'))
enemy_rows=parse_book(os.path.join(base,'enemies.xlsx'))
report=[]
report += compare(god_rows,'gods')
report += compare(enemy_rows,'enemies')
with open(os.path.join(base,'mechanics_compare_report.tsv'),'w',encoding='utf-8',newline='') as f:
    wr=csv.writer(f,delimiter='\t')
    wr.writerow(['kind','sheet','sheet_unit','sheet_ability','type','project_unit','project_ability_or_score','issues','sheet_effect','project_description','marker'])
    wr.writerows(report)
print('god rows',len(god_rows),'enemy rows',len(enemy_rows),'issues',len(report))
for row in report[:220]:
    print('\t'.join(str(x) for x in row[:8]))
print('REPORT', os.path.join(base,'mechanics_compare_report.tsv'))