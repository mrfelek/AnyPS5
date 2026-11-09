import sys, glob, os, numpy as np
from PIL import Image
src, S = sys.argv[1], sys.argv[2]
os.makedirs(S, exist_ok=True)
def dec(path):
    b=open(path,'rb').read(); w,h,f=[int(x) for x in np.frombuffer(b[:12],'<u4')]; d=b[12:]; n=w*h; bpp=len(d)//n
    if f in (37,43): a=np.frombuffer(d,np.uint8).reshape(h,w,4)[...,:3].astype(np.float32)/255
    elif f in (44,50): a=np.frombuffer(d,np.uint8).reshape(h,w,4)[...,2::-1].astype(np.float32)/255
    elif f==64:
        v=np.frombuffer(d,'<u4').reshape(h,w); a=np.stack([(v&1023),(v>>10)&1023,(v>>20)&1023],-1).astype(np.float32)/1023
    elif f==122:
        v=np.frombuffer(d,'<u4').reshape(h,w)
        def uf(x,mb):
            e=(x>>mb)&31; m=x&((1<<mb)-1); return np.where(e==0, m/(1<<mb)*2.0**-14, (1+m/(1<<mb))*2.0**(e.astype(np.float64)-15))
        a=np.stack([uf(v&2047,6),uf((v>>11)&2047,6),uf((v>>22)&1023,5)],-1).astype(np.float32)
    elif f==97: a=np.frombuffer(d,np.float16).reshape(h,w,4)[...,:3].astype(np.float32)
    elif f==76: a=np.repeat(np.frombuffer(d,np.float16).reshape(h,w,1).astype(np.float32),3,-1)
    elif f==100: a=np.repeat(np.frombuffer(d,np.float32).reshape(h,w,1),3,-1)
    elif bpp==8 and f in (101,103):
        x=np.frombuffer(d,np.float32 if f==103 else np.uint32).reshape(h,w,2).astype(np.float32); a=np.concatenate([x,np.zeros((h,w,1),np.float32)],-1)
    else: return w,h,f,None
    return w,h,f,np.nan_to_num(a)
key=lambda s:(s.split('_')[1],int(s.split('_')[2][:-4]))
for p in sorted(glob.glob(src+'/target_*.raw'), key=lambda s:key(os.path.basename(s))):
    name=os.path.basename(p)[:-4]
    w,h,f,a=dec(p)
    if a is None: print(name,w,h,f,'?'); continue
    nz=(np.abs(a).sum(-1)>1e-4).mean(); mx=float(np.abs(a).max())
    t=np.clip(a/max(1e-6,min(mx,4.0)),0,1)**(1/2.2)
    Image.fromarray((t*255).astype(np.uint8)).resize((480,270)).save(f"{S}/{name}.png")
    print(name,w,h,f,f"nonzero {nz:.3f} max {mx:.3g}")
