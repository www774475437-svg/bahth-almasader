"""يجمع فهرس الكتب (الاسم والمؤلف والباب) من صفحات الأبواب — يُشغَّل يدويًا من GitHub Actions"""
import json, re, time, html as H, urllib.request

UA = {"User-Agent": "Mozilla/5.0", "Accept": "*/*"}

def get(url):
    for k in range(5):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:
            err = e; time.sleep(3 + 3 * k)
    raise err

AR = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
home = get("https://app.turath.io/")
cats = {}
for cid, name in re.findall(r'<a href="/category/(\d+)">([^<]+?)\s*<span>', home):
    cats[int(cid)] = H.unescape(name).strip()
print("CATS", len(cats))
books, authors = [], {}
for cid in sorted(cats):
    page = get(f"https://app.turath.io/category/{cid}")
    n = 0
    for li in re.findall(r'<li><a class="name" href="/book/(\d+)">(.*?)</a>(.*?)</li>', page, flags=re.S):
        bid, bname, rest = li
        m = re.search(r'href="/author/(\d+)">(.*?)</a>', rest, flags=re.S)
        aid = int(m.group(1)) if m else 0
        if m: authors[aid] = H.unescape(re.sub(r'\s+', ' ', m.group(2))).strip()
        pg = re.search(r'<span>([٠-٩0-9]+)\s*صفح', rest)
        books.append([int(bid), H.unescape(bname).strip(), aid, cid, int(pg.group(1).translate(AR)) if pg else 0])
        n += 1
    print("CAT", cid, cats[cid], n)
    time.sleep(1)
json.dump({"cats": cats, "authors": authors, "books": books}, open("catalog.json", "w", encoding="utf-8"), ensure_ascii=False)
print("BOOKS", len(books), "AUTHORS", len(authors))
