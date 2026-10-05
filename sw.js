const CACHE='digital-dehazing-lab-v4';
const CORE=['./','./index.html','./styles.css','./app.js','./classic-dcp.js','./manifest.webmanifest'];
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
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