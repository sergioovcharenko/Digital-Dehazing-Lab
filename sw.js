const CACHE='digital-dehazing-lab-v8';
const CORE=['./','./index.html','./styles.css','./app.js','./classic-dcp.js','./manifest.webmanifest'];

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE)).then(()=>self.skipWaiting()));
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;

  const url=new URL(event.request.url);

  // Large AI model shards must never be cloned into Cache Storage on iPhone.
  // Streaming them directly avoids doubled I/O/memory and reduces Safari freezes.
  if(url.origin===self.location.origin && url.pathname.includes('/models/')){
    event.respondWith(fetch(event.request,{cache:'no-store'}));
    return;
  }

  // Do not cache third-party runtimes such as TensorFlow.js.
  if(url.origin!==self.location.origin)return;

  event.respondWith(
    fetch(event.request).then(res=>{
      if(res&&res.status===200&&res.type!=='opaque'){
        const copy=res.clone();
        caches.open(CACHE).then(cache=>cache.put(event.request,copy));
      }
      return res;
    }).catch(()=>caches.match(event.request))
  );
});
