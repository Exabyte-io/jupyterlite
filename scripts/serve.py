#!/usr/bin/env python3
"""Simple HTTP server with CORS headers for serving a folder."""
import http.server
import sys
from functools import partial

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET")
        super().end_headers()

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    folder = sys.argv[2] if len(sys.argv) > 2 else "."

    handler_class = partial(CORSHandler, directory=folder)

    print(f"Serving '{folder}' on http://localhost:{port} with CORS headers")
    http.server.ThreadingHTTPServer(("", port), handler_class).serve_forever()

if __name__ == "__main__":
    main()
