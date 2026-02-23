#!/usr/bin/env python3
"""
Scaleway Billing API
Fetches billing consumption data using Python stdlib (urllib)
"""

import os
import json
import urllib.request
import urllib.error
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, urlencode

SCW_SECRET_KEY = os.environ.get('SCW_SECRET_KEY', '')
SCW_PROJECT_ID = os.environ.get('SCW_PROJECT_ID', 'bbaff92f-ddd8-493b-8d03-05de850deb29')


def get_billing_data():
    """Fetch billing consumption from Scaleway API using urllib"""
    url = f"https://api.scaleway.com/billing/v2beta1/consumptions?project_id={SCW_PROJECT_ID}"
    
    headers = {
        'X-Auth-Token': SCW_SECRET_KEY,
        'Content-Type': 'application/json'
    }
    
    try:
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode())
            return {'data': data.get('consumptions', []), 'error': None}
    except Exception as e:
        return {'error': str(e), 'data': []}


def calculate_cost(units, nanos):
    """Calculate cost from units and nanos"""
    total = units + (nanos / 1_000_000_000)
    return round(total, 4)


def get_total_cost(data):
    """Calculate total cost"""
    total = 0
    for item in data:
        value = item.get('value', {})
        total += calculate_cost(value.get('units', 0), value.get('nanos', 0))
    return round(total, 4)


def get_cost_by_category(data):
    """Group costs by category"""
    categories = {}
    for item in data:
        cat = item.get('category_name', 'Unknown')
        value = item.get('value', {})
        cost = calculate_cost(value.get('units', 0), value.get('nanos', 0))
        categories[cat] = categories.get(cat, 0) + cost
    return categories


def get_cost_by_product(data):
    """Group costs by product"""
    products = {}
    for item in data:
        prod = item.get('product_name', 'Unknown')
        value = item.get('value', {})
        cost = calculate_cost(value.get('units', 0), value.get('nanos', 0))
        products[prod] = products.get(prod, 0) + cost
    return products


def get_instances(data):
    """Extract compute instances"""
    instances = []
    for item in data:
        product = item.get('product_name', '')
        if any(p in product for p in ['DEV1', 'L4', 'H100', 'GP1', 'PLAY']):
            value = item.get('value', {})
            cost = calculate_cost(value.get('units', 0), value.get('nanos', 0))
            billed = item.get('billed_quantity', '0')
            instances.append({
                'product': product,
                'resource': item.get('resource_name', ''),
                'quantity': billed,
                'unit': item.get('unit', 'minute'),
                'cost_eur': cost,
            })
    return instances


class BillingHandler(BaseHTTPRequestHandler):
    """HTTP handler for billing API"""
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().isoformat()}] {format % args}")
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/health':
            self.send_json({'status': 'ok', 'timestamp': datetime.now().isoformat()})
            return
        
        if path == '/metrics':
            result = get_billing_data()
            if result['error']:
                self.send_json({'error': result['error']}, 500)
                return
            
            data = result['data']
            lines = []
            total = get_total_cost(data)
            lines.append(f'scaleway_total_cost_eur {total}')
            
            for cat, cost in get_cost_by_category(data).items():
                lines.append(f'scaleway_cost_category{{category="{cat}"}} {cost}')
            
            for prod, cost in get_cost_by_product(data).items():
                prod_safe = prod.replace(' ', '_').replace('-', '_').replace('.', '_')
                lines.append(f'scaleway_cost_product{{product="{prod_safe}"}} {cost}')
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write('\n'.join(lines).encode())
            return
        
        result = get_billing_data()
        
        if result['error']:
            self.send_json({'error': result['error'], 'timestamp': datetime.now().isoformat()}, 500)
            return
        
        data = result['data']
        
        self.send_json({
            'timestamp': datetime.now().isoformat(),
            'total_cost_eur': get_total_cost(data),
            'by_category': get_cost_by_category(data),
            'by_product': get_cost_by_product(data),
            'instances': get_instances(data),
        })


def main():
    port = int(os.environ.get('PORT', 8080))
    server = HTTPServer(('0.0.0.0', port), BillingHandler)
    print(f'Starting billing API on port {port}')
    print(f'SCW Project: {SCW_PROJECT_ID}')
    server.serve_forever()


if __name__ == '__main__':
    main()
