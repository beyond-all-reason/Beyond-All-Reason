import socket, time, threading
import pygame
from socketserver import BaseRequestHandler, TCPServer
import json

# Main configuration
TCP_IP = "127.0.0.1" # Localhost
TCP_PORT = 51234  # This port match the ones using on other scripts
update_rate = 0.0166666  # 60 hz loop cycle

#internal variables
starttime = time.time()
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
numbuttons = 0
numaxes = 0
numhats = 0
joyname = ''
foundjoystick = False

while(foundjoystick == False) :
	try:
		pygame.init()
		pygame.joystick.init()
		joystick = pygame.joystick.Joystick(0)
		joystick.init()
		numbuttons = joystick.get_numbuttons()
		numaxes = joystick.get_numaxes()
		numhats = joystick.get_numhats()
		print ("Found a joystick:", joystick.get_name(),", with", numaxes,"axes and",numbuttons,"buttons", numhats, 'hats')
		foundjoystick = True

	except Exception as error:
		print ("No joystick connected to the computer, " + str(error))
		time.sleep(2)

def getjoydata():
	pygame.event.pump()
	joydata = {'time': time.time() - starttime}
	joydata['axes'] = [0.0] * numaxes
	joydata['buttons'] = [0] * numbuttons
	joydata['hats'] = [0.0] * 2

	for ax in range(numaxes):
		joydata['axes'][ax] = joystick.get_axis(ax)
	for but in range(numbuttons):
		joydata['buttons'][but] = joystick.get_button(but)
	for hat in range(min(1,numhats)):
		joydata['hats'] = joystick.get_hat(hat)
	return joydata
	
def joydatatostring(jd):
	return 'time = %.3f '%(jd['time']) + 'buttons = ' + str(jd['buttons']) +  ' axes = ['+ ', '.join(['%.3f'%a for a in jd['axes']]) + '] hats = ' + str(jd['hats'])
	
class handler(BaseRequestHandler):
	def handle(self):
		print ("Starting handler")
		i = 0
		while True:
			i += 1
			current = time.time()

			joydata = getjoydata()
			if i%60 == 0 :
				print(i, joydatatostring(joydata))
			self.request.send(str.encode(json.dumps(joydata)))
			# Make this loop work at update_rate
			while current + update_rate > time.time():
				time.sleep(0.001)  # 1ms

with TCPServer(("",51234),handler) as server:
	server.timeout = 2.5
	server.serve_forever(poll_interval= 0.016)

while True: # this is never executed as serve_forever is blocking
	current = time.time()
	print (joydatatostring(getjoydata()))

	while current + update_rate > time.time():
		time.sleep(0.001) # 1ms
