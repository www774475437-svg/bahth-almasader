"""استكشاف واجهة تراث (يُشغَّل يدويًا من GitHub Actions)"""
import json, re, sys, urllib.request, urllib.parse

UA = {"User-Agent": "Mozilla/5.0", "Accept": "*/*"}

def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        b = r.read()
        return b if binary else b.decode("utf-8", "replace")

def api(path, **p):
    p.setdefault("ver", "3")
    return json.loads(get("https://api.turath.io" + path + "?" + urllib.parse.urlencode(p)))

print("== app html / bundles")
try:
    html = get("https://app.turath.io/")
    srcs = set(re.findall(r'(?:src|href)="([^"]+\.(?:js|json))"', html))
    print(srcs)
    urls = set()
    for s in srcs:
        u = s if s.startswith("http") else "https://app.turath.io" + ("" if s.startswith("/") else "/") + s
        try:
            js = get(u)
        except Exception as e:
            print("ERR", u, e); continue
        for m in re.findall(r'https?://[A-Za-z0-9._/-]*turath[A-Za-z0-9._/?=&%{}$-]*', js):
            urls.add(m)
        for m in re.findall(r'["`](/[A-Za-z0-9._/-]*\.json[^"`]*)["`]', js):
            urls.add(m)
        for m in re.findall(r'.{60}(?:cat_id|precision).{60}', js)[:12]:
            print("CTX", m)
    for u in sorted(urls):
        print("URL", u)
except Exception as e:
    print("ERR html", e)

print("== search precision")
q = "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى"
for prec in [None, 0, 1, 2, 3]:
    try:
        p = {"q": q}
        if prec is not None: p["precision"] = str(prec)
        r = api("/search", **p)
        d = r.get("data", [])
        print("precision", prec, "count", r.get("count"), [ (x.get("book_id"), x.get("cat_id")) for x in d[:5]])
        if d and prec is None:
            print("KEYS", list(d[0].keys()), json.dumps(d[0], ensure_ascii=False)[:600])
    except Exception as e:
        print("ERR prec", prec, e)

print("== quoted")
try:
    r = api("/search", q='"' + q + '"'); print("quoted count", r.get("count"))
except Exception as e: print("ERR", e)

print("== multi author")
try:
    a = api("/search", q="الصلاة", author="1"); print("a1", a.get("count"))
    b = api("/search", q="الصلاة", author="1,2"); print("a1,2", b.get("count"))
except Exception as e: print("ERR", e)

print("== book meta sample")
try:
    r = api("/book", id="12836")
    print(json.dumps(r.get("meta", {}), ensure_ascii=False)[:800])
except Exception as e: print("ERR", e)
