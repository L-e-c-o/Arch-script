# -*- coding: utf-8 -*-

import http.server
import socketserver
import logging
import re
import urllib.parse
import sys

logging.basicConfig(format='[%(levelname)s][%(asctime)s] %(message)s', datefmt='%H:%M:%S', level=logging.DEBUG)

data = {}

def add_new_entry(name, line):
	splitted = line.split(" ")
	ip = splitted[0]
	time = splitted[3]
	time = time[1:]
	data[name][time] = ip

def create_new_user(name, line):
	data[name] = {}
	add_new_entry(name, line)

def parse(filename):
	logging.info('Log parsing started')
	with open(filename, "r") as f:
		lines = f.readlines()
		for line in lines:
			if "fullName" in line:
				m = re.search(r'(?<=fullName=)(.*)(?=&join)', line)
				name = urllib.parse.unquote_plus(m.group())
				name = urllib.parse.unquote(name)
				if name not in data:
					create_new_user(name, line)
				else:
					add_new_entry(name, line)
					

	logging.info('Log parsing ended')
	logging.debug('Found ' + str(len(data)) + ' users')
	"""for name in sorted(data):
		logging.debug(name + " connected " + str(len(data[name])) + " times")
		for k, v in data[name].items():
			print(k + " from " + v)"""

def generate_html():
	logging.info("Generating HTML file")
	html = '<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"><title>BBB Log Parser</title><link rel="icon" href="https://bigbluebutton.org/wp-content/themes/bigbluebutton/favicon.png"><link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css"><script src="https://code.jquery.com/jquery-3.4.1.slim.min.js"></script><script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js"></script><script src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js"></script></head><body><style>tbody:nth-child(odd){background:#DCDCDC}tbody:hover td[rowspan],tr:hover td{background:#95CDEB}</style><div class="container"><br/><div class="table-responsive-xl"><table class="table table-bordered" style="text-align:center;"><thead class="thead-dark"><tr><th>User</th><th>IP</th><th>Date</th><th>Time</th></tr></thead>'
	logging.info("Filling table with data")
	rowspan = 0
	for name in sorted(data): # name = key
		html += '<tbody>'
		for date, ip in data[name].items(): # date = key / ip = value
			html += '<tr>'
			if rowspan == 0:
				html += ('<td rowspan="%d" style="vertical-align:middle;text-align:center;">%s</td>' % (len(data[name]), name))
				rowspan = 1
			html += ('<td>%s</td>' % (ip))
			date = date.split(":",1)
			html += ('<td>%s</td>' % (date[0])) # date
			html += ('<td>%s</td>' % (date[1])) # heure
			html += '</tr>'
		html += '</tbody>'
		rowspan = 0
	html += '</table></div></div></body></html>'
	with open("index.html", "w") as f:
		f.write(html)
	logging.info("HTML file generated")
			
def start_http():
	port = 8080
	http_handler = http.server.SimpleHTTPRequestHandler

	with socketserver.TCPServer(("", port), http_handler) as httpd:
		logging.info('Serving at 0.0.0.0:' + str(port))
		httpd.serve_forever()

if __name__ == "__main__":
	if len(sys.argv) != 2:
		print("Usage : python parser.py <filename>")
		exit()
	parse(sys.argv[1])
	generate_html()
	start_http()
