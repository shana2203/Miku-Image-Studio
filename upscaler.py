import io, time, uuid
from pathlib import Path
import requests
from PIL import Image, ImageOps, ImageFilter
MODEL='RealESRGAN_x4plus_anime_6B.pth'

def enhance(worker, image, url, sharp=30):
    worker.ensure_local(url)
    # ComfyUI's built-in ImageUpscaleWithModel starts at 512px tiles,
    # overlap 32px, and reduces tile size on GPU out-of-memory.
    buf=io.BytesIO(); image.convert('RGB').save(buf,format='PNG'); buf.seek(0)
    r=requests.post(url+'/upload/image',files={'image':('miku_'+uuid.uuid4().hex+'.png',buf,'image/png')},data={'type':'input'},timeout=120); r.raise_for_status(); info=r.json()
    name='/'.join(filter(None,[info.get('subfolder'),info['name']]))
    def node(t,**kw): return {'class_type':t,'inputs':kw}
    g={'1':node('LoadImage',image=name),'2':node('UpscaleModelLoader',model_name=MODEL),'3':node('ImageUpscaleWithModel',image=['1',0],upscale_model=['2',0]),'7':node('SaveImage',images=['3',0],filename_prefix='MikuUpscale')}
    raw=worker.execute_graph(url,g)
    out=Image.open(io.BytesIO(raw)).convert('RGB')
    if out.size!=(image.width*4,image.height*4): raise RuntimeError('El modelo no devolvió una ampliación 4×.')
    if sharp: out=out.filter(ImageFilter.UnsharpMask(radius=1.2,percent=sharp,threshold=3))
    if 'A' in image.getbands(): out.putalpha(image.getchannel('A').resize(out.size,Image.Resampling.LANCZOS))
    return out
