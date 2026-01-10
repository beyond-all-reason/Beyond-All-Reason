import re
import sqlite3
import json
import time
import os
import sys
import argparse
import platform
import subprocess
import asyncio
import threading
from datetime import datetime

# WebSocket server to push live updates to dashboard (browser uses native WebSocket)
try:
    import websockets
    WS_AVAILABLE = True
except ImportError:
    WS_AVAILABLE = False
    print("[Parser] websockets not installed. Live dashboard updates disabled.")
    print("Install with: pip install websockets")

WS_PORT = 8765
ws_clients = set()
ws_loop = None
_last_broadcast_time = 0.0


def find_bar_data_dir():
    """Find the Beyond All Reason data directory using OS-specific conventions."""
    system = platform.system()
    if system == 'Windows':
        local_appdata = os.environ.get('LOCALAPPDATA', os.path.expanduser('~\\AppData\\Local'))
        return os.path.join(local_appdata, 'Programs', 'Beyond-All-Reason', 'data')
    elif system == 'Linux':
        if 'microsoft' in platform.release().lower() or 'wsl' in platform.release().lower():
            try:
                win_home = subprocess.check_output(['wslpath', '-u', subprocess.check_output(['cmd.exe', '/c', 'echo', '%LOCALAPPDATA%'], stderr=subprocess.DEVNULL).decode().strip()], stderr=subprocess.DEVNULL).decode().strip()
                wsl_path = os.path.join(win_home, 'Programs', 'Beyond-All-Reason', 'data')
                if os.path.exists(wsl_path): return wsl_path
            except: pass
        try:
            documents = subprocess.check_output(['xdg-user-dir', 'DOCUMENTS'], encoding='utf-8', stderr=subprocess.DEVNULL).strip()
        except:
            documents = os.path.expanduser("~")
        docs_path = os.path.join(documents, 'Beyond All Reason')
        if os.path.exists(docs_path): return docs_path
        state_home = os.environ.get('XDG_STATE_HOME', os.path.join(os.path.expanduser("~"), '.local', 'state'))
        return os.path.join(state_home, 'Beyond All Reason')
    elif system == 'Darwin':
        return os.path.expanduser('~/Library/Application Support/Beyond All Reason')
    return os.path.expanduser('~/.local/share/Beyond All Reason')


# Configuration
BAR_DATA_DIR = find_bar_data_dir()
LOG_FILE_PATH = os.path.join(BAR_DATA_DIR, 'economy_audit.txt')
DB_PATH = os.path.join(BAR_DATA_DIR, "economy_audit.db")
VERBOSE = False

def log(msg):
    if VERBOSE: print(f"[DEBUG] {msg}")

def broadcast_event(event_type, data):
    global ws_loop, _last_broadcast_time
    if not WS_AVAILABLE or ws_loop is None or not ws_clients:
        return
    now = time.time()
    if now - _last_broadcast_time < 0.5:
        return
    _last_broadcast_time = now
    try:
        message = json.dumps({'type': event_type, 'data': data})
        asyncio.run_coroutine_threadsafe(_ws_broadcast(message), ws_loop)
    except Exception as e:
        if VERBOSE: log(f"WebSocket broadcast failed: {e}")

async def _ws_broadcast(message):
    if not ws_clients:
        return
    await asyncio.gather(
        *[client.send(message) for client in list(ws_clients)],
        return_exceptions=True
    )

async def ws_handler(websocket):
    ws_clients.add(websocket)
    if VERBOSE:
        print(f"[WS] Client connected ({len(ws_clients)} total)")
    try:
        async for _ in websocket:
            pass
    except Exception:
        pass
    finally:
        ws_clients.discard(websocket)
        if VERBOSE:
            print(f"[WS] Client disconnected ({len(ws_clients)} total)")

def run_ws_server():
    global ws_loop
    async def serve():
        async with websockets.serve(ws_handler, "127.0.0.1", WS_PORT):
            print(f"[Parser] WebSocket server: ws://127.0.0.1:{WS_PORT}")
            await asyncio.Future()

    ws_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(ws_loop)
    ws_loop.run_until_complete(serve())

def init_db():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    c = conn.cursor()
    c.execute("PRAGMA journal_mode=WAL;")
    
    c.execute('''CREATE TABLE IF NOT EXISTS game_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_timestamp TEXT NOT NULL, end_timestamp TEXT,
        start_frame INTEGER NOT NULL, end_frame INTEGER,
        team_count INTEGER NOT NULL, duration_frames INTEGER,
        session_types TEXT
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS solver_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, metric TEXT NOT NULL, time_us REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_input (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, team_id INTEGER NOT NULL, current REAL NOT NULL,
        resource TEXT NOT NULL, cumulative_sent REAL NOT NULL, share_slider REAL NOT NULL,
        storage REAL NOT NULL, ally_team INTEGER NOT NULL, share_cursor REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_output (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, team_id INTEGER NOT NULL, current REAL NOT NULL,
        resource TEXT NOT NULL, received REAL NOT NULL, sent REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_group_lift (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, member_count INTEGER NOT NULL, resource TEXT NOT NULL,
        lift REAL NOT NULL, total_demand REAL NOT NULL, total_supply REAL NOT NULL, ally_team INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_frame_start (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, tax_rate REAL NOT NULL, metal_threshold REAL NOT NULL,
        energy_threshold REAL NOT NULL, team_count INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_transfer (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, sender_team_id INTEGER NOT NULL, receiver_team_id INTEGER NOT NULL,
        resource TEXT NOT NULL, amount REAL NOT NULL, untaxed REAL NOT NULL, taxed REAL NOT NULL,
        transfer_type TEXT NOT NULL DEFAULT 'passive',
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    
    # Migration: add transfer_type column if missing (for existing databases)
    try:
        c.execute("ALTER TABLE eco_transfer ADD COLUMN transfer_type TEXT NOT NULL DEFAULT 'passive'")
    except sqlite3.OperationalError:
        pass
    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_waterfill (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, team_id INTEGER NOT NULL, ally_team INTEGER NOT NULL,
        resource TEXT NOT NULL, current REAL NOT NULL, target REAL NOT NULL,
        role TEXT NOT NULL, delta REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS team_names (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        team_id INTEGER NOT NULL, name TEXT NOT NULL, is_ai INTEGER NOT NULL,
        ally_team INTEGER NOT NULL, is_gaia INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id),
        UNIQUE(session_id, team_id)
    )''')
    
    # Performance indices
    c.execute("CREATE INDEX IF NOT EXISTS idx_eco_input_lookup ON eco_team_input (session_id, frame, resource)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_eco_output_lookup ON eco_team_output (session_id, frame, resource)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_eco_waterfill_lookup ON eco_team_waterfill (session_id, frame, resource)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_solver_audit_lookup ON solver_audit (session_id, frame)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_eco_transfer_lookup ON eco_transfer (session_id, frame, resource)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_eco_group_lift_lookup ON eco_group_lift (session_id, frame, resource)")
    
    conn.commit()
    return conn

def reset_db(conn):
    c = conn.cursor()
    tables = ['solver_audit', 'eco_team_input', 'eco_team_output', 'eco_group_lift', 'eco_frame_start', 'eco_transfer', 'eco_team_waterfill', 'team_names', 'game_sessions']
    for table in tables: c.execute(f"DROP TABLE IF EXISTS {table}")
    conn.commit()
    return init_db()

class SessionTracker:
    def __init__(self, conn):
        self.conn = conn
        self.current_session_id = None
        self.last_frame = -1
        self.session_start_timestamp = None
        self.session_start_frame = None
        self.session_team_count = None
        self.session_types = set()
        self._load_existing_session()
    
    def _load_existing_session(self):
        c = self.conn.cursor()
        c.execute("SELECT id, end_frame, start_frame, team_count, session_types FROM game_sessions ORDER BY id DESC LIMIT 1")
        row = c.fetchone()
        if row:
            self.current_session_id = row[0]
            self.last_frame = row[1] if row[1] is not None else (row[2] or 0)
            self.session_start_frame = row[2]
            self.session_team_count = row[3]
            if row[4]:
                self.session_types = set(row[4].split(','))
    
    def _start_new_session(self, timestamp, frame, team_count):
        c = self.conn.cursor()
        tc = team_count if team_count is not None else 0
        c.execute('INSERT INTO game_sessions (start_timestamp, start_frame, team_count, session_types) VALUES (?, ?, ?, ?)', 
                 (timestamp, frame, tc, ""))
        self.conn.commit()
        self.current_session_id = c.lastrowid
        self.session_start_timestamp = timestamp
        self.session_start_frame = frame
        self.session_team_count = tc
        self.last_frame = frame
        self.session_types = set()
        print(f"[SessionTracker] Started new session #{self.current_session_id} at frame {frame}")
    
    def _end_current_session(self, timestamp, frame):
        if self.current_session_id:
            c = self.conn.cursor()
            duration = frame - (self.session_start_frame or 0)
            types_str = ",".join(sorted(list(self.session_types)))
            c.execute('UPDATE game_sessions SET end_timestamp = ?, end_frame = ?, duration_frames = ?, session_types = ? WHERE id = ?', 
                     (timestamp, frame, duration, types_str, self.current_session_id))
            self.conn.commit()
    
    def add_type(self, session_type):
        if session_type and session_type not in self.session_types:
            self.session_types.add(session_type)
            c = self.conn.cursor()
            types_str = ",".join(sorted(list(self.session_types)))
            c.execute("UPDATE game_sessions SET session_types = ? WHERE id = ?", (types_str, self.current_session_id))
            self.conn.commit()

    def check_frame(self, timestamp, frame, team_count=None):
        if self.current_session_id is None:
            self._start_new_session(timestamp, frame, team_count)
        elif frame < self.last_frame - 1000:
            self._end_current_session(timestamp, self.last_frame)
            self._start_new_session(timestamp, frame, team_count)
        self.last_frame = max(self.last_frame, frame)
        if team_count and team_count != self.session_team_count:
            self.session_team_count = team_count
            c = self.conn.cursor()
            c.execute("UPDATE game_sessions SET team_count = ? WHERE id = ?", (team_count, self.current_session_id))
        return self.current_session_id

session_tracker = None


def detect_session_type(source_path):
    """Get the economy system type from the embedded source_path."""
    if not source_path or source_path == "UNKNOWN":
        return None

    # The source_path is already the type identifier ("RE", "PE", etc.)
    # embedded by the C++ EconomyAudit::Begin() method
    return source_path


def parse_line(conn, line):
    """Parse NDJSON format: eventType {json}\n"""
    global session_tracker, event_counts
    
    line = line.strip()
    if not line or ' ' not in line:
        return False
    
    try:
        event_type, json_str = line.split(' ', 1)
        data = json.loads(json_str)
    except (ValueError, json.JSONDecodeError):
        return False
    
    frame = data.get('frame', 0)
    game_time = data.get('game_time', frame / 30.0)
    source_path = data.get('source_path', 'UNKNOWN')
    timestamp_str = datetime.now().isoformat()
    
    event_counts[event_type] = event_counts.get(event_type, 0) + 1
    
    team_count = data.get('team_count')
    session_id = session_tracker.check_frame(timestamp_str, frame, team_count) if session_tracker else None
    
    if session_tracker:
        detected_type = detect_session_type(source_path)
        if detected_type:
            session_tracker.add_type(detected_type)
    
    c = conn.cursor()
    parsed = False
    
    try:
        if event_type == "team_input":
            c.execute('INSERT INTO eco_team_input (session_id, timestamp, frame, game_time, source_path, team_id, current, resource, cumulative_sent, share_slider, storage, ally_team, share_cursor) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('team_id'), data.get('current'), data.get('resource'), data.get('cumulative_sent'), data.get('share_slider'), data.get('storage'), data.get('ally_team'), data.get('share_cursor')))
            broadcast_event('economy', {'event': 'team_input', 'frame': frame, 'team_id': data.get('team_id'), 'resource': data.get('resource')})
            parsed = True
        elif event_type == "team_output":
            c.execute('INSERT INTO eco_team_output (session_id, timestamp, frame, game_time, source_path, team_id, current, resource, received, sent) VALUES (?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('team_id'), data.get('current'), data.get('resource'), data.get('received'), data.get('sent')))
            broadcast_event('economy', {'event': 'team_output', 'frame': frame, 'team_id': data.get('team_id'), 'resource': data.get('resource')})
            parsed = True
        elif event_type == "group_lift":
            c.execute('INSERT INTO eco_group_lift (session_id, timestamp, frame, game_time, source_path, member_count, resource, lift, total_demand, total_supply, ally_team) VALUES (?,?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('member_count'), data.get('resource'), data.get('lift'), data.get('total_demand'), data.get('total_supply'), data.get('ally_team')))
            parsed = True
        elif event_type == "frame_start":
            c.execute('INSERT INTO eco_frame_start (session_id, timestamp, frame, game_time, source_path, tax_rate, metal_threshold, energy_threshold, team_count) VALUES (?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('tax_rate', 0), data.get('metal_threshold', 0), data.get('energy_threshold', 0), data.get('team_count', 0)))
            parsed = True
        elif event_type == "transfer":
            transfer_type = data.get('transfer_type', 'passive')
            c.execute('INSERT INTO eco_transfer (session_id, timestamp, frame, game_time, source_path, sender_team_id, receiver_team_id, resource, amount, untaxed, taxed, transfer_type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('sender_team_id'), data.get('receiver_team_id'), data.get('resource'), data.get('amount'), data.get('untaxed'), data.get('taxed'), transfer_type))
            parsed = True
        elif event_type == "team_waterfill":
            c.execute('INSERT INTO eco_team_waterfill (session_id, timestamp, frame, game_time, source_path, team_id, ally_team, resource, current, target, role, delta) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('team_id'), data.get('ally_team'), data.get('resource'), data.get('current', 0), data.get('target', 0), data.get('role', 'unknown'), data.get('delta', 0)))
            parsed = True
        elif event_type == "team_info":
            c.execute('INSERT OR REPLACE INTO team_names (session_id, team_id, name, is_ai, ally_team, is_gaia) VALUES (?, ?, ?, ?, ?, ?)', 
                      (session_id, data.get('team_id'), data.get('name'), 1 if data.get('is_ai') else 0, 
                       data.get('ally_team', 0), 1 if data.get('is_gaia') else 0))
            parsed = True
        elif event_type == "solver_timing":
            metric = data.get('metric', '')
            if metric.endswith('_Overall'):
                metric = 'Overall'
            c.execute("INSERT INTO solver_audit (session_id, timestamp, frame, game_time, source_path, metric, time_us) VALUES (?, ?, ?, ?, ?, ?, ?)", (session_id, timestamp_str, frame, game_time, source_path, metric, data.get('time_us', 0)))
            broadcast_event('solver_timing', {'frame': frame, 'source_path': source_path, 'metric': metric, 'time_us': data.get('time_us')})
            parsed = True
    except Exception as e:
        if VERBOSE:
            log(f"Failed to parse {event_type}: {e} - {line[:100]}")
    
    return parsed

def tail_file(path, from_start=False, follow=True):
    if not os.path.exists(path):
        if not follow:
            return
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, 'a').close()
    with open(path, "r", encoding='utf-8', errors='ignore') as f:
        if not from_start: f.seek(0, 2)
        partial_line = ""
        while True:
            line = f.readline()
            if not line:
                if not follow:
                    if partial_line: yield partial_line
                    return
                time.sleep(0.1); continue
            
            if line.endswith('\n'):
                yield partial_line + line
                partial_line = ""
            else:
                partial_line += line

event_counts = {}

def main():
    global VERBOSE, session_tracker, event_counts
    parser = argparse.ArgumentParser()
    parser.add_argument('--history', action='store_true')
    parser.add_argument('--follow', action='store_true')
    parser.add_argument('--verbose', '-v', action='store_true')
    parser.add_argument('--file', '-f', type=str)
    parser.add_argument('--reset', action='store_true')
    parser.add_argument('--reset-log', action='store_true')
    parser.add_argument('--data-dir', type=str)
    parser.add_argument('--log-path', type=str)
    parser.add_argument('--no-ws', '--no-live', dest='no_ws', action='store_true', help='Disable WebSocket server')
    args = parser.parse_args()
    
    log_file = args.file or args.log_path or LOG_FILE_PATH
    VERBOSE = args.verbose
    
    # Start WebSocket server for live dashboard updates
    if WS_AVAILABLE and not args.no_ws:
        ws_thread = threading.Thread(target=run_ws_server, daemon=True)
        ws_thread.start()
        time.sleep(0.1)
    
    if VERBOSE:
        print(f"[Parser] Log file: {log_file}")
        print(f"[Parser] Database: {DB_PATH}")
        print(f"[Parser] Mode: {'history' if args.history else 'tail'}{' + follow' if args.follow else ''}")
    
    conn = init_db()
    global session_tracker
    if args.reset_log and os.path.exists(log_file):
        if VERBOSE: print(f"[Parser] Truncating audit log...")
        with open(log_file, 'w') as f: f.truncate(0)
    if args.reset:
        if VERBOSE: print(f"[Parser] Resetting database...")
        conn = reset_db(conn)
    session_tracker = SessionTracker(conn)
    
    if VERBOSE:
        print(f"[Parser] Session ID: {session_tracker.current_session_id or 'will create on first event'}")
        print(f"[Parser] Starting parse...")
    
    from_start = args.history or args.file is not None
    count = 0
    last_report = 0
    try:
        for line in tail_file(log_file, from_start=from_start, follow=args.follow):
            if parse_line(conn, line):
                count += 1
                if count % 100 == 0:
                    conn.commit()
                    if VERBOSE and count - last_report >= 500:
                        print(f"[Parser] Parsed {count} events...")
                        last_report = count
    except KeyboardInterrupt:
        if VERBOSE: print(f"\n[Parser] Interrupted")
    finally:
        conn.commit()
        try:
            conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        except (sqlite3.OperationalError, KeyboardInterrupt):
            pass
        conn.close()
        
        if VERBOSE or count > 0:
            print(f"[Parser] Done. Parsed {count} events total.")
            if event_counts:
                print(f"[Parser] Event breakdown:")
                for evt, cnt in sorted(event_counts.items(), key=lambda x: -x[1]):
                    print(f"  {evt}: {cnt}")

if __name__ == "__main__": main()
