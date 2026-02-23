#!/usr/bin/env python3
"""
Simple landing page with basic auth
"""

import os
import json
import base64
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Config
USERNAME = os.environ.get('AUTH_USER', 'margaret-hamilton')
PASSWORD = os.environ.get('AUTH_PASS', 'wearebanana')
GRAFANA_URL = os.environ.get('GRAFANA_URL', 'http://localhost:3000/grafana')
PROMETHEUS_URL = os.environ.get('PROMETHEUS_URL', 'http://localhost:9090/prometheus')
BILLING_URL = os.environ.get('BILLING_URL', 'http://localhost:8080/')

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GPU MIG vs Time Slicing - Monitoring</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255,255,255,0.05);
            border-radius: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.1);
            max-width: 800px;
        }
        h1 { font-size: 2.5rem; margin-bottom: 10px; background: linear-gradient(90deg, #00d4ff, #7b2cbf); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .subtitle { color: #888; margin-bottom: 40px; font-size: 1.1rem; }
        .links { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 30px; }
        .link-card {
            background: rgba(255,255,255,0.08);
            padding: 25px;
            border-radius: 15px;
            text-decoration: none;
            color: #fff;
            transition: all 0.3s;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .link-card:hover { transform: translateY(-5px); background: rgba(255,255,255,0.12); border-color: #00d4ff; }
        .link-card h3 { color: #00d4ff; margin-bottom: 8px; font-size: 1.3rem; }
        .link-card p { color: #aaa; font-size: 0.9rem; }
        .login-form {
            background: rgba(255,255,255,0.08);
            padding: 30px;
            border-radius: 15px;
            max-width: 400px;
            margin: 0 auto;
        }
        .login-form input {
            width: 100%;
            padding: 12px 15px;
            margin: 10px 0;
            border-radius: 8px;
            border: 1px solid rgba(255,255,255,0.2);
            background: rgba(0,0,0,0.3);
            color: #fff;
            font-size: 1rem;
        }
        .login-form button {
            width: 100%;
            padding: 12px;
            background: linear-gradient(90deg, #00d4ff, #7b2cbf);
            border: none;
            border-radius: 8px;
            color: #fff;
            font-size: 1rem;
            font-weight: bold;
            cursor: pointer;
            margin-top: 10px;
        }
        .login-form button:hover { opacity: 0.9; }
        .error { color: #ff6b6b; margin-top: 10px; }
        .logo { font-size: 4rem; margin-bottom: 20px; }
        .version { margin-top: 30px; color: #666; font-size: 0.8rem; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>GPU MIG vs Time Slicing</h1>
        <p class="subtitle">Infrastructure Monitoring Dashboard</p>
        
        <div class="links">
            <a href="/grafana" class="link-card">
                <h3>📊 Grafana</h3>
                <p>Metrics & Dashboards</p>
            </a>
            <a href="/prometheus" class="link-card">
                <h3>📈 Prometheus</h3>
                <p>Time Series Data</p>
            </a>
            <a href="/billing" class="link-card">
                <h3>💰 Billing</h3>
                <p>Cost Analysis</p>
            </a>
        </div>
        
        <div class="version">
            Instance: dev-deployment-test | Zone: fr-par-2 | 
            DNS: dda6040a-6b4a-46f1-bafb-d8105f7ebc68.pub.instances.scw.cloud
        </div>
    </div>
</body>
</html>
"""

AUTH_COOKIE = "auth_token"
AUTH_TOKEN = base64.b64encode(f"{USERNAME}:{datetime.now().date()}".encode()).decode()


class LandingHandler(BaseHTTPRequestHandler):
    """HTTP handler for landing page"""
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().isoformat()}] {format % args}")
    
    def send_html(self, html, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def check_auth(self):
        """Check if user is authenticated"""
        auth_header = self.headers.get('Authorization', '')
        if auth_header.startswith('Basic '):
            try:
                encoded = auth_header[6:]
                decoded = base64.b64decode(encoded).decode()
                user, pwd = decoded.split(':', 1)
                if user == USERNAME and pwd == PASSWORD:
                    return True
            except:
                pass
        return False
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode())
            return
        
        # Check auth for services
        if path.startswith('/grafana') or path.startswith('/prometheus') or path.startswith('/billing'):
            if not self.check_auth():
                self.send_response(401)
                self.send_header('WWW-Authenticate', 'Basic realm="GPU Monitoring"')
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                error_html = """
                <!DOCTYPE html>
                <html><body>
                <h1>Authentication Required</h1>
                <p>Please enter your credentials to access the monitoring dashboard.</p>
                </body></html>
                """
                self.wfile.write(error_html.encode())
                return
        
        # Serve landing page
        self.send_html(HTML_PAGE)
    
    def do_POST(self):
        """Handle login form"""
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode()
        
        # Simple check - in real use, validate properly
        if 'username' in body and 'password' in body:
            self.send_html(HTML_PAGE)
        else:
            self.send_html(HTML_PAGE)


def main():
    port = int(os.environ.get('PORT', 80))
    server = HTTPServer(('0.0.0.0', port), LandingHandler)
    print(f'Starting landing page on port {port}')
    print(f'Auth: {USERNAME} / {PASSWORD}')
    server.serve_forever()


if __name__ == '__main__':
    main()