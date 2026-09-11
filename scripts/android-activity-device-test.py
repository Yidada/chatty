import importlib.util,os,time,json,urllib.request
from pathlib import Path
p=Path(__file__).with_name('appium-ui.py');sp=importlib.util.spec_from_file_location('u',p);u=importlib.util.module_from_spec(sp);sp.loader.exec_module(u)
s=u.Session()
def fill(id,text):
 e=s.call('/element',{'using':'id','value':id})[u.KEY];s.call('/element/'+e+'/clear',{});s.call('/element/'+e+'/value',{'text':text})
def hide():
 if s.call('/appium/device/is_keyboard_shown'):s.call('/appium/device/hide_keyboard',{})
try:
 time.sleep(2)
 if s.find('获取验证码'):
  fill('email','fixture@example.test');hide();s.tap('获取验证码');fill('code','123456');hide();s.tap('登录并连接');s.expect('选择工作区')
 if s.find('选择工作区'):s.tap('Loop Test Workspace')
 s.tap('动态');s.expect('最近动态');s.tap('待关注 2');s.expect('待验收');s.expect('受阻');s.expect('另一位成员的任务需要补充权限');s.shot('attention-groups')
 s.tap('登录流程已完成，等待验收');s.expect('验收通过');s.tap('验收通过');s.expect('已验收');s.shot('approved')
 s.tap('动态');s.expect('待关注 1');s.tap('待关注 1');s.expect('另一位成员的任务需要补充权限');s.tap('另一位成员的任务需要补充权限');s.expect('讨论不会自动解除阻塞。补充信息后，需任务状态更新才会移出待关注。');s.shot('blocked')
 print('DEVICE PASS')
except:
 s.shot('failure');raise
finally:s.close()
