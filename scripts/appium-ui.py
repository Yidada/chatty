#!/usr/bin/env python3
"""Appium W3C client. Exact text assertions, checked HTTP errors, unique evidence."""
import base64, datetime, json, os, pathlib, subprocess, sys, time, urllib.request

URL=os.environ.get('APPIUM_URL','http://127.0.0.1:4725')
KEY='element-6066-11e4-a52e-4f735466cecf'

def request(path, data=None, method=None):
    payload = None if data is None else json.dumps(data).encode()
    req=urllib.request.Request(URL+path,data=payload,headers={'Content-Type':'application/json'},method=method or ('POST' if data is not None else 'GET'))
    with urllib.request.urlopen(req,timeout=90) as r:
        value=json.load(r)['value']
    if isinstance(value,dict) and value.get('error'): raise AssertionError(value)
    return value

class Session:
    def __init__(self):
        self.sid=None
        serial=os.environ.get('ANDROID_SERIAL')
        if not serial:
            lines=subprocess.check_output([os.environ['ADB'],'devices'],text=True).splitlines()[1:]
            devices=[l.split()[0] for l in lines if len(l.split())>=2 and l.split()[1]=='device' and not l.startswith('emulator-')]
            assert len(devices)==1,'Specify ANDROID_SERIAL or connect one physical phone'
            serial=devices[0]
        caps={'platformName':'Android','appium:automationName':'UiAutomator2','appium:udid':serial,'appium:appPackage':os.environ.get('PKG','ai.chatty.app.debug'),'appium:appActivity':os.environ.get('ACT','ai.chatty.app.MainActivity'),'appium:noReset':True,'appium:newCommandTimeout':120}
        self.evidence=pathlib.Path(os.environ.get('EVIDENCE_DIR',str(pathlib.Path(__file__).resolve().parents[1]/'iterations/v2/evidence'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f-ui'))))
        self.evidence.mkdir(parents=True,exist_ok=False)
        self.sid=request('/session',{'capabilities':{'alwaysMatch':caps}})['sessionId']
        self.call('/appium/settings', {'settings': {'disableIdLocatorAutocompletion': True}})
        self.checks=[]
    def call(self,path,data=None): return request('/session/'+self.sid+path,data)
    def find(self,text):
        # JSON serialization and XPath literal handle quotes without shell interpolation.
        literal='"'+text+'"' if '"' not in text else "'"+text+"'"
        return self.call('/elements',{'using':'xpath','value':'//*[@text='+literal+' or @content-desc='+literal+']'})
    def expect(self,text):
        for _ in range(20):
            if self.find(text):
                self.checks.append('PASS: '+text);print(self.checks[-1]);return
            time.sleep(.5)
        raise AssertionError('Not visible: '+text)
    def tap(self,text):
        self.expect(text)
        elements=self.find(text)
        self.call('/element/'+elements[0][KEY]+'/click',{})
    def shot(self,name):
        (self.evidence/(name+'.png')).write_bytes(base64.b64decode(self.call('/screenshot')))
        (self.evidence/(name+'.xml')).write_text(self.call('/source'))
    def close(self):
        (self.evidence/'result.json').write_text(json.dumps({'session':self.sid,'checks':self.checks},ensure_ascii=False,indent=2))
        request('/session/'+self.sid,method='DELETE')

if __name__=='__main__':
    s=Session()
    try:
        if len(sys.argv)>1 and sys.argv[1]=='--shell-loop':
            s.expect('Mika')
            s.shot('chat')
            for n in range(3):
                s.tap('项目');s.expect('按项目查看所有 Issues 的进度')
                s.tap('设置');s.expect('Runtimes')
                s.tap('对话');s.expect('Mika')
            s.shot('after-three-loops')
        else:
            if len(sys.argv)>1 and sys.argv[1]: s.expect(sys.argv[1])
            if len(sys.argv)>2 and sys.argv[2]:
                s.tap(sys.argv[2]);time.sleep(float(sys.argv[3]) if len(sys.argv)>3 else 1)
            if len(sys.argv)>4 and sys.argv[4]: s.expect(sys.argv[4])
            s.shot('screen')
        s.checks.append('PASS: scenario complete')
        print('PASS:',s.evidence)
    except Exception:
        s.checks.append('FAIL: scenario incomplete')
        s.shot('failure')
        raise
    finally: s.close()
