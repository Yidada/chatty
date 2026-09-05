"""Expected to fail until returning Chat refreshes Mika capabilities. Never sends."""
import importlib.util, json, os, subprocess, time, urllib.request
from pathlib import Path
root = Path(__file__).resolve().parents[5]
spec = importlib.util.spec_from_file_location('u', root/'scripts/appium-ui.py')
u=importlib.util.module_from_spec(spec); spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture'
s=u.Session()
fixture='http://127.0.0.1:8875'
def fill(tag, text):
    e=s.call('/element',{'using':'id','value':tag})[u.KEY]
    s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':text})
    if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
def enabled(text):
    # The icon's semantics stay enabled; the enclosing tagged button owns availability.
    e=s.call('/element',{'using':'id','value':'chat-send'})[u.KEY]
    return s.call('/element/'+e+'/attribute/enabled') == 'true'
def calls(): return json.load(urllib.request.urlopen(fixture+'/__calls'))
warning='此 Agent 尚未绑定 Runtime'
try:
    if s.find('获取验证码'):
        fill('email','fixture@example.test');s.tap('获取验证码');fill('code','123456');s.tap('登录并连接');s.expect('选择工作区')
    if s.find('选择工作区'):s.tap('Loop Test Workspace')
    s.expect('Mika');s.expect(warning);fill('chat-draft','retained runtime check')
    assert not enabled('发送')
    s.shot('before-runtime-bound')
    response=json.load(urllib.request.urlopen(urllib.request.Request(fixture+'/__audit/bind-runtime', data=b'{}', headers={'Content-Type':'application/json'})))
    assert response['runtime_bound'] is True
    s.tap('设置');s.tap('Agents');s.tap('Mika Renamed');s.expect('Loop Runtime')
    s.shot('settings-sees-new-runtime')
    before=calls()
    s.tap('对话');s.expect('Mika');s.tap('刷新对话');time.sleep(2)
    after=calls()
    bug=bool(s.find(warning)) and not enabled('发送')
    s.shot('chat-retains-stale-runtime')
    s.checks.append(('FAIL' if bug else 'PASS')+': Chat recognizes the newly bound Runtime after tab return and refresh')
    reads=after['calls'][len(before['calls']):]
    (s.evidence/'observation.json').write_text(json.dumps({'result':'confirmed_defect' if bug else 'passed','new_runtime':response,'stale_runtime_warning':bool(s.find(warning)),'send_enabled_after_refresh':enabled('发送'),'requests_after_chat_return':reads,'send_count':after['send_count'],'issue_writes':after['issue_writes']},ensure_ascii=False,indent=2)+'\n')
    assert after['send_count']==0 and after['issue_writes']==[]
    # Check the recovery boundary without discarding auth or the persisted draft.
    subprocess.run([os.environ['ADB'],'-s',os.environ['ANDROID_SERIAL'],'shell','am','force-stop',os.environ['PKG']],check=True,capture_output=True)
    subprocess.run([os.environ['ADB'],'-s',os.environ['ANDROID_SERIAL'],'shell','am','start','-n',os.environ['PKG']+'/ai.chatty.app.MainActivity'],check=True,capture_output=True)
    s.expect('Mika');s.expect('已连接');s.expect('retained runtime check')
    assert not s.find(warning);assert enabled('发送')
    s.shot('restart-recovers-runtime')
    s.checks.append('PASS: process restart reloads the Runtime binding and preserves the draft; no send')
    if bug: raise AssertionError('Chat keeps stale runtime binding after tab return and manual refresh')
finally:
    s.close()
