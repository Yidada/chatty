#!/usr/bin/env python3
"""Three-tab Pixel acceptance against loopback synthetic data only."""
import importlib.util,os,time,json,urllib.request
from pathlib import Path
spec=importlib.util.spec_from_file_location('u',Path(__file__).with_name('appium-ui.py'));u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
os.environ['PKG']='ai.chatty.app.fixture';s=u.Session()
original_shot=s.shot
def native_shot(name):
 source=s.call('/source')
 for forbidden in ['在 Multica', '详细配置在 Multica', '账号设置', '工作区设置', '访问令牌', '偏好设置', '账单', '插件']:
  assert forbidden not in source, 'Unexpected web entry: '+forbidden
 assert s.call('/appium/device/current_package')==os.environ['PKG'], 'Left native app'
 original_shot(name)
s.shot=native_shot
def fill(tag,text):
 e=s.call('/element',{'using':'id','value':tag})[u.KEY];s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':text})
 if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
def scroll(direction):s.call('/execute/sync',{'script':'mobile: scrollGesture','args':[{'left':30,'top':750,'width':1300,'height':1400,'direction':direction,'percent':1.0}]})
try:
 time.sleep(2)
 if s.find('获取验证码'):
  fill('email','fixture@example.test');s.tap('获取验证码');fill('code','123456');s.tap('登录并连接');s.expect('选择工作区')
 if s.find('选择工作区'):s.tap('Loop Test Workspace')
 s.tap('对话');s.expect('Mika');s.expect('已连接');assert not s.find('历史');assert not s.find('新对话');s.shot('mika-only')
 s.tap('项目');s.expect('Loop Project');s.expect('25 / 55 已完成');s.shot('projects')
 before=json.load(urllib.request.urlopen('http://127.0.0.1:8765/__calls'));time.sleep(3);after=json.load(urllib.request.urlopen('http://127.0.0.1:8765/__calls'));assert len(after['calls'])-len(before['calls'])<3,'Unexpected repeated loading'
 s.tap('Loop Project');s.expect('共 55 个 · 已加载 50 个');s.tap('Issue 01');s.expect('Synthetic issue description');s.tap('状态：待开始');s.tap('内部验收');s.expect('状态：内部验收');s.shot('status-updated');s.tap('关闭')
 fill('issue-search','Issue 55');s.tap('搜索');s.expect('共 1 个 · 已加载 1 个');s.expect('Issue 55');s.shot('issue-search')
 fill('issue-search','');s.tap('搜索');s.expect('共 55 个 · 已加载 50 个')
 s.tap('全部状态');s.tap('内部验收');s.expect('共 1 个 · 已加载 1 个');s.expect('Issue 01');s.shot('custom-status-filter')
 s.tap('内部验收');s.tap('全部状态');s.expect('共 55 个 · 已加载 50 个')
 for _ in range(24):
  if s.find('加载更多 Issues'):break
  scroll('down')
 s.tap('加载更多 Issues');s.expect('共 55 个 · 已加载 55 个');s.shot('issue-pagination')
 s.tap('返回项目');s.tap('Empty Project');s.expect('没有符合条件的 Issue。');s.tap('返回项目');s.tap('未归属项目的 Issues');s.expect('Unassigned project issue');s.shot('no-project')
 s.tap('设置');s.expect('切换工作区');s.expect('退出登录');s.expect('Runtimes');s.expect('Agents');s.expect('Squads');s.shot('settings')
 s.tap('Runtimes');s.expect('Loop Runtime');s.tap('Loop Runtime');s.expect('在线');s.shot('runtime-detail');s.tap('关闭');s.tap('返回设置')
 s.tap('Agents');s.expect('Mika Renamed');s.tap('Mika Renamed');s.shot('agent-detail');s.tap('关闭');s.tap('返回设置')
 s.tap('Squads');s.expect('Loop Squad');s.tap('Loop Squad');s.expect('3 位成员');s.shot('squad-detail');s.tap('关闭');s.tap('返回设置')
 for _ in range(3):
  s.tap('对话');s.expect('Mika');assert not s.find('历史');s.tap('项目');s.expect('Loop Project');s.tap('设置');s.expect('Runtimes')
 calls=json.load(urllib.request.urlopen('http://127.0.0.1:8765/__calls'))
 assert len(calls['issue_writes'])==1;assert calls['issue_writes'][0]['suppress_run'] is True;assert calls['issue_writes'][0]['expected_revision']==1
 assert calls['send_count']==0
 (s.evidence/'fixture-calls.json').write_text(json.dumps(calls,ensure_ascii=False,indent=2))
 s.checks.append('PASS: Mika-only, project aggregates, issue status/search/filter/paging/no-project, resource settings, three tab loops; no agent run or chat send')
 print(s.evidence)
except Exception:s.checks.append('FAIL: three-tab acceptance incomplete');s.shot('failure');raise
finally:s.close()
