import json,sys
for p in sys.argv[1:]:
    rows=[json.loads(l) for l in open(p) if l.strip()][-5:]
    ms=sum(r['window']['ms'] for r in rows); pr=sum(r['presents'] for r in rows)
    g=sum(r.get('gpu_busy_ms_per_present',0)*r['presents'] for r in rows)/pr
    print(p.split('/')[0]+'/'+p.split('/')[1], 'fps %.2f'%(1000*pr/ms), 'frame %.2f s'%(ms/pr/1000), 'gpu/frame %.2f s'%(g/1000))
