python
import os

from optparse import OptionParser

# Improve OptionParser readability and adhere to PEP 8 (line breaks, redundant arguments).
usage = "usage: %prog -i inputbos -o outputbos -n minsleep -x maxsleep -a animspeeddefault -f forcesmooth, use -h for detailed help"
parser = OptionParser(usage=usage, version="%prog 1.0")
parser.add_option("-i", "--input", action="store", dest="infile",
                  help="Input BOS file to be optimized")  # type="string" is default
parser.add_option("-o", "--output", action="store", dest="outfile",
                  help="Output BOS file, defaults to overwrite!")
parser.add_option("-f", "--forcesmooth", action="store_true",
                  dest="force", help="Force sleep [x]/currentspeed syntax")  # default=False is implicit for store_true
parser.add_option("-n", "--minsleep", action="store", type="int", dest="minsleep",
                  help="minimum sleep length to smooth", default=33)
parser.add_option("-x", "--maxsleep", action="store", type="int", dest="maxsleep",
                  help="maximum sleep length to smooth", default=400)
parser.add_option("-a", "--animspeed", action="store", type="int", dest="animspeed",
                  help="default anim speed for wonky things", default=65)
(options, args) = parser.parse_args()
print 'options:', options

# Remove unused class Piece (it was defined but never instantiated or used).
# class Piece:
# 	rx=0
# 	ry=0
# 	rz=0
# 	mx=0
# 	mz=0
# 	my=0

if not options.infile:
    print 'smoother needs at least a bos script specified! (-i)'
    exit(1)

infile = options.infile
# Use a more Pythonic way for conditional assignment.
output = options.outfile if options.outfile else options.infile
minsleep = options.minsleep
maxsleep = options.maxsleep
animspeed = options.animspeed
forcesmooth = options.force
pieces = {}

# Use 'with' statement for proper file handling (guarantees file closure).
with open(infile, 'r') as f:
    inputfile_lines = f.readlines()

# process the bos file to extract piece names from a "comment-stripped" single string representation.
# This approach is brittle but preserved for minimal change.
wholefile = ''.join([line.strip().partition('//')[0] for line in inputfile_lines])
piecenames = [pname.strip(' ,;') for pname in wholefile.partition('piece')[2].partition(';')[0].lower().strip().split(',')]
print piecenames
for p in piecenames:
    if p != '':
        pieces[p] = {'move': {'x': 0, 'y': 0, 'z': 0}, 'turn': {'x': 0, 'y': 0, 'z': 0}}
print pieces


def parsebos(line, verbose=True):
    # Parses a move or turn command, returns False on any anomaly.
    # Returns a dict: {'command':str, 'piece':str, 'axis':str, 'position':float, 'speed':str/float, 'acceleration':float}
    # l=line # Unused variable, remove.
    line_processed = line.replace('  ', ' ').lower().partition('//')[0]  # remove comment
    line_processed = line_processed.strip().strip(';').split(' ')

    # move rleg to y-axis [0.250000] now;
    if len(line_processed) < 5:
        if verbose:
            print 'line split is less than 5, not a proper move/turn command!', line_processed, line
        return False

    if line_processed[0] != 'turn' and line_processed[0] != 'move':
        if verbose:
            print 'line[0] is not turn or move', line
        return False
    else:
        command = line_processed[0]

    if line_processed[1] not in pieces:
        if verbose:
            print 'invalid piece', line, 'not in piecelist', pieces
        return False
    else:
        piece = line_processed[1]

    if line_processed[2] != 'to':
        if verbose:
            print "line[2] != to", line
        return False

    if '-axis' not in line_processed[3] and not ('x-' in line_processed[3] or 'y-' in line_processed[3] or 'z-' in line_processed[3]):
        if verbose:
            print 'bad axis in line[3]', line
        return False
    else:
        axis = line_processed[3][0]
        if axis not in 'xyz':
            if verbose:
                # Removed redundant print of 'axis fail!' after previous check for bad axis.
                pass
            return False

    try:
        if command == 'move' and ('[' not in line_processed[4] or ']' not in line_processed[4]):
            if verbose:
                print 'missing [ or ] in pos of move command', line
            return False
        elif command == 'turn' and ('<' not in line_processed[4] or '>' not in line_processed[4]):
            if verbose:
                print 'missing < or > in pos of turn command', line
            return False
        else:
            pos = float(line_processed[4].strip('[]<>'))
    except ValueError:
        if verbose:
            print 'cant parse pos in', line, line_processed
        return False

    if line_processed[5] == 'now':
        speed = 'now'
    elif line_processed[5] == 'speed':
        try:
            if command == 'move' and ('[' not in line_processed[6] or ']' not in line_processed[6]):
                if verbose:
                    print 'missing [ or ] in speed of move command', line
                return False
            elif command == 'turn' and ('<' not in line_processed[6] or '>' not in line_processed[6]):
                if verbose:
                    print 'missing < or > in speed of turn command', line
                return False
            else:
                speed = float(line_processed[6].strip('[]<>'))
        except ValueError:  # Fix: Use specific ValueError instead of bare except
            if verbose:
                print 'cant parse speed in', line, line_processed
            return False
    else:
        if verbose:
            print 'bad line[6]', line_processed[6], line
        return False

    # Use consistent indexing (7 and 8 are based on 'accelerate' presence)
    if len(line_processed) >= 9 and line_processed[7] == 'accelerate':
        try:
            if command == 'move' and ('[' not in line_processed[8] or ']' not in line_processed[8]):
                if verbose:
                    # Fix: Print message should refer to accelerate, not speed.
                    print 'missing [ or ] in accelerate of move command', line
                return False
            elif command == 'turn' and ('<' not in line_processed[8] or '>' not in line_processed[8]):
                if verbose:
                    # Fix: Print message should refer to accelerate, not speed.
                    print 'missing < or > in accelerate of turn command', line
                return False
            else:
                acc = float(line_processed[8].strip('[]<>'))
        except ValueError:  # Fix: Use specific ValueError instead of bare except
            if verbose:
                print 'cant parse accelerate in', line, line_processed[8]
            return False
    else:
        acc = 0

    # Fix critical bug in dictionary keys: 'p' and 'a' were overwritten.
    # Use descriptive keys for clarity and correctness.
    return {'command': command, 'piece': piece, 'axis': axis, 'position': pos, 'speed': speed, 'acceleration': acc}


# Use enumerate for cleaner loop index. Store parsebos results to avoid re-parsing and handle False returns.
for i, line in enumerate(inputfile_lines):
    if ('move' in line or 'turn' in line) and 'now' in line:
        sleep = -1
        sleepline = -1

        orig_bos_data = parsebos(line, False)  # Parse once
        if not orig_bos_data:  # If original line isn't a valid command, skip
            continue

        for k in range(i + 1, min(i + 20, len(inputfile_lines))):
            next_bos_data = parsebos(inputfile_lines[k], False)  # Parse once
            if next_bos_data:  # Check if next line is a valid BOS command
                if 'wait-for-' + orig_bos_data['command'] in inputfile_lines[k] \
                        and orig_bos_data['piece'] in inputfile_lines[k] \
                        and orig_bos_data['axis'] + '-axis' in inputfile_lines[k]:
                    print 'There is a wait-for command referring to this piece on this axis, skipping', inputfile_lines[k]
                    break

                if orig_bos_data['command'] == next_bos_data['command'] \
                        and orig_bos_data['piece'] == next_bos_data['piece'] \
                        and orig_bos_data['axis'] == next_bos_data['axis']:
                    print 'There is an identical move order ', k - i, 'lines after, we just need to update the piece pos!'
                    # Update dictionary access to use correct keys after parsebos fix.
                    pieces[orig_bos_data['piece']][orig_bos_data['command']][orig_bos_data['axis']] = orig_bos_data['position']
                    break

            if 'sleep' in inputfile_lines[k].partition('//')[0]:
                if 'animSpeed' in inputfile_lines[k].partition('//')[0]:
                    sleep = 'animSpeed'
                    break
                elif 'currentSpeed' in inputfile_lines[k].partition('//')[0]:
                    sleep = 'currentSpeed'
                    try:
                        # Ensure float division for animspeed calculation when parsing 'currentSpeed'.
                        # The original `int(...) / 100` would be integer division in Python 2.
                        animspeed = int(inputfile_lines[k].partition('sleep')[2].partition('/')[0]) / 100.0
                        break
                    except ValueError:
                        print 'failed to parse sleep in line', inputfile_lines[k], 'skipping'
                        continue
                else:
                    try:
                        sleep = float(inputfile_lines[k].partition('sleep')[2].partition(';')[0])
                        sleepline = k
                        break
                    except ValueError:
                        print 'failed to parse sleep in line', inputfile_lines[k], 'skipping'
                        continue
            if '}' in inputfile_lines[k].partition('//')[0]:
                print 'no sleep after now'
                break

        if sleep == 'animSpeed' or sleep == 'currentSpeed' or (sleep > minsleep and sleep < maxsleep):
            bos_data = orig_bos_data  # Use the already parsed data
            # Update dictionary access to use correct keys after parsebos fix.
            oldpos = pieces[bos_data['piece']][bos_data['command']][bos_data['axis']]
            if bos_data['speed'] == 'now':
                dist = abs(oldpos - bos_data['position'])
                if sleep == 'animSpeed':
                    smanim = True
                    sleep = animspeed
                else:
                    smanim = False
                if sleep == 'currentSpeed':
                    sleep = animspeed
                    smanim = True

                # Refine sleep calculation for Python 2 to match original logic precisely.
                # Original logic: (int(sleep)/33+1)*33+17, where `/` is integer division if operands are int.
                # Ensure float values are first cast to int for this specific calculation.
                calculated_frames = (int(sleep) / 33) + 1  # Python 2 integer division
                sleep = calculated_frames * 33 + 17  # Update sleep value (it's in ms now)

                speed = dist / (float(sleep) / 990)
                if dist != 0:
                    if bos_data['command'] == 'turn':
                        s = 'speed <%f>' % (speed)
                    else:
                        s = 'speed [%f]' % (speed)
                    if smanim or forcesmooth:
                        s += ' * currentSpeed / 100'  # Cleaned up extra space
                    inputfile_lines[i] = line.replace('now', s)
                    if forcesmooth and sleepline > 0:
                        inputfile_lines[sleepline] = inputfile_lines[sleepline].partition('sleep')[0] + 'sleep ' + str(sleep * 100) + ' / currentSpeed;\n'

            # Update dictionary access to use correct keys after parsebos fix.
            pieces[bos_data['piece']][bos_data['command']][bos_data['axis']] = bos_data['position']
            # Removed unreachable else block.

# Use 'with' statement for proper file handling.
with open(output, 'w') as outf:
    outf.write(''.join(inputfile_lines))
print 'Done'