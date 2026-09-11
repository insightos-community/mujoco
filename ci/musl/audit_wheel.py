import json,re,subprocess,tempfile,zipfile
from pathlib import Path
root=Path('/work')
wheel=next((root/'repaired-wheels').glob('*.whl'))
rows=[]
with tempfile.TemporaryDirectory() as directory:
 with zipfile.ZipFile(wheel) as z:z.extractall(directory)
 for path in Path(directory).rglob('*'):
  if not path.is_file():continue
  with path.open('rb') as f:
   if f.read(4)!=b'\x7fELF':continue
  versions=subprocess.check_output(['readelf','--version-info',str(path)],text=True)
  dynamic=subprocess.check_output(['readelf','-d',str(path)],text=True)
  assert not re.search(r'\bGLIBC_[0-9]',versions),path
  rows.append({'path':str(path.relative_to(directory)),'needed':re.findall(r'\(NEEDED\).*?\[(.*?)\]',dynamic)})
 assert len([r for r in rows if Path(r['path']).name.startswith('libmujoco')])==1, 'Duplicate MuJoCo core libraries'
(root/'wheel-elf-audit.json').write_text(json.dumps(rows,indent=2)+'\n')
print(f'PASS: {len(rows)} wheel ELF files, no GLIBC symbol versions, exactly one MuJoCo core library')
