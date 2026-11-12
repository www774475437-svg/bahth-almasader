"""استكشاف واجهة تراث (يُشغَّل يدويًا من GitHub Actions)"""
import json, re, sys, time, urllib.request, urllib.parse

UA = {"User-Agent": "Mozilla/5.0", "Accept": "*/*"}

def get(url):
    for k in range(4):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:
            err = e; time.sleep(2 + 2 * k)
    raise err

html = get("https://app.turath.io/")
i = html.find('/category/')
print("== HOME CATS", html[i - 600:i + 2500])
c = get("https://app.turath.io/category/17")
i = c.find('/book/')
print("== CAT17 len", len(c), c.count('/book/'), c.count('/author/'))
print(c[i - 1500:i + 2500])
for u in ["https://app.turath.io/author/57", "https://app.turath.io/book/10649"]:
    try:
        a = get(u)
        j = a.find('<main')
        print("== ", u, len(a), a.count('/book/'), a.count('/category/'))
        print(a[j:j + 2500])
    except Exception as e:
        print("ERR", u, e)
