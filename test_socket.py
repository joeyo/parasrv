#!/usr/bin/env python
import socket
import sys
import os


sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

server_address = '/tmp/parasrv.sock'
sock.connect(server_address)
sock.sendall('test')
sock.close()