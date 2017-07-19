"""A simple HTTP server, that serves a given static html file"""
import SocketServer
import BaseHTTPServer
import sys
import shutil
import socket
import os


if len(sys.argv) < 3:
    print "This scripts takes 2 arguments:"
    print "     - The address on which to serve it"
    print "     - The filename to server"
    sys.exit()

PORT = 80
ADDRESS = sys.argv[1]
FILE = sys.argv[2]


class LookingGlassServer(SocketServer.TCPServer):
    address_family = socket.AF_INET6
    allow_reuse_address = True


class req_handler(BaseHTTPServer.BaseHTTPRequestHandler):
    def do_GET(self):
        f = None
        try:
            f = open(FILE, 'rb')
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            fs = os.fstat(f.fileno())
            self.send_header("Content-Length", str(fs[6]))
            self.send_header("Last-Modified",
                             self.date_time_string(fs.st_mtime))
            self.end_headers()
            shutil.copyfileobj(f, self.wfile)
        except:
            self.send_response(500)
        finally:
            if f:
                f.close()



httpd = LookingGlassServer((ADDRESS, PORT), req_handler)
httpd.serve_forever()
