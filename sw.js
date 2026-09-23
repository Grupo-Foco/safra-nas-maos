/* Safra nas Mãos — service worker
   Guarda o app no aparelho para abrir sem internet.
   CACHE muda a cada publicação: é o que dispara a atualização. */

const CACHE = "safra-v2.31.0";
const SHELL = ["./", "./index.html", "./manifest.json", "./icone.svg", "./icone-maskable.svg", "./mapa-santa-angelina.jpg"];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(SHELL.map(u => new Request(u, {cache:"reload"}))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("message", e => {
  if (e.data === "pular-espera") self.skipWaiting();
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET" || req.url.includes("/rest/v1/")) return;

  // O HTML e o próprio app nunca saem do cache do navegador:
  // sem isso, o GitHub Pages devolve a versão antiga por até 10 minutos.
  const ehApp = req.mode === "navigate" ||
                /\.(html|js|json|svg)$/.test(new URL(req.url).pathname) ||
                new URL(req.url).pathname.endsWith("/");

  e.respondWith(
    fetch(ehApp ? new Request(req, {cache:"no-store"}) : req)
      .then(res => {
        const copia = res.clone();
        caches.open(CACHE).then(c => c.put(req, copia)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then(r => r || caches.match("./index.html")))
  );
});
