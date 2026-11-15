"""로컬 웹 프록시의 정적 파일·API·Auth·WebSocket 전달 확인."""
import functools
import http.client
import socket
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from dev_server import Handler


class Upstream(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.headers.get('Upgrade') == 'websocket':
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.end_headers()
            self.wfile.flush()
            data = self.connection.recv(5)
            self.connection.sendall(data)
            return
        body = self.headers.get('Authorization', '').encode()
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        body = self.rfile.read(int(self.headers['Content-Length']))
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class ProxyTest(unittest.TestCase):
    def test_static_api_auth_and_websocket(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, 'index.html').write_text('busro')
            upstream = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
            target = f'http://127.0.0.1:{upstream.server_port}'
            proxy_handler = type('ProxyHandler', (Handler,), {'api': target, 'auth': target})
            proxy = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(proxy_handler, directory=directory))
            for server in (upstream, proxy):
                threading.Thread(target=server.serve_forever, daemon=True).start()
            try:
                for path, method, body, expected in [
                    ('/reset-password', 'GET', None, b'busro'),
                    ('/api/v1/me', 'GET', None, b'Bearer test-token'),
                    ('/auth/v1/token?grant_type=password', 'POST', b'example', b'example'),
                ]:
                    connection = http.client.HTTPConnection('127.0.0.1', proxy.server_port, timeout=3)
                    connection.request(method, path, body=body, headers={'Authorization': 'Bearer test-token'})
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    self.assertEqual(response.read(), expected)
                    connection.close()
                with socket.create_connection(('127.0.0.1', proxy.server_port), timeout=3) as client:
                    client.sendall(b'GET /api/v1/journeys/test/stream HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
                    response = b''
                    while b'\r\n\r\n' not in response:
                        response += client.recv(1024)
                    self.assertIn(b'101 Switching Protocols', response)
                    client.sendall(b'hello')
                    self.assertEqual(client.recv(5), b'hello')
            finally:
                for server in (proxy, upstream):
                    server.shutdown()
                    server.server_close()


if __name__ == '__main__':
    unittest.main()
