/* Safra nas Mãos — service worker
   Guarda o app no aparelho para abrir sem internet.
   Troque CACHE ao publicar uma versão nova. */

const CACHE = "safra-v0.3.0";
const SHELL = ["./", "./index.html", "./manifest.json"];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;

  // Chamadas ao Supabase nunca vêm do cache — a fila local cuida do offline.
  if (req.method !== "GET" || req.url.includes("/rest/v1/")) return;

  // Rede primeiro, cache como reserva: abre sempre a versão mais nova quando há sinal.
  e.respondWith(
    fetch(req)
      .then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then(r => r || caches.match("./index.html")))
  );
});
