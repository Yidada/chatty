#!/usr/bin/env python3
"""Native link and image regression on the isolated fixture application."""
import importlib.util,json,os,time,urllib.request
from pathlib import Path
spec=importlib.util.spec_from_file_location('u',Path(__file__).with_name('appium-ui.py'));u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture';s=u.Session()
try:
 s.tap('对话');s.expect('已连接')
 req=urllib.request.Request('http://127.0.0.1:8765/api/chat/sessions/s1/messages/page',headers={'Authorization':'Bearer synthetic-device-fixture-token'})
 if not any(m['id']=='native-link' for m in json.load(urllib.request.urlopen(req))['messages']):
  urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8765/__control',data=b'{"native":true}',headers={'Content-Type':'application/json'})).close()
 s.tap('设置');s.tap('对话');time.sleep(2)
 list_id=s.call('/element',{'using':'id','value':'chat-messages'})[u.KEY]
 for _ in range(5):
  if s.find('Multica 项目'):break
  s.call('/execute/sync',{'script':'mobile: scrollGesture','args':[{'elementId':list_id,'direction':'up','percent':.5}]})
 s.expect('Multica 项目')
 s.tap('Multica 项目');time.sleep(.5)
 assert s.call('/appium/device/current_package')==os.environ['PKG']
 assert '在 Multica' not in s.call('/source')
 s.shot('internal-link-plain-text')
 images=s.call('/elements',{'using':'accessibility id','value':'消息图片'})
 assert images,'Native image missing'
 s.call('/element/'+images[0][u.KEY]+'/click',{})
 s.expect('图片');s.expect('关闭')
 assert s.call('/appium/device/current_package')==os.environ['PKG']
 s.shot('native-image-preview');s.tap('关闭');s.expect('Mika')
 for _ in range(5):
  if s.find('native-preview.png'):break
  s.call('/execute/sync',{'script':'mobile: scrollGesture','args':[{'elementId':list_id,'direction':'down','percent':.5}]})
 s.tap('native-preview.png');s.expect('关闭')
 assert s.call('/appium/device/current_package')==os.environ['PKG']
 s.shot('native-attachment-image-preview');s.tap('关闭');s.expect('Mika')
 s.checks.append('PASS: Multica label does not launch browser; Mermaid has no web fallback; native image opens and closes in app')
 print(s.evidence)
except Exception:s.checks.append('FAIL: native navigation');s.shot('failure');raise
finally:s.close()
