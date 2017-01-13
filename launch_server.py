"""Run the correction server depending on the python version"""
import platform


if platform.python_version_tuple()[0] == '3':
    import http.server
    import socketserver

    PORT = 8000
    Handler = http.server.SimpleHTTPRequestHandler
    httpd = socketserver.TCPServer(("", PORT), Handler)
    httpd.serve_forever()
    # python -m http.server
elif platform.python_version_tuple()[0] == '2':
    import SimpleHTTPServer
    import SocketServer

    PORT = 8000
    Handler = SimpleHTTPServer.SimpleHTTPRequestHandler
    httpd = SocketServer.TCPServer(("", PORT), Handler)
    httpd.serve_forever()
    # python -m SimpleHTTPServer 8000
else:
    print('Unknown python version')
