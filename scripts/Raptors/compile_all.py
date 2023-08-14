import os
import sys

for file in os.listdir(os.getcwd() if len(sys.argv)<2 else sys.argv[1]):
	if file.lower().endswith('.bos'):
		cmd = "python bos2cob.py %s"%(file)
		print cmd
		os.system(cmd)