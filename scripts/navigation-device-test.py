#!/usr/bin/env python3
"""Pixel navigation continuity; isolated synthetic API, no real-workspace writes."""
import importlib.util,json,os,time,urllib.request,xml.etree.ElementTree as ET
from pathlib import Path
FIXTURE=os.environ.get('CHATTY_FIXTURE_URL','http://127.0.0.1:8765')
spec=importlib.util.spec_from_file_location('u',Path(__file__).with_name('appium-ui.py'));u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
def control(**args):urllib.request.urlopen(urllib.request.Request(FIXTURE+'/__control',data=json.dumps(args).encode(),headers={'Content-Type':'application/json'})).close()
control(navigation=True)
os.environ['PKG']='ai.chatty.app.fixture';s=u.Session()
def element(tag):return s.call('/element',{'using':'id','value':tag})[u.KEY]
def fill(tag,text):
 e=element(tag);s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':text})
 if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
def value(tag):return s.call('/element/'+element(tag)+'/text')
def scroll(tag,direction):s.call('/execute/sync',{'script':'mobile: scrollGesture','args':[{'elementId':element(tag),'direction':direction,'percent':.9}]})
def back():s.call('/back',{})
def shot(name):
 assert s.call('/appium/device/current_package')==os.environ['PKG']
 assert '在 Multica' not in s.call('/source')
 s.shot(name)
try:
 if s.find('获取验证码'):
  fill('email','fixture@example.test');s.tap('获取验证码');fill('code','123456');s.tap('登录并连接');s.expect('选择工作区')
 if s.find('选择工作区'):s.tap('Loop Test Workspace')
 s.expect('Mika');s.expect('已连接');fill('chat-draft','navigation-draft')
 s.tap('项目');s.expect('Loop Project');s.tap('Loop Project');s.expect('共 55 个 · 已加载 50 个')
 s.tap('全部状态');s.tap('待开始');s.expect('共 30 个 · 已加载 30 个')
 fill('issue-search','Issue 0');s.tap('搜索');s.expect('共 9 个 · 已加载 9 个')
 s.tap('Issue 01');s.expect('返回 Issues');s.expect('Synthetic issue description')
 s.tap('设置');s.tap('Runtimes');s.tap('Loop Runtime');s.expect('返回 Runtimes');s.expect('Synthetic Mac');shot('runtime-detail')
 s.tap('对话');assert value('chat-draft')=='navigation-draft'
 s.tap('项目');s.expect('返回 Issues');s.expect('Issue 01');shot('issue-detail')
 back();s.expect('共 9 个 · 已加载 9 个');assert value('issue-search')=='Issue 0';s.expect('待开始')
 # An unsubmitted search draft and the loaded query are separate state.
 fill('issue-search','unsent search');s.tap('设置');s.expect('返回 Runtimes');s.tap('项目');assert value('issue-search')=='unsent search'
 fill('issue-search','');s.tap('搜索');s.expect('共 30 个 · 已加载 30 个');s.tap('待开始');s.tap('全部状态');s.expect('共 55 个 · 已加载 50 个')
 for _ in range(25):
  if s.find('加载更多 Issues'):break
  scroll('issues-list','down')
 s.tap('加载更多 Issues');s.expect('共 55 个 · 已加载 55 个')
 for _ in range(5):
  if s.find('Issue 55'):break
  scroll('issues-list','down')
 s.expect('Issue 55');shot('paged-list-before')
 s.tap('Issue 55');s.expect('返回 Issues');s.tap('对话');s.tap('项目');s.expect('返回 Issues');s.expect('Issue 55')
 back();s.expect('共 55 个 · 已加载 55 个');s.expect('Issue 55')
 s.tap('设置');s.expect('返回 Runtimes');s.tap('项目');s.expect('共 55 个 · 已加载 55 个');s.expect('Issue 55');shot('paged-list-after')
 # Retain reading position, not just the conversation draft.
 s.tap('对话')
 for _ in range(4):scroll('chat-messages','up')
 labels=[e.attrib['text'] for e in ET.fromstring(s.call('/source')).iter() if e.attrib.get('text','').startswith('历史消息')]
 assert labels, 'No historical message visible'
 anchor=labels[0];s.tap('设置');s.tap('对话');s.expect(anchor);shot('chat-position-retained')
 # Send continues after leaving its tab; only the synthetic service receives it.
 fill('chat-draft','navigation-loop-send');s.tap('发送');s.tap('项目');s.expect('Issue 55');s.tap('对话');s.expect('CHATTY_CHAT_OK · navigation-loop-send')
 s.tap('设置');s.expect('返回 Runtimes');back();s.expect('Loop Runtime');back();s.expect('切换工作区')
 s.tap('切换工作区');s.expect('当前工作区');s.expect('Second Workspace');shot('workspace-sheet');s.tap('取消');s.expect('Runtimes')
 s.tap('项目');s.expect('Issue 55');s.tap('设置');s.tap('切换工作区');back();s.expect('Runtimes')
 s.tap('切换工作区');s.tap('Loop Test Workspace');s.expect('Runtimes');s.tap('项目');s.expect('Issue 55')
 s.tap('设置');s.tap('切换工作区');control(status=503);s.tap('重新加载');s.expect('暂时无法连接，请重试。已有登录信息会保留。');shot('workspace-reload-error');s.tap('取消');s.expect('Runtimes');control(status=200)
 s.tap('切换工作区');s.expect('Second Workspace');s.tap('Second Workspace');s.expect('Mika')
 assert value('chat-draft')=='';s.tap('项目');s.expect('Second Project');assert not s.find('Loop Project');shot('second-workspace')
 s.tap('设置');s.tap('切换工作区');s.tap('Loop Test Workspace');s.expect('Mika');s.tap('项目');s.expect('Loop Project');assert not s.find('Second Project')
 calls=json.load(urllib.request.urlopen(FIXTURE+'/__calls'))
 assert calls['send_count']==1;assert calls['issue_writes']==[]
 assert any(c['workspace']=='second' and c['path']=='/api/projects' for c in calls['calls'])
 (s.evidence/'fixture-calls.json').write_text(json.dumps(calls,ensure_ascii=False,indent=2)+'\n')
 s.checks.append('PASS: retained detail/filter/query/pages/scroll, hierarchical Back, cancellable sheet, same-workspace no-op, 503 recovery, workspace isolation, one synthetic send')
 print(s.evidence)
except Exception:s.checks.append('FAIL: continuity scenario incomplete');shot('failure');raise
finally:control(status=200);s.close()
