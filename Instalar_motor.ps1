$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$root = Join-Path $PSScriptRoot 'motor'
New-Item -ItemType Directory -Force $root | Out-Null
if (!(Test-Path "$root\ComfyUI_windows_portable\python_embeded\python.exe")) {
$release = Invoke-RestMethod 'https://api.github.com/repos/Comfy-Org/ComfyUI/releases/latest'
$asset = $release.assets | Where-Object { $_.name -eq 'ComfyUI_windows_portable_nvidia.7z' } | Select-Object -First 1
if (!$asset) { $asset = $release.assets | Where-Object { $_.name -match 'windows_portable_nvidia.*\.7z$' -and $_.name -notmatch 'amd' } | Select-Object -First 1 }
if (!$asset) { throw 'No se encontro el paquete NVIDIA oficial. Instale ComfyUI portable manualmente en motor.' }
$archive = Join-Path $root $asset.name
if (!(Test-Path "$root\ComfyUI_windows_portable\python_embeded\python.exe")) {
  curl.exe -L --fail --retry 3 -C - -o $archive $asset.browser_download_url
  if ($LASTEXITCODE) { throw 'Error descargando ComfyUI' }
  tar.exe -xf $archive -C $root
  if ($LASTEXITCODE) { throw 'No se pudo extraer. Extraiga el archivo 7z con 7-Zip dentro de motor.' }
  if (!(Test-Path "$root\ComfyUI_windows_portable\python_embeded\python.exe")) { throw 'Estructura portable inesperada' }
  Remove-Item $archive
}
}
$dir = "$root\ComfyUI_windows_portable\ComfyUI\models\checkpoints"
New-Item -ItemType Directory -Force $dir | Out-Null
$repo = 'OnomaAIResearch/Illustrious-xl-early-release-v0'
if (!(Get-ChildItem $dir -Filter '*.safetensors' | Where-Object { $_.Length -gt 2000000000 } | Select-Object -First 1)) {
$meta = Invoke-RestMethod "https://huggingface.co/api/models/${repo}?blobs=true"
$file = $meta.siblings | Where-Object { $_.rfilename -match '^[^/]+\.safetensors$' -and $_.size -gt 2000000000 } | Select-Object -First 1
if (!$file) { throw 'Modelo no disponible. Coloque un checkpoint SDXL anime en models/checkpoints.' }
$dest = Join-Path $dir $file.rfilename
if (!(Test-Path $dest)) {
 curl.exe -L --fail --retry 3 -C - -o "$dest.part" "https://huggingface.co/$repo/resolve/main/$($file.rfilename)"
 if ($LASTEXITCODE) { throw 'Error descargando modelo' }
 if ((Get-Item "$dest.part").Length -ne $file.size) { throw 'Descarga incompleta' }
 if ($file.lfs.sha256 -and (Get-FileHash "$dest.part" -Algorithm SHA256).Hash -ne $file.lfs.sha256) { Remove-Item "$dest.part"; throw 'SHA256 incorrecto' }
 Move-Item "$dest.part" $dest
}
}
Write-Host 'Motor y modelo instalados.'

$up = Join-Path $root 'ComfyUI_windows_portable\ComfyUI\models\upscale_models'
New-Item -ItemType Directory -Force $up | Out-Null
$anime = Join-Path $up 'RealESRGAN_x4plus_anime_6B.pth'
if (!(Test-Path $anime)) {
 curl.exe -L --fail --retry 3 -C - -o "$anime.part" 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth'
 if ($LASTEXITCODE -eq 0) { Move-Item "$anime.part" $anime } else { throw 'No se pudo descargar Anime 6B. Reintente la instalacion.' }
}
