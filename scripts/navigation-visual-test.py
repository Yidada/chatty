#!/usr/bin/env python3
"""Check new detail pages and workspace sheet on Pixel; restores system preferences."""
import importlib.util,os,subprocess
from pathlib import Path
spec=importlib.util.spec_from_file_location('u',Path(__file__).with_name('appium-ui.py'));u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture'
adb=[os.environ['ADB']]
if os.environ.get('ANDROID_SERIAL'):adb+=['-s',os.environ['ANDROID_SERIAL']]
def shell(*args):return subprocess.check_output(adb+['shell',*args],text=True).strip()
night=shell('cmd','uimode','night').split(':')[-1].strip();font=shell('settings','get','system','font_scale')
assert night in ('auto','yes','no','custom')
s=u.Session()
def restart():
 s.call('/appium/device/terminate_app',{'appId':os.environ['PKG']});s.call('/appium/device/activate_app',{'appId':os.environ['PKG']});s.expect('Mika')
try:
 for prefix,theme,scale in [('dark','yes','1.0'),('large-font','no','1.3')]:
  shell('cmd','uimode','night',theme);shell('settings','put','system','font_scale',scale);restart()
  s.tap('项目');s.tap('Loop Project');s.tap('Issue 01');s.expect('返回 Issues');s.expect('Synthetic issue description');s.shot(prefix+'-issue')
  s.tap('设置');s.tap('Runtimes');s.tap('Loop Runtime');s.expect('返回 Runtimes');s.expect('Synthetic Mac');s.shot(prefix+'-runtime');s.tap('返回 Runtimes');s.tap('返回设置')
  s.tap('切换工作区');s.expect('当前工作区');s.expect('取消');s.shot(prefix+'-sheet');s.tap('取消');s.expect('Runtimes')
 s.checks.append('PASS: dark and 1.3x font detail/sheet checks, full-page native return paths')
except Exception:s.checks.append('FAIL: visual check incomplete');s.shot('failure');raise
finally:
 shell('cmd','uimode','night',night)
 if font=='null':shell('settings','delete','system','font_scale')
 else:shell('settings','put','system','font_scale',font)
 s.close()
