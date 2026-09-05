#!/usr/bin/env python3
"""Pixel loop against isolated synthetic API; no external messages."""
import importlib.util,json,os,time,urllib.request
from pathlib import Path
FIXTURE=os.environ.get('CHATTY_FIXTURE_URL','http://127.0.0.1:8765')
spec=importlib.util.spec_from_file_location('ui',Path(__file__).with_name('appium-ui.py'));u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture';s=u.Session()
def fill(id,value):
 e=s.call('/element',{'using':'id','value':id})[u.KEY];s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':value})
def hide():
 if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
def control(**kwargs):
 urllib.request.urlopen(urllib.request.Request(FIXTURE+'/__control',data=json.dumps(kwargs).encode(),headers={'Content-Type':'application/json'})).close()
def scroll(direction,percent=.9):s.call('/execute/sync',{'script':'mobile: scrollGesture','args':[{'left':30,'top':600,'width':1300,'height':1700,'direction':direction,'percent':percent}]})
try:
 time.sleep(2)
 if s.find('获取验证码'):
  fill('email','fixture@example.test');hide();s.tap('获取验证码');fill('code','123456');hide();s.tap('登录并连接');s.expect('选择工作区')
 if s.find('Loop Test Workspace') and s.find('选择工作区'):s.tap('Loop Test Workspace')
 s.tap('对话');s.expect('已连接');s.expect('Mika');time.sleep(1);s.shot('rich-content')
 s.tap('fixture-note.txt');s.expect('Chatty attachment preview OK');s.shot('attachment-preview');s.tap('关闭')
 s.tap('继续测试');e=s.call('/element',{'using':'id','value':'chat-draft'})[u.KEY]
 assert '继续测试格式' in s.call('/element/'+e+'/text')
 fill('chat-draft','loop-round-1');hide();s.tap('发送');s.expect('CHATTY_CHAT_OK · loop-round-1');s.shot('reply-round-1')
 s.tap('▸ 任务过程 · 2 项');s.expect('工具 · fixture_check');s.shot('task-trace');s.tap('▾ 任务过程 · 2 项')
 # Drop the socket and let automatic reconnect converge from REST.
 control(disconnect=True);s.expect('已连接')
 fill('chat-draft','loop-round-2');hide();s.tap('发送');s.expect('CHATTY_CHAT_OK · loop-round-2');s.shot('reconnected-reply')
 # Leaving the single Mika page preserves its local draft.
 fill('chat-draft','draft-retained');hide();s.tap('设置');s.expect('Runtimes');s.tap('对话');s.expect('Mika')
 assert not s.find('历史');assert not s.find('新对话')
 e=s.call('/element',{'using':'id','value':'chat-draft'})[u.KEY];assert 'draft-retained' in s.call('/element/'+e+'/text')
 # Force stop, relaunch, refetch backend messages and recover only the local draft.
 s.call('/appium/device/terminate_app',{'appId':os.environ['PKG']});s.call('/appium/device/activate_app',{'appId':os.environ['PKG']})
 s.expect('Mika');s.expect('CHATTY_CHAT_OK · loop-round-2')
 e=s.call('/element',{'using':'id','value':'chat-draft'})[u.KEY];assert 'draft-retained' in s.call('/element/'+e+'/text');s.shot('cold-start')
 # Scroll to the cursor boundary and load the oldest six rows.
 for _ in range(30):
  if s.find('加载更早消息'):break
  scroll('up',1.0)
 s.tap('加载更早消息');s.expect('历史消息 00');s.shot('cursor-page')
 # Return to the bottom before new fixture messages arrive.
 for _ in range(30):
  if s.find('CHATTY_CHAT_OK · loop-round-2'):break
  scroll('down',1.0)
 s.expect('CHATTY_CHAT_OK · loop-round-2')
 control(cases=True);s.expect('连接模型服务失败，请检查网络后重试。');s.tap('▸ 错误详情');s.expect('synthetic provider error');s.shot('failure-detail')
 s.expect('任务已结束，没有生成回复。')
 control(status=503);s.tap('刷新对话');time.sleep(1)
 s.expect('暂时无法连接，请重试。草稿已保留。');s.shot('rest-error')
 control(status=200);s.tap('刷新对话');s.expect('连接模型服务失败，请检查网络后重试。')
 calls=json.load(urllib.request.urlopen(FIXTURE+'/__calls'))
 assert calls['send_count']==2,calls['send_count']
 assert all(c['authenticated'] for c in calls['calls'])
 (s.evidence/'fixture-calls.json').write_text(json.dumps(calls,ensure_ascii=False,indent=2))
 s.checks.append('PASS: rich content, fresh attachment preview, quick action, two sends, traces, reconnect, drafts, cold start, cursor, Mika-only navigation')
 print(s.checks[-1]);print(s.evidence)
except Exception:
 s.checks.append('FAIL: chat loop incomplete');s.shot('failure');raise
finally:s.close()
