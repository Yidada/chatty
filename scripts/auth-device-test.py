#!/usr/bin/env python3
import importlib.util,json,os,subprocess,time,urllib.request
from pathlib import Path
spec=importlib.util.spec_from_file_location('appium_ui',Path(__file__).with_name('appium-ui.py'))
u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture'
s=u.Session()
def control(status):
 req=urllib.request.Request('http://127.0.0.1:8765/__control',data=json.dumps({'status':status}).encode(),headers={'Content-Type':'application/json'})
 urllib.request.urlopen(req).close()
def fill(id,value):
 e=s.call('/element',{'using':'id','value':id})[u.KEY]
 s.call('/element/'+e+'/clear',{})
 s.call('/element/'+e+'/value',{'text':value})
def hide():
 if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
def restart():
 s.call('/appium/device/terminate_app',{'appId':os.environ['PKG']})
 s.call('/appium/device/activate_app',{'appId':os.environ['PKG']})
try:
 control(200)
 if s.find('更换邮箱'): s.tap('更换邮箱')
 s.expect('获取验证码')
 # Validation rejects empty email before any network action.
 assert s.find('获取验证码')
 fill('email','fixture@example.test');hide();s.tap('获取验证码')
 s.expect('验证码已发送，请查看邮箱。')
 fill('code','000000');hide();s.tap('登录并连接')
 s.expect('请求未通过，请检查邮箱和验证码。');s.shot('invalid-code')
 fill('code','123456');hide();s.tap('登录并连接')
 s.tap('Loop Test Workspace');s.expect('工作区已连接');s.shot('connected')
 raw=subprocess.check_output([os.environ['ADB'],'exec-out','run-as',os.environ['PKG'],'cat','shared_prefs/chatty_session.xml'])
 assert b'synthetic-device-fixture-token' not in raw, 'Credential persisted in plaintext'
 s.checks.append('PASS: JWT absent from plaintext preference bytes')
 restart();s.expect('工作区已连接');s.shot('cold-start-restored')
 s.tap('Loop Test Workspace');control(503);s.tap('重新加载')
 s.expect('暂时无法连接，请重试。已有登录信息会保留。');s.shot('server-503')
 restart();s.expect('暂时无法连接，请重试。已有登录信息会保留。')
 control(200);s.tap('重新加载');s.expect('工作区已连接');s.shot('recovered')
 s.tap('Loop Test Workspace');control(401);s.tap('重新加载')
 s.expect('获取验证码');s.shot('unauthorized-login')
 restart();s.expect('获取验证码')
 calls=json.load(urllib.request.urlopen('http://127.0.0.1:8765/__calls'))
 assert all(c['authenticated'] for c in calls)
 assert any(c['workspace']=='fixture' for c in calls)
 (s.evidence/'fixture-calls.json').write_text(json.dumps(calls,indent=2))
 s.checks.append('PASS: fixture login, invalid code, secure cold start, 503 preserves credentials, 401 clears credentials')
 print(s.checks[-1])
except Exception:
 s.checks.append('FAIL: auth fixture loop incomplete');s.shot('failure');raise
finally:
 control(200);s.close()
