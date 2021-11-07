import os


for root, dir, files in os.walk(os.getcwd()):
	for filename in files:
		if filename.lower().endswith('.bos'):
			fpath = os.path.join(root, filename)
			boslines=open(fpath).readlines()
			hasSmokeUnit = 0
			hasHitByWeapon = 0
			hasHitByWeaponID = 0
			alreadydone = 0
			
			piecelist = []
			
			
			for i, line in enumerate( boslines):
					
				if '//' in line:
					line = line.partition('//')[0] + '\n' # uncomment it
				# 	explode body type FIRE | SMOKE | FALL | NOHEATCLOUD;
				
				if '#define SMOKEPIECE' in line:
					alreadydone = 1
				if 'HitByWeaponId(' in line:
					hasHitByWeaponID = i
				if 'HitByWeapon(' in line: 
					hasHitByWeapon = i
				if 'SmokeUnit(' in line:
					hasSmokeUnit = i
				if line.startswith('piece') and piecelist == []:
					piecelist = line[6:].replace(';','').strip().split(',')
			try:
				piecelist[0]
			except IndexError:
				print ("     Warning, no pieces found for", filename)
				continue
			
			if alreadydone == 1 :
				continue
			
			if hasHitByWeapon == 0 and hasHitByWeaponID == 0 and hasSmokeUnit:
				# the easy case, we only need to include smokeunit_thread
				# 1. delete start-script smokeunit();
				# 2. delete smokeunit(){}
				# 3  add hitbyweapon()
				# 4. add smokeunit()
				# replace smokepiece with first piece in piece list
				
				print ("OnlySmokeUnit", filename, piecelist[0],hasHitByWeapon, hasHitByWeaponID, hasSmokeUnit)
			elif hasHitByWeapon and hasHitByWeaponID == 0 and hasSmokeUnit:
				print ("hasHitByWeaponID", filename, piecelist[0],hasHitByWeapon, hasHitByWeaponID, hasSmokeUnit)
			elif hasHitByWeapon == 0 and hasHitByWeaponID == 0 and hasSmokeUnit == 0:
				print ("NoSmoke", filename, piecelist[0],hasHitByWeapon, hasHitByWeaponID, hasSmokeUnit)
			else:
				print ("TODO", filename, piecelist[0],hasHitByWeapon, hasHitByWeaponID, hasSmokeUnit)
			
			if False and fixed > 0:
				
				bosfile=open(fpath,'w')
				bosfile.write(''.join(boslines))
				bosfile.close()
				# print ''.join(newbosfle)