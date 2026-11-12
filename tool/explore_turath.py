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

print("== html")
html = get("https://app.turath.io/")
print(html[:2500])
cands = set(re.findall(r'["\'(]((?:https?:)?/?/?[A-Za-z0-9._/-]+\.(?:js|json|mjs))["\')]', html))
print("CANDS", cands)
seen, urls = set(), set()
queue = list(cands)
n = 0
while queue and n < 40:
    s = queue.pop(); n += 1
    if s in seen: continue
    seen.add(s)
    u = s if s.startswith("http") else ("https:" + s if s.startswith("//") else "https://app.turath.io/" + s.lstrip("./").lstrip("/"))
    if "turath" not in u: continue
    try: js = get(u)
    except Exception as e: print("ERR", u, e); continue
    print("FETCHED", u, len(js))
    for m in re.findall(r'https?://[A-Za-z0-9._/-]*turath[A-Za-z0-9._/?=&%{}$-]*', js): urls.add(m)
    for m in re.findall(r'["`\']([A-Za-z0-9._/-]*\.json)["`\']', js): urls.add(m)
    for m in re.findall(r'["`\'](\.?/?[A-Za-z0-9._/-]+\.m?js)["`\']', js):
        b = u.rsplit("/", 1)[0] + "/" + m.lstrip("./")
        if b not in seen: queue.append(b)
    for m in re.findall(r'.{80}(?:cat_id|data-v|authors).{80}', js)[:6]: print("CTX", m)
for u in sorted(urls): print("URL", u)

print("== cats multi")
try:
    print("cat17", api("/search", q="الصلاة", cat_id="17").get("count"), "cat17,22", api("/search", q="الصلاة", cat_id="17,22").get("count"))
except Exception as e: print("ERR", e)

print("== author sample")
print(json.dumps(api("/author", id="57"), ensure_ascii=False)[:1200])

print("== authors scan")
def one(i):
    try:
        r = api("/author", id=str(i))
        info = (r.get("info") or "").strip().split("\n")[0][:70]
        return i, info
    except Exception as e:
        return i, None
with ThreadPoolExecutor(8) as ex:
    for i, info in ex.map(one, range(1, 2600)):
        if info: print("AUTH", i, info)
