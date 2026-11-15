"""فحص: هل تسمح واجهة تراث بالطلب من موقع آخر (CORS)؟"""
import urllib.request
for url in ["https://api.turath.io/search?q=%D8%A7%D9%84%D8%B5%D9%84%D8%A7%D8%A9&ver=3",
            "https://api.turath.io/page?book_id=12836&pg=5&ver=3"]:
    for origin in ["https://www774475437-svg.github.io", "https://example.com"]:
        req = urllib.request.Request(url, headers={"Origin": origin, "User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                print("CORS", url[:45], origin, r.status, r.headers.get("Access-Control-Allow-Origin"), r.headers.get("Vary"))
        except Exception as e:
            print("CORS ERR", url[:45], origin, e)
    req = urllib.request.Request(url, method="OPTIONS", headers={"Origin": "https://www774475437-svg.github.io", "Access-Control-Request-Method": "GET", "User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            print("PREFLIGHT", r.status, dict(r.headers))
    except Exception as e:
        print("PREFLIGHT ERR", e)
