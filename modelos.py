from pathlib import Path
import requests, shutil, struct, json
from PySide6.QtCore import QThread, Signal
CATALOG={'Illustrious XL':'OnomaAIResearch/Illustrious-xl-early-release-v0','NoobAI XL':'Laxhar/noobai-XL-1.1'}
class Download(QThread):
    status=Signal(str); done=Signal(str); failed=Signal(str)
    def __init__(self,name,folder): super().__init__(); self.name=name; self.folder=Path(folder)
    def run(self):
        try:
            repo=CATALOG[self.name]; token=__import__('os').getenv('HF_TOKEN'); headers={'Authorization':'Bearer '+token} if token else {}
            r=requests.get('https://huggingface.co/api/models/'+repo,params={'blobs':'true'},headers=headers,timeout=30); r.raise_for_status(); meta=r.json()
            files=[x for x in meta['siblings'] if '/' not in x['rfilename'] and x['rfilename'].endswith('.safetensors') and (x.get('size') or 0)>2_000_000_000]
            if not files: raise RuntimeError('No se encontró un checkpoint completo. Consultá la página del modelo: https://huggingface.co/'+repo)
            f=sorted(files,key=lambda x:('fp16' not in x['rfilename'].lower(),x['rfilename']))[0]; size=f['size']; self.folder.mkdir(parents=True,exist_ok=True); dest=self.folder/f['rfilename']; part=dest.with_suffix('.part'); offset=part.stat().st_size if part.exists() else 0
            if dest.exists() and dest.stat().st_size==size: self.done.emit(dest.name); return
            if offset>size: part.unlink(); offset=0
            if shutil.disk_usage(self.folder).free<size-offset+500_000_000: raise RuntimeError('Espacio insuficiente')
            if offset<size:
                h=dict(headers); h.update({'Range':f'bytes={offset}-'} if offset else {})
                with requests.get('https://huggingface.co/'+repo+'/resolve/'+meta['sha']+'/'+f['rfilename'],headers=h,stream=True,timeout=(20,90)) as response:
                    response.raise_for_status()
                    if response.status_code!=206: offset=0
                    elif not response.headers.get('Content-Range','').startswith(f'bytes {offset}-'): raise RuntimeError('Rango de descarga incorrecto')
                    with part.open('ab' if offset else 'wb') as out:
                        for chunk in response.iter_content(4*1024*1024):
                            if self.isInterruptionRequested(): return
                            out.write(chunk); offset+=len(chunk); self.status.emit(f'{self.name}: {offset/size:.1%} ({offset/1e9:.2f} GB)')
            if part.stat().st_size!=size: raise RuntimeError('Descarga incompleta')
            import hashlib
            expected=(f.get('lfs') or {}).get('sha256')
            if expected:
                self.status.emit('Verificando SHA-256…'); digest=hashlib.sha256()
                with part.open('rb') as inp:
                    for block in iter(lambda:inp.read(8*1024*1024),b''): digest.update(block)
                if digest.hexdigest()!=expected: part.unlink(); raise RuntimeError('SHA-256 incorrecto; volvé a descargar')
            with part.open('rb') as inp:
                n=struct.unpack('<Q',inp.read(8))[0]
                if not 2<=n<=100_000_000: raise RuntimeError('Cabecera safetensors inválida')
                json.loads(inp.read(n))
            part.replace(dest); self.done.emit(dest.name)
        except Exception as e: self.failed.emit(str(e))
