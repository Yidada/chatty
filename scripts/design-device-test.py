#!/usr/bin/env python3
"""Capture and exercise the native visual system on the synthetic Pixel app.

Temporarily changes Android night mode and font scale; always restores both.
Run after fixture authentication. No requests are sent to the real workspace.
"""
import importlib.util,json,os,subprocess,time,urllib.request,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('u',Path(__file__).with_name('appium-ui.py'));u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture'
adb=[os.environ['ADB']]
if os.environ.get('ANDROID_SERIAL'):adb+=['-s',os.environ['ANDROID_SERIAL']]
def shell(*args):return subprocess.check_output(adb+['shell',*args],text=True).strip()
night=shell('cmd','uimode','night').split(':')[-1].strip()
assert night in ('auto','yes','no','custom'),night
font=shell('settings','get','system','font_scale')
s=u.Session()
def mode(value):
 shell('cmd','uimode','night',value);time.sleep(1)
 s.expect('Mika')
def shot(name):
 assert s.call('/appium/device/current_package')==os.environ['PKG']
 assert '在 Multica' not in s.call('/source')
 s.shot(name)
def overview(prefix):
 s.tap('对话');s.expect('Mika');shot(prefix+'-chat')
 s.tap('项目');s.expect('Loop Project');shot(prefix+'-projects')
 s.tap('设置');s.expect('Runtimes');s.expect('退出登录');shot(prefix+'-settings')
 s.tap('对话')
try:
 # Restart into the single conversation before applying the temporary system theme.
 s.call('/appium/device/terminate_app',{'appId':os.environ['PKG']})
 s.call('/appium/device/activate_app',{'appId':os.environ['PKG']});s.expect('Mika')
 if '--keyboard-only' not in sys.argv:
  req=urllib.request.Request('http://127.0.0.1:8765/__control',data=b'{"design":true}',headers={'Content-Type':'application/json'})
  existing=urllib.request.Request('http://127.0.0.1:8765/api/chat/sessions/s1/messages/page',headers={'Authorization':'Bearer synthetic-device-fixture-token'})
  if not any(m['id']=='design-reply' for m in json.load(urllib.request.urlopen(existing))['messages']):
   urllib.request.urlopen(req).close()
  mode('no');s.tap('设置');s.tap('对话');time.sleep(1)
  overview('light')
  mode('yes');overview('dark')
  mode('no');shell('settings','put','system','font_scale','1.3');time.sleep(1)
  overview('large-font')
 else:mode('no')
 shell('settings','put','system','font_scale','1.0');time.sleep(1)
 e=s.call('/element',{'using':'id','value':'chat-draft'})[u.KEY]
 s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':'帮我整理下一步计划'})
 s.call('/element/'+e+'/click',{})
 assert s.call('/appium/device/is_keyboard_shown')
 s.expect('发送');shot('keyboard')
 s.call('/appium/device/hide_keyboard',{})
 if '--keyboard-only' in sys.argv:
  s.tap('发送');s.expect('CHATTY_CHAT_OK · 帮我整理下一步计划')
  s.tap('项目');s.expect('Loop Project');s.tap('设置');s.expect('Runtimes');s.tap('对话');s.expect('Mika');shot('after-keyboard-send')
  s.checks.append('PASS: keyboard composer, one synthetic send and tab navigation after inset correction')
 else:s.checks.append('PASS: light/dark/1.3x font across three tabs, keyboard composer, native-only navigation')
 print(s.evidence)
except Exception:
 s.checks.append('FAIL: visual acceptance incomplete');s.shot('failure');raise
finally:
 shell('cmd','uimode','night',night)
 if font=='null':shell('settings','delete','system','font_scale')
 else:shell('settings','put','system','font_scale',font)
 s.close()
