#!/usr/bin/env python3
"""Flutter 웹 빌드와 기존 API/Auth를 같은 origin으로 제공하는 로컬 전용 서버."""
import argparse
import http.client
import select
import socket
import ssl
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class Handler(SimpleHTTPRequestHandler):
    api = auth = None

    def log_message(self, format, *args):
        pass  # 인증 요청·이메일·토큰을 출력하지 않습니다.

    def _proxy(self):
        path = urlsplit(self.path).path
        target = self.api if path == '/health' or path.startswith('/api/v1/') else self.auth if path.startswith('/auth/v1/') else None
        if target is None:
            return False
        upstream = urlsplit(target)
        host, port = upstream.hostname, upstream.port or (443 if upstream.scheme == 'https' else 80)
        if self.headers.get('Upgrade', '').lower() == 'websocket':
            self.close_connection = True
            try:
                with socket.create_connection((host, port), timeout=10) as raw:
                    remote = ssl.create_default_context().wrap_socket(raw, server_hostname=host) if upstream.scheme == 'https' else raw
                    with remote:
                        headers = ''.join(f'{key}: {value}\r\n' for key, value in self.headers.items() if key.lower() != 'host')
                        remote.sendall(f'{self.command} {self.path} HTTP/1.1\r\nHost: {upstream.netloc}\r\n{headers}\r\n'.encode('latin-1'))
                        while True:
                            ready, _, _ = select.select([remote, self.connection], [], [], 60)
                            if not ready:
                                return True
                            for source in ready:
                                data = source.recv(65536)
                                if not data:
                                    return True
                                (self.connection if source is remote else remote).sendall(data)
            except OSError:
                return True
        else:
            connection = (http.client.HTTPSConnection if upstream.scheme == 'https' else http.client.HTTPConnection)(host, port, timeout=30)
            try:
                length = int(self.headers.get('Content-Length', 0))
                if length < 0 or length > 1_048_576:
                    self.send_error(413)
                    return True
                body = self.rfile.read(length) if length else None
                headers = {k: v for k, v in self.headers.items() if k.lower() not in {'host', 'connection', 'content-length'}}
                connection.request(self.command, self.path, body=body, headers=headers)
                response = connection.getresponse()
                data = response.read()
                self.send_response(response.status)
                for key, value in response.getheaders():
                    if key.lower() not in {'connection', 'transfer-encoding', 'content-length'}:
                        self.send_header(key, value)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except (OSError, http.client.HTTPException, ValueError):
                self.send_error(502, 'Upstream server unavailable')
            finally:
                connection.close()
        return True

    def do_GET(self):
        if self._proxy():
            return
        path = urlsplit(self.path).path
        if not Path(self.translate_path(path)).exists() and '.' not in path.rsplit('/', 1)[-1]:
            self.path = '/index.html'
        super().do_GET()

    def do_POST(self):
        if not self._proxy():
            self.send_error(404)

    do_PATCH = do_PUT = do_DELETE = do_POST


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=3000)
    parser.add_argument('--api', default='http://127.0.0.1:8001')
    parser.add_argument('--auth', default='http://127.0.0.1:8100')
    parser.add_argument('--directory', default=str(Path(__file__).resolve().parents[1] / 'build/web'))
    args = parser.parse_args()
    if not (Path(args.directory) / 'index.html').is_file():
        parser.error('flutter build web을 먼저 실행해 주세요.')
    Handler.api, Handler.auth = args.api, args.auth
    print(f'버스로: http://localhost:{args.port} (종료: Ctrl+C)', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=args.directory)).serve_forever()


if __name__ == '__main__':
    main()
