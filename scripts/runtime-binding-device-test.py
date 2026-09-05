#!/usr/bin/env python3
"""Pixel regression: binding changes converge without restarting retained Chat."""
import importlib.util, json, os, time, urllib.request
from pathlib import Path
spec=importlib.util.spec_from_file_location('u',Path(__file__).with_name('appium-ui.py'))
u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture'
s=u.Session(); fixture='http://127.0.0.1:8875'; warning='此 Agent 尚未绑定 Runtime'
def fill(tag,text):
    e=s.call('/element',{'using':'id','value':tag})[u.KEY]
    s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':text})
    if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
def enabled():
    e=s.call('/element',{'using':'id','value':'chat-send'})[u.KEY]
    return s.call('/element/'+e+'/attribute/enabled')=='true'
def control(**body):
    with urllib.request.urlopen(urllib.request.Request(fixture+'/__runtime',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})) as r: return json.load(r)
def check(bound,name):
    for _ in range(30):
        if enabled()==bound and bool(s.find(warning))== (not bound):break
        time.sleep(.3)
    assert enabled()==bound, name+': send availability'
    assert bool(s.find(warning))==(not bound),name+': binding warning'
    s.expect('retained runtime check');s.shot(name)
    s.checks.append('PASS: '+name+' preserves draft without process restart')
try:
    if s.find('获取验证码'):
        fill('email','fixture@example.test');s.tap('获取验证码');fill('code','123456');s.tap('登录并连接');s.expect('选择工作区')
    if s.find('选择工作区'):s.tap('Loop Test Workspace')
    s.expect('Mika');s.expect(warning);fill('chat-draft','retained runtime check');check(False,'initial-unbound')
    control(bound=True)
    s.tap('设置');s.tap('Agents');s.tap('Mika Renamed');s.expect('Loop Runtime');s.tap('对话')
    check(True,'tab-return-recovers-binding')
    control(bound=False);s.tap('刷新对话');check(False,'manual-refresh-recognizes-unbind')
    control(bound=True);s.tap('刷新对话');check(True,'manual-refresh-recognizes-rebind')
    control(failure=True);s.tap('刷新对话');s.expect('暂时无法连接，请重试。草稿已保留。')
    assert not enabled();s.expect('retained runtime check');s.shot('context-failure-keeps-draft')
    s.checks.append('PASS: failed capability refresh blocks stale send and preserves draft')
    control(failure=False);s.tap('刷新对话');check(True,'retry-recovers-binding')
    s.tap('发送');s.expect('CHATTY_CHAT_OK · retained runtime check');s.shot('single-send-completes')
    with urllib.request.urlopen(fixture+'/__calls') as r:calls=json.load(r)
    assert calls['send_count']==1;assert calls['issue_writes']==[]
    (s.evidence/'fixture-calls.json').write_text(json.dumps(calls,ensure_ascii=False,indent=2))
    s.checks.append('PASS: exactly one synthetic send completed after binding; zero issue writes; no process restart')
except Exception:
    s.checks.append('FAIL: runtime binding loop incomplete');s.shot('failure');raise
finally:s.close()
