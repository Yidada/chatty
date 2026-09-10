#!/usr/bin/env python3
"""Loopback-only synthetic Chat API + RFC6455 WebSocket; never contacts Multica."""
import os, base64, hashlib, json, re, socket, struct, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs
TOKEN='synthetic-device-fixture-token'
S={'id':'s1','agent_id':'mika','title':'格式与资源验证','status':'active','pinned':True,'has_unread':True,'unread_count':2,'created_at':'2026-09-05T01:00:00Z','updated_at':'2026-09-05T02:00:00Z'}
AGENT={'id':'mika','name':'Mika Renamed','system_key':'mika','owner_id':'u1','runtime_id':'r1','runtime_bound':True,'status':'online'}
A={'id':'file1','filename':'fixture-note.txt','content_type':'text/plain','size_bytes':32,'markdown_url':'/api/attachments/file1/download','download_url':'http://127.0.0.1:8765/files/note.txt'}
IMAGE_A={'id':'native-image-file','filename':'native-preview.png','content_type':'image/png','size_bytes':320,'download_url':'http://127.0.0.1:8765/api/native-image'}
MESSAGES=[{'id':f'm{i:03}','chat_session_id':'s1','role':'user' if i%2 else 'assistant','content':f'历史消息 {i:02}','created_at':f'2026-09-05T01:{i:02}:00Z'} for i in range(55)]
MESSAGES += [{'id':'rich','chat_session_id':'s1','role':'assistant','content':'## 格式验证\n\n**粗体**与[链接](https://multica.ai)\n\n| 项目 | 状态 |\n| --- | --- |\n| 对话 | OK |\n\n- [x] 游标分页\n- [ ] 待办事项\n\n```python\nprint("Chatty")\n```','created_at':'2026-09-05T02:00:00Z','attachments':[A],'quick_actions':[{'label':'继续测试','prompt':'继续测试格式'}]}]
SESSIONS=[S,dict(S,id='s2',title='第二个会话',pinned=False,has_unread=False,unread_count=0),dict(S,id='s3',title='归档会话',status='archived',pinned=False)]
PENDING={};TRACES={};CLIENTS=[];CALLS=[];LOCK=threading.Lock();STATUS=200;SEND_COUNT=0
TASKS={};CANCELLED=set();SLOW=False
ISSUES=[{'id':'i'+str(i),'identifier':'LOOP-'+str(i+1),'title':f'Issue {i+1:02}','status':'todo' if i<30 else 'done','description':'Synthetic issue description','project_id':'p1','revision':1,'priority':'high' if i==0 else 'none'} for i in range(55)]
ISSUES.append({'id':'orphan','identifier':'LOOP-56','title':'Unassigned project issue','status':'todo','project_id':None,'revision':1})
STATUSES=[{'key':'todo','name':'待开始','category':'todo'},{'key':'qa_custom','name':'内部验收','category':'in_review'},{'key':'done','name':'已完成','category':'done'}]
WRITES=[]
NAVIGATION=False

def broadcast(kind,payload):
    data=json.dumps({'type':kind,'payload':payload}).encode()
    packet=b'\x81'+(bytes([len(data)]) if len(data)<126 else b'\x7e'+struct.pack('!H',len(data)))+data
    with LOCK:
        for client in list(CLIENTS):
            try:client.sendall(packet)
            except OSError:CLIENTS.remove(client)

def finish(task,session,text):
    time.sleep(6 if SLOW else 1)
    if task in CANCELLED:return
    trace={'task_id':task,'seq':1,'type':'thinking','content':'检查格式与上下文'}
    TRACES[task]=[trace];broadcast('task:message',trace)
    TRACES[task]+=[{'task_id':task,'seq':2,'type':'tool_use','tool':'fixture_check','input':{'check':'synthetic only'}}]
    broadcast('task:message',TRACES[task][-1])
    time.sleep(6 if SLOW else 2)
    if task in CANCELLED:return
    final='CHATTY_CHAT_OK · '+text
    TRACES[task]+=[{'task_id':task,'seq':3,'type':'text','content':final}]
    broadcast('task:message',TRACES[task][-1])
    msg={'id':'reply-'+task,'chat_session_id':session,'role':'assistant','content':final,'task_id':task,'created_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'elapsed_ms':3000,'quick_actions':[{'label':'继续测试','prompt':'继续测试格式'}]}
    MESSAGES.append(msg)
    cur=PENDING.get(session)
    if cur and cur.get('task_id')==task:
        q=cur.get('queued_tasks') or []
        if q:
            nxt=q.pop(0)
            PENDING[session]={'task_id':nxt['task_id'],'status':'running','created_at':nxt['created_at'],'supports_queue':True,'queued_tasks':q}
            broadcast('task:dispatch',{'task_id':nxt['task_id'],'chat_session_id':session,'status':'running'})
            threading.Thread(target=finish,args=(nxt['task_id'],session,nxt.get('content','')),daemon=True).start()
        else:
            PENDING.pop(session,None)
    broadcast('chat:done',dict(msg,message_id=msg['id']))

class API(BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*args):pass
    def reply(self,code,value,ctype='application/json'):
        body=json.dumps(value,ensure_ascii=False).encode() if ctype=='application/json' else value
        self.send_response(code);self.send_header('Content-Type',ctype);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    def raw(self):
        if self.headers.get('Transfer-Encoding','').lower()!='chunked':return self.rfile.read(int(self.headers.get('Content-Length','0')))
        chunks=[]
        while True:
            n=int(self.rfile.readline().split(b';')[0],16)
            if not n:
                while self.rfile.readline().strip():pass
                break
            chunks.append(self.rfile.read(n));self.rfile.read(2)
        return b''.join(chunks)
    def auth(self):
        valid=self.headers.get('Authorization')=='Bearer '+TOKEN
        CALLS.append({'method':self.command,'path':urlsplit(self.path).path,'authenticated':valid,'workspace':self.headers.get('X-Workspace-Slug')})
        if not valid:self.reply(401,{'error':'unauthorized'});return False
        return True
    def do_POST(self):
        global STATUS,SEND_COUNT,NAVIGATION,SLOW
        raw=self.raw()
        if self.path=='/api/upload-file':
            if not self.auth():return
            return self.reply(200,A)
        body=json.loads(raw or '{}')
        if self.path=='/__control':
            STATUS=body.get('status',200)
            NAVIGATION=body.get('navigation',NAVIGATION)
            SLOW=body.get('slow',SLOW)
            if body.get('design'):
                MESSAGES.extend([
                    {'id':'design-user','chat_session_id':'s1','role':'user','content':'帮我梳理一下项目进度。','created_at':'2026-09-05T08:32:00Z'},
                    {'id':'design-reply','chat_session_id':'s1','role':'assistant','content':'### 进展清晰，继续向前\n\nLoop Project 已完成 **25 / 55** 项工作。\n\n- 核心对话流程已验证\n- 项目进度可以直接在手机上更新\n- 资源状态统一收在设置中\n\n你可以在「项目」中查看待完成的工作。','created_at':'2026-09-05T08:32:01Z'}
                ])
                broadcast('chat:message',{'chat_session_id':'s1'})
            if body.get('native'):
                MESSAGES.extend([
                    {'id':'native-link','chat_session_id':'s1','role':'assistant','content':'[Multica 项目](https://multica.ai/fixture/projects)','created_at':'2026-09-05T08:02:00Z'},
                    {'id':'native-rich','chat_session_id':'s1','role':'assistant','attachments':[IMAGE_A],'content':'```mermaid\ngraph LR\nA-->B\n```\n\n![原生图片](/api/native-image)','created_at':'2026-09-05T08:02:01Z'}
                ])
                broadcast('chat:message',{'chat_session_id':'s1'})
            if body.get('cases'):
                MESSAGES.extend([
                    {'id':'no-response','chat_session_id':'s1','role':'assistant','content':'','task_id':'empty','message_kind':'no_response','created_at':'2026-09-05T08:00:00Z'},
                    {'id':'failure','chat_session_id':'s1','role':'assistant','content':'synthetic provider error','task_id':'failed','failure_reason':'agent_error.provider_network','created_at':'2026-09-05T08:00:01Z'}
                ])
                broadcast('chat:message',{'chat_session_id':'s1'})
            if body.get('disconnect'):
                with LOCK:
                    for c in CLIENTS:
                        try:c.shutdown(socket.SHUT_RDWR)
                        except OSError:pass
                    CLIENTS.clear()
            return self.reply(200,{'ok':True})
        if self.path=='/auth/send-code':return self.reply(200,{'ok':True})
        if self.path=='/auth/verify-code':return self.reply(200,{'token':TOKEN}) if body.get('code')=='123456' else self.reply(400,{'error':'invalid code'})
        if not self.auth():return
        if self.path.endswith('/read'):return self.reply(200,{})
        if self.path=='/api/chat/sessions':
            s=dict(S,id='s'+str(len(SESSIONS)+1),title='新对话',has_unread=False,unread_count=0);SESSIONS.append(s);return self.reply(200,s)
        m=re.fullmatch('/api/chat/sessions/([^/]+)/messages',self.path)
        if m:
            SEND_COUNT+=1;sid=m[1];tid='t'+str(SEND_COUNT);mid='user-'+tid;now=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())
            msg={'id':mid,'chat_session_id':sid,'role':'user','content':body['content'],'task_id':tid,'created_at':now,'attachments':[A] if body.get('attachment_ids') else []}
            MESSAGES.append(msg);TASKS[tid]={'session':sid,'content':body['content'],'message_id':mid}
            cur=PENDING.get(sid)
            if cur and cur.get('task_id'):
                cur.setdefault('queued_tasks',[]).append({'task_id':tid,'status':'queued','created_at':now,'message_id':mid,'content':body['content']})
                cur['supports_queue']=True;queued=True
                broadcast('task:queued',{'task_id':tid,'chat_session_id':sid,'status':'queued'})
            else:
                PENDING[sid]={'task_id':tid,'status':'running','created_at':now,'supports_queue':True,'queued_tasks':[]};queued=False
                threading.Thread(target=finish,args=(tid,sid,body['content']),daemon=True).start()
            return self.reply(200,{'message_id':mid,'task_id':tid,'created_at':now,'queued':queued,'supports_queue':True})
        self.reply(404,{'error':'unknown route'})
    def do_PUT(self):
        body=json.loads(self.raw() or '{}')
        if not self.auth():return
        m=re.fullmatch('/api/issues/([^/]+)',self.path)
        row=next((i for i in ISSUES if m and i['id']==m[1]),None)
        if row is None:return self.reply(404,{'error':'missing'})
        if body.get('suppress_run') is not True:return self.reply(400,{'error':'must suppress execution in fixture'})
        if body.get('expected_revision')!=row['revision']:return self.reply(409,{'error':'stale'})
        row['status']=body['status'];row['revision']+=1;WRITES.append(body)
        return self.reply(200,row)
    def do_GET(self):
        path=urlsplit(self.path).path;q=parse_qs(urlsplit(self.path).query)
        if path=='/ws':return self.websocket()
        if path=='/__calls':return self.reply(200,{'calls':CALLS,'send_count':SEND_COUNT,'issue_writes':WRITES})
        if path=='/files/note.txt':return self.reply(200,b'Chatty attachment preview OK','text/plain')
        if not self.auth():return
        if STATUS!=200:return self.reply(STATUS,{'error':'synthetic failure'})
        if path=='/api/native-image':return self.reply(200,base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAKAAAABkCAIAAACO1KzYAAABB0lEQVR4nO3RAQnAMBDAwPc3GbNYERUxMVNRCuHgBAQy77MIm+sFHGVwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHDfr24QZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHPcDQPd7TSyKeuEAAAAASUVORK5CYII='),'image/png')
        if path=='/api/workspaces':return self.reply(200,[{'id':'w1','slug':'fixture','name':'Loop Test Workspace'}]+([{'id':'w2','slug':'second','name':'Second Workspace'}] if NAVIGATION else []))
        if NAVIGATION and self.headers.get('X-Workspace-Slug')=='second':
            if path=='/api/projects':return self.reply(200,{'projects':[{'id':'second-project','title':'Second Project','issue_count':0,'done_count':0}],'total':1})
            if path=='/api/chat/sessions':return self.reply(200,[])
            if path=='/api/issues':return self.reply(200,{'issues':[],'total':0})
            if path.startswith('/api/issues/'):return self.reply(404,{'error':'missing'})
        if path=='/api/workspaces/w2/members':return self.reply(200,[{'user_id':'u1','role':'member'}])
        if path=='/api/projects':return self.reply(200,{'projects':[{'id':'p1','title':'Loop Project','status':'in_progress','issue_count':55,'done_count':sum(i['status']=='done' for i in ISSUES if i['project_id']=='p1')},{'id':'p2','title':'Empty Project','issue_count':0,'done_count':0}], 'total':2})
        if path=='/api/issue-statuses':return self.reply(200,{'statuses':STATUSES})
        if path=='/api/issues':
            rows=[i for i in ISSUES if (i['project_id']==q['project_id'][0] if q.get('project_id') else i['project_id'] is None if q.get('include_no_project')==['true'] else True)]
            if q.get('status'):rows=[i for i in rows if i['status']==q['status'][0]]
            if q.get('q'):rows=[i for i in rows if q['q'][0].lower() in i['title'].lower()]
            offset=int(q.get('offset',['0'])[0]);limit=int(q.get('limit',['50'])[0]);return self.reply(200,{'issues':rows[offset:offset+limit],'total':len(rows)})
        if path.startswith('/api/issues/'):
            row=next((i for i in ISSUES if i['id']==path.split('/')[-1]),None);return self.reply(200,row) if row else self.reply(404,{'error':'missing'})
        if path=='/api/runtimes':return self.reply(200,[{'id':'r1','name':'Raw runtime name','custom_name':'Loop Runtime','status':'online','provider':'codex','runtime_mode':'local','device_info':'Synthetic Mac','last_seen_at':'2026-09-05T10:00:00Z'}])
        if path=='/api/squads':return self.reply(200,[{'id':'sq1','name':'Loop Squad','description':'Synthetic team','leader_id':'mika','member_count':3}])
        if path=='/api/me':return self.reply(200,{'id':'u1'})
        if path=='/api/agents':return self.reply(200,[AGENT,dict(AGENT,id='private',name='Private Agent',owner_id='someone-else',system_key=None,permission_mode='private')])
        if path=='/api/workspaces/w1/members':return self.reply(200,[{'user_id':'u1','role':'member'}])
        if path=='/api/chat/sessions':return self.reply(200,[dict(s,last_message=next((m for m in reversed(MESSAGES) if m['chat_session_id']==s['id']),None)) for s in SESSIONS])
        if path=='/api/attachments/native-image-file':return self.reply(200,IMAGE_A)
        if path=='/api/attachments/file1':return self.reply(200,A)
        if path=='/api/attachments/file1/content':return self.reply(200,b'Chatty attachment preview OK','text/plain')
        if path=='/api/attachments/file1/download':return self.reply(200,b'Chatty attachment preview OK','text/plain')
        m=re.fullmatch('/api/chat/sessions/([^/]+)/(messages/page|pending-task)',path)
        if m:
            if m[2]=='pending-task':return self.reply(200,PENDING.get(m[1],{'supports_queue':True}))
            rows=[x for x in MESSAGES if x['chat_session_id']==m[1]]
            if q.get('before_id'):
                ids=[x['id'] for x in rows];rows=rows[:ids.index(q['before_id'][0])]
            page=rows[-50:];more=len(rows)>50
            return self.reply(200,{'messages':page,'has_more':more,'next_cursor':{'id':page[0]['id'],'created_at':page[0]['created_at']} if more else None})
        m=re.fullmatch('/api/tasks/([^/]+)/messages',path)
        if m:return self.reply(200,TRACES.get(m[1],[]))
        self.reply(404,{'error':'unknown route'})
    def websocket(self):
        key=self.headers.get('Sec-WebSocket-Key','')
        accept=base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        self.send_response(101);self.send_header('Upgrade','websocket');self.send_header('Connection','Upgrade');self.send_header('Sec-WebSocket-Accept',accept);self.end_headers()
        authenticated=False
        try:
            while True:
                head=self.rfile.read(2)
                if len(head)<2:return
                opcode=head[0]&15;length=head[1]&127
                if length==126:length=struct.unpack('!H',self.rfile.read(2))[0]
                elif length==127:length=struct.unpack('!Q',self.rfile.read(8))[0]
                mask=self.rfile.read(4) if head[1]&128 else b''
                data=self.rfile.read(length)
                if mask:data=bytes(b^mask[i%4] for i,b in enumerate(data))
                if opcode==8:return
                if opcode==9:self.connection.sendall(bytes([0x8a,len(data)])+data);continue
                if opcode==1 and not authenticated:
                    auth=json.loads(data);assert auth.get('type')=='auth' and auth.get('payload',{}).get('token')==TOKEN
                    authenticated=True
                    with LOCK:CLIENTS.append(self.connection)
                    broadcast('auth_ack',{})
        except (OSError,ValueError,AssertionError):pass
        finally:
            with LOCK:
                if self.connection in CLIENTS:CLIENTS.remove(self.connection)

if __name__=='__main__':
    port=int(os.environ.get('CHATTY_FIXTURE_PORT','8765'))
    ThreadingHTTPServer(('127.0.0.1',port),API).serve_forever()
