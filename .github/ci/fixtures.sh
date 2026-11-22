#!/usr/bin/env bash
# Fixture pages + threaded server the UI tests use. Extracted verbatim from the
# step that used to inline it, so the build job and every shard serve the same bytes.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-$(pwd)}"
mkdir -p fixtures
printf 'brows download fixture\n' > fixtures/sample.bin
cat > fixtures/login.html <<'HTML'
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Login Fixture</title>
<style>
body{font-family:-apple-system,Helvetica,sans-serif;padding:24px;color:#1b1f27}
input{display:block;width:100%;box-sizing:border-box;font-size:16px;padding:10px;margin:8px 0;border:1px solid #99a;border-radius:8px}
button{font-size:16px;padding:10px 18px;border-radius:8px;border:0;background:#1b1f27;color:#fff}
#mirror{font-size:14px;color:#333;margin-top:18px}
</style>
</head>
<body>
<h1>Sign in</h1>
<form id="login" method="get" action="/other.html">
<input id="u" name="username" type="text" autocomplete="username" aria-label="Username" placeholder="Username">
<input id="p" name="password" type="password" aria-label="Password" placeholder="Password">
<button type="submit">Log in</button>
</form>
<pre id="mirror">U= P=</pre>
<script>
var u=document.getElementById('u');var p=document.getElementById('p');
function mirror(){document.getElementById('mirror').textContent='U='+u.value+' P='+p.value;}
[u,p].forEach(function(el){el.addEventListener('input',mirror);el.addEventListener('change',mirror);});
document.getElementById('login').addEventListener('submit',function(event){event.preventDefault();});
</script>
</body>
</html>
HTML
cat > fixtures/other.html <<'HTML'
<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Other page</title></head>
<body style="font-family:-apple-system,Helvetica,sans-serif;padding:24px"><h1>Other page</h1>
<p>This page exists so the password test can leave the login origin and come back.</p></body></html>
HTML
cat > fixtures/dialog.html <<'HTML'
<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dialogs</title>
<style>
body{font-family:-apple-system,Helvetica,sans-serif;padding:24px;color:#1b1f27}
button{display:block;width:100%;font-size:16px;padding:12px 18px;margin:10px 0;border-radius:10px;border:0;background:#1b1f27;color:#fff}
p{font-size:15px;color:#333;margin:4px 0 16px}
</style></head>
<body>
<h1>Dialogs</h1>
<button id="alert">Alert</button>
<button id="confirm">Confirm</button>
<button id="prompt">Prompt</button>
<p id="alert-result"></p>
<p id="confirm-result"></p>
<p id="prompt-result"></p>
<script>
document.getElementById('alert').onclick=function(){alert('Saved to the shelf.');document.getElementById('alert-result').textContent='alerted';};
document.getElementById('confirm').onclick=function(){document.getElementById('confirm-result').textContent=confirm('Remove this bookmark?')?'confirmed':'cancelled';};
document.getElementById('prompt').onclick=function(){var v=prompt('Name this workspace','Work');document.getElementById('prompt-result').textContent=(v===null)?'null':'hello '+v;};
</script>
</body></html>
HTML
cat > fixtures/links.html <<'HTML'
<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Links</title>
<style>
body{font-family:-apple-system,Helvetica,sans-serif;padding:24px;color:#1b1f27}
a{display:block;font-size:17px;padding:12px 0}
button{display:block;width:100%;font-size:16px;padding:12px 18px;margin:10px 0;border-radius:10px;border:0;background:#1b1f27;color:#fff}
</style></head>
<body>
<h1>Links</h1>
<!-- The scheme links stay at the top of the page: the page runs
     full-bleed under the bottom rail, so a link at the end of the
     document scrolls underneath it and a tap there lands on the
     rail's back button instead (run 44652824094: tapping
     "Unsupported" went back to the start page). -->
<a href="mailto:someone@example.com">Mail</a>
<a href="tel:+15551234567">Call</a>
<a href="brows-nothing:whatever">Unsupported</a>
<button id="named-first" onclick="window.browsNamedWindow = window.open('/article.html','browsNamed'); document.getElementById('named-result').textContent = window.browsNamedWindow ? 'first-open' : 'first-null'">Open named window</button>
<button id="named-again" onclick="window.browsNamedWindow = window.open('/article.html','browsNamed'); setTimeout(function(){ var w = window.open('/other.html','browsNamed'); document.getElementById('named-result').textContent = w === window.browsNamedWindow ? 'same-window' : (w ? 'different-window' : 'null-again'); }, 1800)">Open named window again</button>
<p id="named-result">none</p>
<button id="named-fresh" onclick="var w = window.open('/other.html','browsNamed'); document.getElementById('fresh-result').textContent = w ? 'fresh-open' : 'fresh-null'">Open the closed name again</button>
<p id="fresh-result">none</p>
<a href="/other.html" target="_blank">Open blank</a>
<button onclick="window.open('/article.html','_blank')">Open popup</button>
<button id="features" onclick="var w = window.open('/article.html','oauth','width=420,height=640,menubar=no'); document.getElementById('popup-result').textContent = w ? 'opened' : 'blocked'">Open popup with features</button>
<a id="refuse" href="brows-nothing://popup">Open refused popup</a>
<p id="popup-result">none</p>
</body></html>
HTML
{ echo '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>The shape of a browser</title>'; echo '<style>body{margin:0;background:#f4f2ee;color:#23262b;font-family:Georgia,serif}article{max-width:680px;margin:0 auto;padding:28px 22px 180px}h1{font-size:30px;line-height:1.15}p{font-size:17px;line-height:1.62;margin:0 0 16px}</style></head><body><article>'; echo '<h1>The shape of a browser</h1>'; echo '<p>A browser is a rectangle of page with a thin band of controls around it. Almost everything that makes one feel right lives in that band: how much of the page shows through it, how far a thumb has to travel, and whether the controls agree with each other about where the edges are.</p>'; echo '<p>On a phone the band moves to the bottom, because the top of the screen belongs to the page and to the notch. The address field stops being a place you type and becomes a place you glance at, so its text has to survive a background that changes with every site you visit. That is why it is glass: not decoration, but a way of staying legible over a photograph, a spreadsheet, or a wall of text like this one.</p>'; echo '<p>Glass, done properly, is a stack of very thin decisions. A pane of almost-white at less than half opacity. A ramp that is brighter at the edge where light would fall. A hairline, one pixel, that gives the pane an edge without drawing a box. A sheen in one corner so the surface reads as a surface rather than a fill. Remove any one of those and the result collapses into a grey slab, which is exactly what a flat alpha value looks like.</p>'; echo '<p>Typography carries the rest. Long lines are tiring, so the column is narrow. Line height is generous. The measure is set by the reading experience, not by the window. When a reader mode strips a page down, it should keep the images and the paragraphs and lose the navigation, the cookie banners, and the three separate requests to subscribe.</p>'; echo '<p>Tabs are a gallery now. A row of shrinking trapezoids made sense on a desktop with a mouse; on a phone the useful question is not which tab is third from the left but which of these pages was I reading. So the gallery ranks by recency, shows the workspace each tab belongs to, and offers the ones you closed by mistake.</p>'; echo '<p>Downloads, history, passwords and site settings belong to the browser, not to the page. They should be one gesture away, in the same place every time, and they should tell the truth about what they are doing. A download that has not started is not a download. A password that was not written is not saved. A progress bar that never completes is a lie with a rounded corner.</p>'; echo '<p>That is the whole test. Not whether the controls exist, but whether they behave the same way twice, on a page nobody designed for them, with the network doing what networks do.</p>'; echo '</article></body></html>'; } > fixtures/article.html
# `python3 -m http.server` is single-threaded: one lingering connection
# (a cancelled download, a keep-alive socket) blocks every later request,
# which is how the article page hung after the download test. Serve the
# fixtures from a threaded server instead, and poll every endpoint the
# tests use before running them.
cat > fixtures/serve.py <<'PY'
import base64
import http.server
import socketserver
ACCOUNTS = {'browsuser': 'browssecret', 'otheraccount': 'othersecret'}
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory='fixtures', **kwargs)
    def do_GET(self):
        path = self.path.split('?', 1)[0]
        if path in ('/auth.html', '/auth2.html'):
            second = path == '/auth2.html'
            realm = 'Brows Fixture 2' if second else 'Brows Fixture'
            # Each protection space demands its own account. WebKit reuses
            # a .forSession credential for the host across realms, so a
            # page that accepted either account would never challenge
            # and the second-account offer could not be reached.
            allowed = 'otheraccount' if second else 'browsuser'
            user = ''
            header = self.headers.get('Authorization', '')
            if header.startswith('Basic '):
                try:
                    raw = base64.b64decode(header[6:]).decode('utf-8')
                    name, password = raw.split(':', 1)
                    if name == allowed and ACCOUNTS.get(name) == password:
                        user = name
                except Exception:
                    user = ''
            if not user:
                body = b'Authentication required'
                self.send_response(401)
                self.send_header('WWW-Authenticate', 'Basic realm="%s"' % realm)
                self.send_header('Content-Type', 'text/plain')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            body = ('<!doctype html><html><head><meta name="viewport" '
                    'content="width=device-width,initial-scale=1"><title>Protected</title>'
                    '</head><body style="font-family:-apple-system,Helvetica,sans-serif;'
                    'padding:24px"><h1>Protected area</h1><p>Signed in as %s</p>'
                    '</body></html>' % user).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()
class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True
Server(('', 8000), Handler).serve_forever()
PY
nohup python3 fixtures/serve.py > fixtures/server.log 2>&1 &
ready=0
for i in $(seq 1 30); do
  if curl -sf http://localhost:8000/sample.bin > /dev/null \
    && curl -sf http://localhost:8000/login.html > /dev/null \
    && curl -sf http://localhost:8000/article.html > /dev/null \
    && curl -sf http://localhost:8000/dialog.html > /dev/null \
    && curl -sf http://localhost:8000/links.html > /dev/null \
    && [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/auth.html)" = "401" ]; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" != "1" ]; then
  echo "fixture server did not serve all endpoints on :8000"
  cat fixtures/server.log || true
  exit 1
fi
