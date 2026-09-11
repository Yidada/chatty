#!/usr/bin/env python3
"""Generate the deterministic native project and isolated fixture scheme."""
from pathlib import Path
import hashlib,json,plistlib
root=Path(__file__).resolve().parents[1]/'ios'; objects={}
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def obj(key,isa,**kw):
 i=uid(key);objects[i]={'isa':isa,**kw};return i
def cfgs(key,base):
 refs=[]
 for mode in ('Debug','Release'):
  settings={**base,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'}
  if mode=='Debug':settings.update(ENABLE_TESTABILITY='YES',ONLY_ACTIVE_ARCH='YES')
  refs.append(obj(key+mode,'XCBuildConfiguration',buildSettings=settings,name=mode))
 return obj(key+'configs','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
files={}
for folder in ('Chatty','Fixture','Tests'):
 for p in sorted((root/folder).glob('*.swift')):
  files[str(p.relative_to(root))]=obj(str(p.relative_to(root)),'PBXFileReference',lastKnownFileType='sourcecode.swift',path=p.name,sourceTree='<group>')
groups=[obj(folder+'group','PBXGroup',children=[v for k,v in files.items() if k.startswith(folder+'/')],path=folder,sourceTree='<group>') for folder in ('Chatty','Fixture','Tests')]
assets=obj('app-assets','PBXFileReference',lastKnownFileType='folder.assetcatalog',path='Chatty/Assets.xcassets',sourceTree='<group>')
privacy=obj('app-privacy','PBXFileReference',lastKnownFileType='text.xml',path='Config/PrivacyInfo.xcprivacy',sourceTree='<group>')
package=obj('package','XCLocalSwiftPackageReference',relativePath='Packages/ChattyKit')
productrefs=[];targets=[]
for name in ('Chatty','ChattyFixture','ChattyFixtureTests'):
 test=name.endswith('Tests'); fixture=name=='ChattyFixture'
 ext='xctest' if test else 'app'
 prod=obj(name+'product','PBXFileReference',explicitFileType='wrapper.cfbundle' if test else 'wrapper.application',includeInIndex='0',path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR');productrefs.append(prod)
 paths=[k for k in files if k.startswith('Tests/' if test else 'Chatty/') or (fixture and k.startswith('Fixture/'))]
 sources=obj(name+'sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=[obj(name+k,'PBXBuildFile',fileRef=files[k]) for k in paths],runOnlyForDeploymentPostprocessing='0')
 deps=[];frameworks=[]
 for product in (['ChattyCore','ChattyFixtureSupport'] if fixture else ['ChattyCore']):
  dep=obj(name+product,'XCSwiftPackageProductDependency',package=package,productName=product);deps.append(dep);frameworks.append(obj(name+product+'build','PBXBuildFile',productRef=dep))
 fw=obj(name+'frameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files=frameworks,runOnlyForDeploymentPostprocessing='0')
 res=obj(name+'resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=[] if test else [obj(name+'assets-build','PBXBuildFile',fileRef=assets),obj(name+'privacy-build','PBXBuildFile',fileRef=privacy)],runOnlyForDeploymentPostprocessing='0')
 settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'ai.chatty.ios'+('.fixture.tests' if test else '.fixture' if fixture else ''),'CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SWIFT_VERSION':'6.0','IPHONEOS_DEPLOYMENT_TARGET':'26.0','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks'],'MARKETING_VERSION':'0.2.0','CURRENT_PROJECT_VERSION':'3'}
 if test:settings.update(GENERATE_INFOPLIST_FILE='YES',TEST_HOST='$(BUILT_PRODUCTS_DIR)/ChattyFixture.app/ChattyFixture',BUNDLE_LOADER='$(TEST_HOST)')
 else:settings.update(INFOPLIST_FILE='Config/'+name+'-Info.plist',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon')
 if fixture:settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='$(inherited) CHATTY_FIXTURE'
 targetdeps=[]
 if test:
  proxy=obj('testproxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType='1',remoteGlobalIDString=uid('ChattyFixturetarget'),remoteInfo='ChattyFixture')
  targetdeps=[obj('testdependency','PBXTargetDependency',target=uid('ChattyFixturetarget'),targetProxy=proxy)]
 targets.append(obj(name+'target','PBXNativeTarget',buildConfigurationList=cfgs(name,settings),buildPhases=[sources,fw,res],buildRules=[],dependencies=targetdeps,name=name,packageProductDependencies=deps,productName=name,productReference=prod,productType='com.apple.product-type.bundle.unit-test' if test else 'com.apple.product-type.application'))
products=obj('products','PBXGroup',children=productrefs,name='Products',sourceTree='<group>')
main=obj('main','PBXGroup',children=groups+[assets,privacy,products],sourceTree='<group>')
project=obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2660'},buildConfigurationList=cfgs('project',{'SDKROOT':'iphoneos','SWIFT_VERSION':'6.0','SWIFT_STRICT_CONCURRENCY':'complete','CLANG_ENABLE_MODULES':'YES','IPHONEOS_DEPLOYMENT_TARGET':'26.0'}),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings='0',knownRegions=['en','Base','zh-Hans'],mainGroup=main,packageReferences=[package],productRefGroup=products,projectDirPath='',projectRoot='',targets=targets)
def encode(x,level=0):
 if isinstance(x,dict):return '{\n'+''.join('\t'*(level+1)+json.dumps(k)+' = '+encode(v,level+1)+';\n' for k,v in x.items())+'\t'*level+'}'
 if isinstance(x,list):return '('+', '.join(encode(v,level) for v in x)+')'
 return json.dumps(x,ensure_ascii=False)
p=root/'Chatty.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project})+'\n')
(root/'Config').mkdir(exist_ok=True)
orientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']
for name in ('Chatty','ChattyFixture'):
 info={'CFBundleDevelopmentRegion':'$(DEVELOPMENT_LANGUAGE)','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundleDisplayName':'Chatty Test' if name.endswith('Fixture') else 'Chatty','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':True},'UILaunchScreen':{},'UISupportedInterfaceOrientations':orientations,'UISupportedInterfaceOrientations~ipad':orientations}
 if name.endswith('Fixture'):
  info['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
  info['UIFileSharingEnabled']=True
  info['LSSupportsOpeningDocumentsInPlace']=True
 (root/'Config'/f'{name}-Info.plist').write_bytes(plistlib.dumps(info))
schemes=p/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name+"target")}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:Chatty.xcodeproj"/>'
for name in ('Chatty','ChattyFixture'):
 testable=f'<Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("ChattyFixtureTeststarget")}" BuildableName="ChattyFixtureTests.xctest" BlueprintName="ChattyFixtureTests" ReferencedContainer="container:Chatty.xcodeproj"/></TestableReference></Testables>' if name.endswith('Fixture') else '<Testables/>'
 (schemes/(name+'.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(name)}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">{testable}</TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(name)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(name)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Created Xcode project and shared schemes')
