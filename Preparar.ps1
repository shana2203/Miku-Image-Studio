$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
if (!(Test-Path '.venv\Scripts\python.exe')) {
  $py=Get-Command py.exe -ErrorAction SilentlyContinue
  if (!$py) {
    winget install --id Python.Python.3.11 --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE) { throw 'No se pudo instalar Python 3.11' }
  }
  $launcher=@("$env:LOCALAPPDATA\Programs\Python\Launcher\py.exe", "$env:WINDIR\py.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($py) { $launcher=$py.Source }
  if ($launcher) { & $launcher -3.11 -m venv .venv } else { & "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe" -m venv .venv }
  if ($LASTEXITCODE) { throw 'No se pudo crear el entorno Python' }
}
& '.venv\Scripts\python.exe' -m pip install -r requirements.txt
if ($LASTEXITCODE) { throw 'Error instalando dependencias' }
& "$PSScriptRoot\Instalar_motor.ps1"
& '.venv\Scripts\python.exe' -c 'import PySide6, PIL, requests, openai'
if ($LASTEXITCODE) { throw 'Dependencias incompletas' }
$motor=Join-Path $PSScriptRoot 'motor\ComfyUI_windows_portable\python_embeded\python.exe'
& $motor -c 'import torch; assert torch.cuda.is_available(), "CUDA no disponible"; print(torch.cuda.get_device_name(0))'
if ($LASTEXITCODE) { throw 'CUDA no disponible. Actualice el controlador NVIDIA.' }
Set-Content -Path '.ready' -Value '3.3'
