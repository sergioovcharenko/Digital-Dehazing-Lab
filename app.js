'use strict';
(() => {
  const $=id=>document.getElementById(id);
  const video=$('video'), photo=$('photo'), out=$('canvas'), ctx=out.getContext('2d',{alpha:false});
  const status=$('status'), fpsEl=$('fps'), latEl=$('latency'), label=$('algoLabel');
  const strength=$('strength'), strengthVal=$('strengthVal'), autoStrength=$('autoStrength');
  const cameraZoom=$('cameraZoom'), cameraZoomVal=$('cameraZoomVal'), cameraResetZoom=$('cameraResetZoom');
  const viewerStage=$('viewerStage'), engineStat=$('engineStat'), sourceStat=$('sourceStat'), outputStat=$('outputStat');
  const seek=$('seek'), timeEl=$('time'), play=$('play');
  const bClassic=$('bClassic'), bWebl=$('bWebl'), bEdn=$('bEdn'), bAid=$('bAid');
  let sourceMode='video', stream=null, objectUrl=null, running=false, raf=0, lastTs=0, frames=0, fpsTs=0;
  let viewMode='split', liveTrack=null, digitalZoom=1;
  let autoS=.60, autoTs=0, currentPhoto=null;
  let aiBusy=false;
  const bench={classic:[],webl:[],edn:[],aid:[]};

  function algo(){return document.querySelector('input[name=algo]:checked')?.value||'webl';}
  function setStatus(s){status.textContent=s;}
  function fmt(t){t=Math.max(0,Math.floor(t||0));return String(Math.floor(t/60)).padStart(2,'0')+':'+String(t%60).padStart(2,'0');}
  function strength01(){return autoStrength.checked?autoS:Number(strength.value)/100;}
  function setLabels(){
    const map={original:'ORIGINAL',classic:'CLASSIC DCP',webl:'WEBL',edn:'EDN-GTM',aid:'AID',hybrid:'HYBRID'};
    label.textContent=map[algo()]||algo().toUpperCase();
    strengthVal.textContent=Math.round(strength01()*100)+'%';
  }
  strength.oninput=()=>{autoStrength.checked=false;setLabels(); if(sourceMode==='photo') renderPhoto();};
  autoStrength.onchange=()=>{setLabels(); if(sourceMode==='photo') renderPhoto();};
  document.querySelectorAll('[data-view]').forEach(btn=>btn.onclick=()=>{
    viewMode=btn.dataset.view;
    document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b===btn));
    viewerStage.className='viewerStage view-'+viewMode;
    if(sourceMode==='photo') renderPhoto();
  });
  document.querySelectorAll('input[name=algo]').forEach(x=>x.onchange=()=>{setLabels();if(sourceMode==='photo')renderPhoto();});

  // --- Exact WebL/Adaptive family: shader derived from the existing v20 pipeline.
  const glCanvas=document.createElement('canvas');
  const gl=glCanvas.getContext('webgl',{alpha:false,antialias:false,powerPreference:'high-performance'});
  let prog=null,tex=null;
  function sh(type,src){const s=gl.createShader(type);gl.shaderSource(s,src);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s;}
  function initGL(){
    if(prog||!gl)return;
    const vs=sh(gl.VERTEX_SHADER,`attribute vec2 a; varying vec2 uv; void main(){uv=(a+1.0)*.5;gl_Position=vec4(a,0.,1.);}`);
    const fs=sh(gl.FRAGMENT_SHADER,`precision mediump float;
varying vec2 uv; uniform sampler2D t; uniform vec2 px; uniform float s;
float lum(vec3 c){return dot(c,vec3(.299,.587,.114));}
float dc(vec3 c){return min(c.r,min(c.g,c.b));}
void main(){
 vec3 c=texture2D(t,uv).rgb; if(s<.001){gl_FragColor=vec4(c,1.);return;}
 vec2 p1=px*1.75,p4=px*4.5;
 vec3 a=texture2D(t,uv+vec2(p1.x,0.)).rgb,b=texture2D(t,uv-vec2(p1.x,0.)).rgb;
 vec3 d=texture2D(t,uv+vec2(0.,p1.y)).rgb,e=texture2D(t,uv-vec2(0.,p1.y)).rgb;
 vec3 q1=texture2D(t,uv+vec2(p4.x,p4.y)).rgb,q2=texture2D(t,uv+vec2(-p4.x,p4.y)).rgb;
 vec3 q3=texture2D(t,uv+vec2(p4.x,-p4.y)).rgb,q4=texture2D(t,uv-vec2(p4.x,p4.y)).rgb;
 vec3 nearMean=(a+b+d+e)*.25,wideMean=(q1+q2+q3+q4)*.25;
 float y=lum(c),yn=lum(nearMean),yw=lum(wideMean);
 float e1=abs(y-yn)+length(c-nearMean)*.42,e2=abs(yn-yw)+abs(y-yw)*.55;
 float structure=clamp(smoothstep(.004,.085,e1+.62*e2),0.,1.);
 float weak=smoothstep(.003,.040,abs(y-yw))*(1.-smoothstep(.12,.26,e1));
 float darkNear=min(dc(c),min(min(dc(a),dc(b)),min(dc(d),dc(e))));
 float darkWide=min(min(dc(q1),dc(q2)),min(dc(q3),dc(q4)));
 float A=.84,veil=clamp(mix(min(darkNear,darkWide),darkNear,.10+.78*structure)/A*.78+(1.-structure)*.12+y*.10,0.,1.);
 float obj=clamp(max(structure*.82,weak)*smoothstep(.10,.74,veil),0.,1.);
 float omega=mix(.68,.91,s),floorT=mix(.42,.23,s)-.02*obj;
 float tr=clamp(1.-omega*veil,max(.20,floorT),1.);
 vec3 rec=clamp((c-vec3(A))/tr+vec3(A),0.,1.);
 vec3 r=mix(c,rec,clamp(s*(.42+.45*smoothstep(.10,.78,veil)),0.,.94));
 vec3 local=nearMean*.72+wideMean*.28;
 vec3 detail=clamp(c-local,vec3(-.085),vec3(.085));
 r+=detail*s*(.18+.70*obj);
 float ry=lum(r);r=vec3(ry)+(r-vec3(ry))*(1.+.055*s+.095*obj);
 gl_FragColor=vec4(clamp(r,0.,1.),1.);
}`);
    prog=gl.createProgram();gl.attachShader(prog,vs);gl.attachShader(prog,fs);gl.linkProgram(prog);gl.useProgram(prog);
    const buf=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buf);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
    const loc=gl.getAttribLocation(prog,'a');gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);
    tex=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,tex);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
    gl.uniform1i(gl.getUniformLocation(prog,'t'),0);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);
  }
  function renderWebL(src,w,h,s){
    initGL(); if(!gl||!prog) throw Error('WebGL unavailable');
    const max=1280,sc=Math.min(1,max/Math.max(w,h)),rw=Math.max(2,Math.round(w*sc)),rh=Math.max(2,Math.round(h*sc));
    if(glCanvas.width!==rw||glCanvas.height!==rh){glCanvas.width=rw;glCanvas.height=rh;gl.viewport(0,0,rw,rh);}
    gl.useProgram(prog);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,tex);
    if(sourceMode==='live'&&digitalZoom>1.001){
      capCanvas.width=rw;capCanvas.height=rh;drawSourceZoomed(capCtx,src,0,0,rw,rh);
      gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,capCanvas);
    }else gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,src);
    gl.uniform2f(gl.getUniformLocation(prog,'px'),1/rw,1/rh);gl.uniform1f(gl.getUniformLocation(prog,'s'),s);
    gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    return glCanvas;
  }

  const capCanvas=document.createElement('canvas'), capCtx=capCanvas.getContext('2d',{willReadFrequently:true});
  const procCanvas=document.createElement('canvas'), procCtx=procCanvas.getContext('2d');
  function sourceDims(){
    if(sourceMode==='photo'&&currentPhoto)return [currentPhoto.naturalWidth,currentPhoto.naturalHeight,currentPhoto];
    if(video.videoWidth)return [video.videoWidth,video.videoHeight,video];
    return [0,0,null];
  }
  function drawSourceZoomed(dstCtx,src,dx,dy,dw,dh){
    if(sourceMode!=='live'||digitalZoom<=1.001){dstCtx.drawImage(src,dx,dy,dw,dh);return;}
    const sw=src.videoWidth||src.naturalWidth||dw, sh=src.videoHeight||src.naturalHeight||dh;
    const cw=sw/digitalZoom, ch=sh/digitalZoom, sx=(sw-cw)/2, sy=(sh-ch)/2;
    dstCtx.drawImage(src,sx,sy,cw,ch,dx,dy,dw,dh);
  }
  function captureForCPU(src,w,h,maxSide=640){
    const sc=Math.min(1,maxSide/Math.max(w,h)),cw=Math.max(2,Math.round(w*sc)),ch=Math.max(2,Math.round(h*sc));
    capCanvas.width=cw;capCanvas.height=ch;drawSourceZoomed(capCtx,src,0,0,cw,ch);
    return [capCtx.getImageData(0,0,cw,ch),cw,ch];
  }
  function renderClassic(src,w,h,s){
    const [im,cw,ch]=captureForCPU(src,w,h,480);
    const arr=window.dehazeStrongDCP(im.data,cw,ch,{strength:Math.round(s*100),maxSide:480});
    procCanvas.width=cw;procCanvas.height=ch;procCtx.putImageData(new ImageData(arr,cw,ch),0,0);
    return procCanvas;
  }
  function analyzeAuto(src,w,h,now){
    if(!autoStrength.checked||now-autoTs<700)return;
    autoTs=now;const [im,cw,ch]=captureForCPU(src,w,h,96),d=im.data;let sum=0,sum2=0,sat=0;
    for(let i=0;i<d.length;i+=4){const y=.299*d[i]+.587*d[i+1]+.114*d[i+2];sum+=y;sum2+=y*y;sat+=Math.max(d[i],d[i+1],d[i+2])-Math.min(d[i],d[i+1],d[i+2]);}
    const n=cw*ch,mean=sum/n,std=Math.sqrt(Math.max(0,sum2/n-mean*mean)),satM=sat/n;
    const haze=Math.max(0,Math.min(1,(45-std)/35*.65+(35-satM)/35*.35));
    autoS=autoS*.78+(0.08+haze*.80)*.22;setLabels();
  }

  // --- AI model hooks. Real model inference only; no fake filter fallback.
  const modelCfg={
    edn:{url:'models/edn_gtm_densehaze_192x320.onnx',size:[192,320]},
    aid:{url:'models/aid_transformer_256.onnx',size:[256,256]}
  };
  const sessions={};
  async function getSession(kind){
    if(sessions[kind])return sessions[kind];
    if(!window.ort)throw Error('ONNX Runtime Web unavailable');
    try{
      ort.env.wasm.numThreads=Math.min(4,navigator.hardwareConcurrency||2);
      sessions[kind]=await ort.InferenceSession.create(modelCfg[kind].url,{executionProviders:['webgpu','wasm']});
      return sessions[kind];
    }catch(e){throw Error('model asset not installed: '+modelCfg[kind].url);}
  }
  async function renderAI(kind,src,w,h){
    const sess=await getSession(kind),[H,W]=modelCfg[kind].size;
    const tmp=document.createElement('canvas');tmp.width=W;tmp.height=H;const c=tmp.getContext('2d',{willReadFrequently:true});c.drawImage(src,0,0,W,H);
    const d=c.getImageData(0,0,W,H).data;
    if(kind==='edn'){
      // EDN-GTM requires RGB plus a transmission-map channel. Browser lab computes a lightweight DCP transmission estimate.
      const input=new Float32Array(H*W*4),gray=new Float32Array(H*W);
      let A=.85;
      for(let i=0,p=0;i<d.length;i+=4,p++){const r=d[i]/255,g=d[i+1]/255,b=d[i+2]/255;gray[p]=Math.min(r,g,b);A=Math.max(A,r,g,b);}
      for(let y=0;y<H;y++)for(let x=0;x<W;x++){const p=y*W+x,i=p*4;let mn=1;for(let yy=Math.max(0,y-2);yy<=Math.min(H-1,y+2);yy++)for(let xx=Math.max(0,x-2);xx<=Math.min(W-1,x+2);xx++)mn=Math.min(mn,gray[yy*W+xx]);const tr=1-.95*Math.min(1,mn/Math.max(.35,A));input[p*4]=(d[i]-127.5)/127.5;input[p*4+1]=(d[i+1]-127.5)/127.5;input[p*4+2]=(d[i+2]-127.5)/127.5;input[p*4+3]=2*(tr-.5);}
      const name=sess.inputNames[0],res=await sess.run({[name]:new ort.Tensor('float32',input,[1,H,W,4])}),o=res[sess.outputNames[0]].data;
      const outIm=c.createImageData(W,H);for(let p=0;p<H*W;p++){outIm.data[p*4]=Math.max(0,Math.min(255,o[p*3]));outIm.data[p*4+1]=Math.max(0,Math.min(255,o[p*3+1]));outIm.data[p*4+2]=Math.max(0,Math.min(255,o[p*3+2]));outIm.data[p*4+3]=255;}c.putImageData(outIm,0,0);return tmp;
    }else{
      const input=new Float32Array(3*H*W);for(let p=0;p<H*W;p++){input[p]=d[p*4]/255;input[H*W+p]=d[p*4+1]/255;input[2*H*W+p]=d[p*4+2]/255;}
      const name=sess.inputNames[0],res=await sess.run({[name]:new ort.Tensor('float32',input,[1,3,H,W])}),o=res[sess.outputNames[0]].data;
      const outIm=c.createImageData(W,H);for(let p=0;p<H*W;p++){outIm.data[p*4]=255*Math.max(0,Math.min(1,o[p]));outIm.data[p*4+1]=255*Math.max(0,Math.min(1,o[H*W+p]));outIm.data[p*4+2]=255*Math.max(0,Math.min(1,o[2*H*W+p]));outIm.data[p*4+3]=255;}c.putImageData(outIm,0,0);return tmp;
    }
  }

  function compose(src,processed,w,h){
    const max=1600,sc=Math.min(1,max/Math.max(w,h)),rw=Math.max(2,Math.round(w*sc)),rh=Math.max(2,Math.round(h*sc));
    if(out.width!==rw||out.height!==rh){out.width=rw;out.height=rh;}
    ctx.clearRect(0,0,rw,rh);
    if(viewMode==='split'){
      drawSourceZoomed(ctx,src,0,0,rw,rh);
      ctx.save();ctx.beginPath();ctx.rect(rw/2,0,rw/2,rh);ctx.clip();ctx.drawImage(processed,0,0,rw,rh);ctx.restore();
      ctx.fillStyle='#fff';ctx.fillRect(rw/2-1,0,2,rh);
    }else ctx.drawImage(processed,0,0,rw,rh);
  }
  function recordBench(kind,ms){
    if(!bench[kind])return;const a=bench[kind];a.push(ms);if(a.length>60)a.shift();
    const avg=a.reduce((x,y)=>x+y,0)/a.length;
    const el=kind==='classic'?bClassic:kind==='webl'?bWebl:kind==='edn'?bEdn:bAid;
    el.textContent=avg.toFixed(1)+' ms • '+Math.round(1000/avg)+' FPS theoretical';
  }
  async function processFrame(now=performance.now()){
    const [w,h,src]=sourceDims();if(!src||!w||!h)return;
    analyzeAuto(src,w,h,now);const a=algo(),s=strength01(),t0=performance.now();
    if(engineStat)engineStat.textContent=a.toUpperCase();
    if(sourceStat)sourceStat.textContent=w+'×'+h;
    try{
      if(a==='original'){compose(src,src,w,h);}
      else if(a==='webl'){const p=renderWebL(src,w,h,s);compose(src,p,w,h);recordBench('webl',performance.now()-t0);}
      else if(a==='classic'){const p=renderClassic(src,w,h,s);compose(src,p,w,h);recordBench('classic',performance.now()-t0);}
      else if(a==='edn'||a==='aid'){
        if(aiBusy)return;aiBusy=true;
        try{const p=await renderAI(a,src,w,h);compose(src,p,w,h);recordBench(a,performance.now()-t0);}
        finally{aiBusy=false;}
      }else if(a==='hybrid'){
        setStatus('HYBRID буде активований після фактичного benchmark EDN/AID; зараз не підміняємо AI звичайним фільтром.');
        const p=renderWebL(src,w,h,s);compose(src,p,w,h);
      }
      const ms=performance.now()-t0;latEl.textContent=ms.toFixed(1)+' ms';
      if(outputStat)outputStat.textContent=out.width+'×'+out.height;
    }catch(e){setStatus((a==='edn'?'EDN-GTM':a==='aid'?'AIDTransformer':a)+': '+e.message);if(a==='edn')bEdn.textContent='model pending';if(a==='aid')bAid.textContent='model pending';compose(src,src,w,h);}
  }
  async function loop(ts){
    if(!running)return;
    if(!lastTs||ts-lastTs>16){lastTs=ts;await processFrame(ts);frames++;}
    if(!fpsTs)fpsTs=ts;if(ts-fpsTs>=1000){fpsEl.textContent=Math.round(frames*1000/(ts-fpsTs))+' FPS';frames=0;fpsTs=ts;}
    raf=requestAnimationFrame(loop);
  }
  function start(){if(running)return;running=true;lastTs=0;frames=0;fpsTs=0;raf=requestAnimationFrame(loop);}
  function stop(){running=false;cancelAnimationFrame(raf);fpsEl.textContent='— FPS';}

  function activate(mode){sourceMode=mode;['photoBtn','videoBtn','liveBtn'].forEach(id=>$(id).classList.remove('active'));$(mode+'Btn').classList.add('active');}
  $('photoBtn').onclick=()=>{$('photoInput').click();};
  $('videoBtn').onclick=()=>{$('videoInput').click();};
  $('liveBtn').onclick=async()=>{
    activate('live');stop();if(stream)stream.getTracks().forEach(t=>t.stop());
    try{
      stream=await navigator.mediaDevices.getUserMedia({video:{
        facingMode:{ideal:'environment'},
        width:{ideal:3840},
        height:{ideal:2160},
        frameRate:{ideal:30,max:60},
        aspectRatio:{ideal:1.7777778}
      },audio:false});
      liveTrack=stream.getVideoTracks()[0]||null;
      video.srcObject=stream;video.muted=true;await video.play();
      const settings=liveTrack?.getSettings?.()||{};
      const caps=liveTrack?.getCapabilities?.()||{};
      digitalZoom=1;
      if(cameraZoom){
        if(caps.zoom){
          cameraZoom.min=String(caps.zoom.min||1);
          cameraZoom.max=String(caps.zoom.max||6);
          cameraZoom.step=String(caps.zoom.step||0.1);
          cameraZoom.value=String(settings.zoom||caps.zoom.min||1);
        }else{
          cameraZoom.min='1';cameraZoom.max='6';cameraZoom.step='0.1';cameraZoom.value='1';
        }
        cameraZoomVal.textContent=Number(cameraZoom.value).toFixed(1)+'×';
      }
      setStatus('LIVE камера • '+(settings.width||video.videoWidth)+'×'+(settings.height||video.videoHeight)+' • локальна обробка.');
      start();
    }catch(e){setStatus('LIVE camera error: '+e.message);}
  };
  async function applyCameraZoom(value){
    const z=Math.max(1,Number(value)||1);
    const caps=liveTrack?.getCapabilities?.()||{};
    if(liveTrack&&caps.zoom){
      const min=Number(caps.zoom.min||1),max=Number(caps.zoom.max||z),clamped=Math.max(min,Math.min(max,z));
      try{await liveTrack.applyConstraints({advanced:[{zoom:clamped}]});digitalZoom=1;}
      catch(e){digitalZoom=z;}
    }else digitalZoom=z;
    if(cameraZoomVal)cameraZoomVal.textContent=z.toFixed(1)+'×';
  }
  if(cameraZoom)cameraZoom.oninput=()=>applyCameraZoom(cameraZoom.value);
  if(cameraResetZoom)cameraResetZoom.onclick=()=>{cameraZoom.value='1';applyCameraZoom(1);};
  $('photoInput').onchange=e=>{
    const f=e.target.files[0];if(!f)return;activate('photo');stop();if(objectUrl)URL.revokeObjectURL(objectUrl);objectUrl=URL.createObjectURL(f);
    photo.src=objectUrl;photo.onload=()=>{currentPhoto=photo;setStatus('Фото: '+f.name);renderPhoto();};
  };
  $('videoInput').onchange=async e=>{
    const f=e.target.files[0];if(!f)return;activate('video');stop();if(stream){stream.getTracks().forEach(t=>t.stop());stream=null;}if(objectUrl)URL.revokeObjectURL(objectUrl);objectUrl=URL.createObjectURL(f);
    video.srcObject=null;video.src=objectUrl;video.loop=false;video.muted=true;await video.play().catch(()=>{});setStatus('Відео: '+f.name);start();
  };
  async function renderPhoto(){if(sourceMode!=='photo'||!currentPhoto)return;await processFrame();}
  play.onclick=async()=>{if(sourceMode==='photo')return;if(video.paused){await video.play();start();play.textContent='Ⅱ';}else{video.pause();stop();play.textContent='▶';}};
  video.ontimeupdate=()=>{if(sourceMode==='video'&&video.duration){seek.value=Math.round(video.currentTime/video.duration*1000);timeEl.textContent=fmt(video.currentTime)+' / '+fmt(video.duration);}};
  seek.oninput=()=>{if(sourceMode==='video'&&video.duration)video.currentTime=video.duration*Number(seek.value)/1000;};
  $('saveFrame').onclick=()=>{out.toBlob(blob=>{if(!blob)return;const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='dehaze-frame.png';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);},'image/png');};

  if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
  window.addEventListener('online',()=>{$('offlineState').textContent='ONLINE';});
  window.addEventListener('offline',()=>{$('offlineState').textContent='OFFLINE';});
  $('offlineState').textContent=navigator.onLine?'ONLINE':'OFFLINE';
  setLabels();
  setStatus('Lab ready. Фото, відео і LIVE обробляються локально; AI режими потребують локальних model/runtime assets.');
})();