#!/usr/bin/env python3
"""Build once, run XCUITest flows continuously, and synchronize simulator capture."""
import argparse, datetime, hashlib, json, os, pathlib, plistlib, shutil, signal, subprocess, tempfile, time, uuid, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT_ID = hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]
BUILD = pathlib.Path(tempfile.gettempdir()) / ('waypoint-recordings-' + PROJECT_ID)
LOCK = pathlib.Path(tempfile.gettempdir()) / ('waypoint-validation-' + PROJECT_ID + '.lock')
NAMES = ['b01-stack-navigation','b02-switch-then-push','b03-independent-tab-history','b04-background-tab-routing','b05-sheet-round-trip','b06-sheet-replacement','b07-replace-sheet-from-detail','b08-local-sheet-navigation','b09-dismiss-and-reopen','b10-sheet-to-utility-ios','c01-router-push-in-sheet','c02-open-class-through-parent','c03-open-class-directly','c04-reuse-existing-context','c05-nested-sheet','c06-external-root-override','w04-iphone-editor-fallback']
FILES = {name.split('-')[0].upper(): name + '.mp4' for name in NAMES}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--flows', default='B07', help='Comma-separated flow IDs, all, or FAILURE')
    parser.add_argument('--check', action='store_true', help='Run state checks with capture disabled')
    parser.add_argument('--build', action='store_true', help='Build app and UI runner before executing')
    parser.add_argument('--build-directory', type=pathlib.Path, default=BUILD)
    parser.add_argument('--output', type=pathlib.Path)
    parser.add_argument('--xcode', default='/Applications/Xcode 27.1-1.app')
    args=parser.parse_args()
    build=args.build_directory.resolve()
    flows=list(FILES) if args.flows=='all' else args.flows.upper().split(',')
    if any(f not in FILES and f!='FAILURE' for f in flows): parser.error('Unknown flow ID')
    if shutil.disk_usage(ROOT).free<20*1024**3: raise RuntimeError('At least 20 GB free required')
    run_id=str(uuid.uuid4())
    out=args.output or ROOT/'Resources/Recordings'/('run-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S'))
    out=out.resolve();out.mkdir(parents=True,exist_ok=False)
    env=os.environ.copy();env['DEVELOPER_DIR']=args.xcode+'/Contents/Developer'
    env['CLANG_MODULE_CACHE_PATH']=str(build/'module-cache')
    def command(parts, **kw): return subprocess.run(parts,env=env,check=True,**kw)
    resource_id=hashlib.sha256(str(build).encode()).hexdigest()[:12]
    locks=[LOCK, pathlib.Path(tempfile.gettempdir())/('waypoint-build-'+resource_id+'.lock'), pathlib.Path(tempfile.gettempdir())/('waypoint-simulator-'+args.simulator+'.lock')]
    acquired=[]
    try:
        for lock in locks:
            lock.mkdir(); acquired.append(lock)
            (lock/'owner.json').write_text(json.dumps({'task':'Waypoint scripted recording','pid':os.getpid(),'project':str(ROOT),'output':str(build),'simulator':args.simulator}))
    except BaseException:
        for lock in acquired:shutil.rmtree(lock)
        raise
    manifest={'runID':run_id,'flows':flows,'mode':'checks' if args.check else 'recording','clips':[],'status':'running','simulatorUUID':args.simulator}
    capture=None;test=None;handles=[]
    def save(): (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    def stop_capture():
        nonlocal capture
        if capture:
            process,handle=capture
            if process.poll() is None: process.send_signal(signal.SIGINT)
            try: process.wait(timeout=30)
            except subprocess.TimeoutExpired: process.terminate();process.wait(timeout=10)
            handle.close();capture=None
            if process.returncode: raise RuntimeError('Capture finalization failed')
    try:
        devices=json.loads(command(['xcrun','simctl','list','devices','available','--json'],capture_output=True,text=True).stdout)
        selected=[(runtime,d) for runtime,ds in devices['devices'].items() for d in ds if d['udid']==args.simulator]
        if len(selected)!=1: raise RuntimeError('Simulator UUID is not available')
        runtime,device=selected[0];manifest.update(device=device['name'],runtime=runtime)
        manifest['xcode']=command(['xcrun','xcodebuild','-version'],capture_output=True,text=True).stdout.strip()
        manifest['baseCommit']=command(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True).stdout.strip()
        source_files=[ROOT/'Package.swift',*sorted((ROOT/'Sources').rglob('*')), *sorted((ROOT/'Demo').rglob('*'))]
        source_files=[p for p in source_files if p.is_file() and 'xcuserdata' not in p.parts]
        manifest['sourceHashes']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
        with zipfile.ZipFile(out/'source-snapshot.zip','w',zipfile.ZIP_DEFLATED) as archive:
            for p in source_files:archive.write(p,p.relative_to(ROOT))
        if device['state']!='Booted': command(['xcrun','simctl','boot',args.simulator])
        command(['xcrun','simctl','bootstatus',args.simulator,'-b'],stdout=subprocess.DEVNULL)
        command(['xcrun','simctl','status_bar',args.simulator,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100'])
        built_hashes={k:v for k,v in manifest['sourceHashes'].items() if k.endswith(('.swift','.pbxproj','.xcscheme'))}
        stamp=build/'BuiltSourceHashes.json'
        if not args.build and stamp.exists() and json.loads(stamp.read_text())!=built_hashes:
            raise RuntimeError('Source changed since build; rerun with --build')
        if args.build:
            build.mkdir(parents=True,exist_ok=True)
            with (out/'build.log').open('w') as build_log:
                command(['xcrun','xcodebuild','build-for-testing','-project',str(ROOT/'Demo/WaypointDemo.xcodeproj'),'-scheme','WaypointDemo','-destination','platform=iOS Simulator,id='+args.simulator,'-derivedDataPath',str(build/'DerivedData'),'CODE_SIGNING_ALLOWED=NO'],stdout=build_log,stderr=subprocess.STDOUT)
            stamp.write_text(json.dumps(built_hashes,sort_keys=True))
        products=build/'DerivedData/Build/Products'
        candidates=list(products.glob('*.xctestrun'))
        if len(candidates)!=1: raise RuntimeError('Run build-for-testing first; expected one .xctestrun')
        original=candidates[0];configuration=plistlib.loads(original.read_bytes())
        targets=[]
        if 'TestConfigurations' in configuration:
            for c in configuration['TestConfigurations']: targets.extend(c['TestTargets'])
        else: targets=[v for k,v in configuration.items() if not k.startswith('__') and isinstance(v,dict)]
        for target in targets:
            target.setdefault('EnvironmentVariables',{}).update(WAYPOINT_CAPTURE='0' if args.check else '1',WAYPOINT_RUN_ID=run_id,WAYPOINT_FAILURE_PROBE='1' if 'FAILURE' in flows else '0')
        # Keep __TESTROOT__ resolution beside the original build products.
        configured=products/('WaypointCapture-'+run_id+'.xctestrun');configured.write_bytes(plistlib.dumps(configuration))
        log=(out/'ui-tests.log').open('w');handles.append(log)
        cmd=['xcrun','xcodebuild','test-without-building','-xctestrun',str(configured),'-destination','platform=iOS Simulator,id='+args.simulator,'-parallel-testing-enabled','NO','-maximum-concurrent-test-simulator-destinations','1','-resultBundlePath',str(out/'Results.xcresult')]
        cmd += ['-only-testing:WaypointDemoUITests/RecordingFlows/test'+('FailureProbe' if f=='FAILURE' else f) for f in flows]
        save();test=subprocess.Popen(cmd,env=env,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        folder=None;seen={};active=None;started=time.monotonic();last_progress=started
        while test.poll() is None:
            if folder is None:
                located=subprocess.run(['xcrun','simctl','get_app_container',args.simulator,'world.aethers.WaypointDemoUITests.xctrunner','data'],env=env,capture_output=True,text=True)
                if located.returncode==0:
                    candidate=pathlib.Path(located.stdout.strip())/'Documents/WaypointCapture'/run_id
                    if candidate.exists():folder=candidate
            if folder and folder.exists():
                for flow in flows:
                    events=folder/(flow+'.jsonl')
                    if not events.exists():continue
                    lines=events.read_text().splitlines();offset=seen.get(flow,0)
                    for line in lines[offset:]:
                        try:event=json.loads(line)
                        except json.JSONDecodeError:break
                        seen[flow]=seen.get(flow,0)+1;last_progress=time.monotonic()
                        print(flow,event['kind'],event['detail'],flush=True)
                        with (out/'steps.jsonl').open('a') as target:target.write(line+'\n')
                        if event['kind']=='ready' and not args.check:
                            if capture:raise RuntimeError('Overlapping flows')
                            name=FILES.get(flow,flow.lower()+'.mp4');video=out/name;capture_log=out/(flow+'.capture.log');handle=capture_log.open('w')
                            process=subprocess.Popen(['xcrun','simctl','io',args.simulator,'recordVideo','--codec=h264',str(video)],env=env,stdout=handle,stderr=subprocess.STDOUT)
                            capture=(process,handle);deadline=time.monotonic()+20
                            while 'Recording started' not in capture_log.read_text():
                                if process.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Recording readiness failed')
                                time.sleep(.02)
                            active={'flow':flow,'file':name,'captureStarted':time.time(),'status':'recording'}
                            manifest['clips'].append(active);save()
                            (folder/(flow+'.capture-started')).touch()
                        if event['kind'] in ('passed','failed'):
                            if capture:stop_capture()
                            result={'flow':flow,'status':event['kind'],'completed':event['time']}
                            if active:active.update(result);active=None
                            elif args.check:manifest['clips'].append(result)
                            save()
            if time.monotonic()-last_progress>180:raise RuntimeError('UI runner stopped reporting progress')
            time.sleep(.1)
        code=test.wait();stop_capture()
        if folder and folder.exists():shutil.copytree(folder,out/'RunnerEvidence')
        manifest['testExitCode']=code
        passed={x['flow'] for x in manifest['clips'] if x['status']=='passed'}
        manifest['status']='passed' if code==0 and passed==set(flows) else 'failed'
        if manifest['status']!='passed':raise RuntimeError('UI flow failed; inspect ui-tests.log and Results.xcresult')
    except BaseException as error:
        manifest['status']='failed';manifest['error']=str(error);raise
    finally:
        if test and test.poll() is None:
            test.terminate()
            try:test.wait(timeout=30)
            except subprocess.TimeoutExpired:test.kill();test.wait()
        try:stop_capture()
        finally:
            for handle in handles:handle.close()
            save()
            if 'configured' in locals():configured.unlink(missing_ok=True)
            for lock in acquired:shutil.rmtree(lock)
            print('Run:',out,flush=True)

if __name__=='__main__':main()
