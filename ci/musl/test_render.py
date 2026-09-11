"""Physics + software EGL rendering with quantitative RGB/depth checks."""
import json
import os
from pathlib import Path
import time
import mujoco
import numpy as np
from PIL import Image
from OpenGL import EGL
import ctypes

out=Path(os.environ.get('RENDER_OUTPUT','/work/render-output'))
out.mkdir(parents=True,exist_ok=True)
xml='''<mujoco model="musl-render-test">
  <option timestep="0.002" gravity="0 0 -9.81"/>
  <visual><global offwidth="320" offheight="240"/><quality shadowsize="1024"/></visual>
  <worldbody>
    <light pos="0 0 4" dir="0 0 -1" diffuse="1 1 1"/>
    <camera name="top" pos="0 0 3" fovy="45"/>
    <geom name="floor" type="plane" size="3 3 0.1" rgba="0.7 0.7 0.7 1"/>
    <body name="box" pos="0 0 1"><freejoint/>
      <geom type="box" size="0.2 0.2 0.2" mass="1" rgba="1 0.1 0.1 1"/>
    </body>
  </worldbody>
</mujoco>'''
model=mujoco.MjModel.from_xml_string(xml)
data=mujoco.MjData(model)
initial=float(data.qpos[2])
for _ in range(1000): mujoco.mj_step(model,data)
assert np.isfinite(data.qpos).all() and 0.18<float(data.qpos[2])<0.22
assert data.ncon>0
with mujoco.Renderer(model,height=240,width=320) as renderer:
    renderer.update_scene(data,camera='top')
    started=time.monotonic()
    rgb=renderer.render().copy()
    renderer.enable_depth_rendering()
    depth=renderer.render().copy()
    elapsed=time.monotonic()-started
    get_string=ctypes.CFUNCTYPE(ctypes.c_char_p, ctypes.c_uint)(EGL.eglGetProcAddress('glGetString'))
    gl_info={name:get_string(value).decode() for name,value in [('vendor',0x1F00),('renderer',0x1F01),('version',0x1F02)]}
assert rgb.shape==(240,320,3) and rgb.dtype==np.uint8
assert depth.shape==(240,320) and np.isfinite(depth).all()
assert rgb.std()>10 and int(rgb[120,160,0])>int(rgb[120,160,1])+30
expected=3-(float(data.qpos[2])+0.2)
assert abs(float(depth[120,160])-expected)<0.02,(depth[120,160],expected)
assert abs(float(depth[10,10])-3)<0.02,depth[10,10]
assert 'llvmpipe' in gl_info['renderer'].lower(),gl_info
Image.fromarray(rgb).save(out/'rgb.png')
np.save(out/'depth.npy',depth)
Image.fromarray(np.clip((depth-2.5)/0.6*255,0,255).astype('uint8')).save(out/'depth-preview.png')
loaded=sorted({line.split()[-1] for line in Path('/proc/self/maps').read_text().splitlines() if '/' in line})
expected_mesa=os.environ.get('EXPECTED_MESA_PREFIX')
if expected_mesa:
    for lib in ['libEGL.so','libgallium-']:
        paths=[p for p in loaded if Path(p).name.startswith(lib)]
        assert paths and all(p.startswith(expected_mesa+'/') for p in paths),(lib,paths)
result={'mujoco':mujoco.__version__,'numpy':np.__version__,'initial_box_z':initial,'final_box_z':float(data.qpos[2]),'contacts':int(data.ncon),'rgb_center':rgb[120,160].tolist(),'depth_center':float(depth[120,160]),'expected_depth_center':expected,'depth_floor':float(depth[10,10]),'render_seconds':elapsed,'opengl':gl_info,'loaded_libraries':loaded}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='loaded_libraries'},indent=2))
print('PASS: physics, RGB, metric depth, llvmpipe renderer')
