"""استكشاف واجهة تراث (يُشغَّل يدويًا من GitHub Actions)"""
import json, re, sys, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

UA = {"User-Agent": "Mozilla/5.0", "Accept": "*/*"}

def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")

def api(path, **p):
    p.setdefault("ver", "3")
    return json.loads(get("https://api.turath.io" + path + "?" + urllib.parse.urlencode(p)))

a = api("/author", id="57")
print("AUTHOR KEYS", {k: (str(v)[:80]) for k, v in a.items() if k != "biography"})
b = api("/book", id="10649")
print("BOOK KEYS", list(b.keys()), {k: str(v)[:80] for k, v in b.get("meta", {}).items()})

print("== html tail")
html = get("https://app.turath.io/")
i = html.find("_app/")
print(len(html), html[-2500:])
mods = set(re.findall(r'["\'(](\.?/?_app/[A-Za-z0-9._/-]+\.js)["\')]', html))
print("MODS", mods)
seen, urls, queue, n = set(), set(), list(mods), 0
while queue and n < 80:
    s = queue.pop(); n += 1
    u = s if s.startswith("http") else "https://app.turath.io/" + s.lstrip("./").lstrip("/")
    if u in seen: continue
    seen.add(u)
    try: js = get(u)
    except Exception as e: print("ERR", u, e); continue
    for m in re.findall(r'https?://[A-Za-z0-9._/-]*(?:turath|nuqayah)[A-Za-z0-9._/?=&%{}$-]*', js): urls.add(m)
    for m in re.findall(r'["`\']([A-Za-z0-9._/?=-]*\.(?:json|sqlite|db|gz|br)[A-Za-z0-9?=._-]*)["`\']', js): urls.add(m)
    for m in re.findall(r'["`\'](\.{0,2}/?[A-Za-z0-9._/-]+\.js)["`\']', js):
        b2 = urllib.parse.urljoin(u, m)
        if "app.turath.io" in b2 and b2 not in seen: queue.append(b2)
    for m in re.findall(r'.{100}(?:cat_id|/data|authors\b).{100}', js)[:4]: print("CTX", m.replace("\n", " "))
print("FETCHED", len(seen))
for u in sorted(urls): print("URL", u)

print("== authors scan")
def one(i):
    try:
        r = api("/author", id=str(i))
        return i, (r.get("name") or "").strip()
    except Exception:
        return i, None
with ThreadPoolExecutor(8) as ex:
    for i, name in ex.map(one, range(1, 3200)):
        if name: print("AUTH", i, name)
