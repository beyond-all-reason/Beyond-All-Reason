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

# WebSocket for real-time push to dashboard
try:
    import websockets
    from websockets.sync.client import connect as ws_connect
    WS_AVAILABLE = True
except ImportError:
    WS_AVAILABLE = False
    print("Warning: websockets not installed. Live dashboard updates disabled.")
    print("Install with: pip install websockets")

WS_PORT = 8765
ws_client = None


def get_state_dir():
    """Get the XDG state directory for economy audit data."""
    system = platform.system()
    if system == 'Windows':
        base = os.environ.get('LOCALAPPDATA', os.path.expanduser('~\\AppData\\Local'))
        state_dir = os.path.join(base, 'economy_audit')
    elif system == 'Darwin':
        state_dir = os.path.expanduser('~/Library/Application Support/economy_audit')
    else:
        state_home = os.environ.get('XDG_STATE_HOME', os.path.join(os.path.expanduser("~"), '.local', 'state'))
        state_dir = os.path.join(state_home, 'economy_audit')
    
    os.makedirs(state_dir, exist_ok=True)
    return state_dir


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
LOG_FILE_PATH = os.path.join(BAR_DATA_DIR, 'infolog.txt')
STATE_DIR = get_state_dir()
DB_PATH = os.path.join(STATE_DIR, "audit_logs.db")
VERBOSE = False

def log(msg):
    if VERBOSE: print(f"[DEBUG] {msg}")

def broadcast_event(event_type, data):
    global ws_client
    if not WS_AVAILABLE: return
    try:
        if ws_client is None: ws_client = ws_connect(f"ws://localhost:{WS_PORT}")
        message = json.dumps({'type': event_type, 'data': data})
        ws_client.send(message)
    except Exception as e:
        ws_client = None
        if VERBOSE: log(f"WebSocket broadcast failed: {e}")

def init_db():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    c = conn.cursor()
    c.execute("PRAGMA journal_mode=WAL;")
    
    c.execute('''CREATE TABLE IF NOT EXISTS game_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_timestamp TEXT, end_timestamp TEXT,
        start_frame INTEGER, end_frame INTEGER,
        team_count INTEGER, duration_frames INTEGER
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
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_waterfill (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, team_id INTEGER NOT NULL, ally_team INTEGER NOT NULL,
        resource TEXT NOT NULL, current REAL NOT NULL, target REAL NOT NULL,
        role TEXT NOT NULL, delta REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS eco_storage_capped (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL, frame INTEGER NOT NULL, game_time REAL NOT NULL,
        source_path TEXT NOT NULL, team_id INTEGER NOT NULL, resource TEXT NOT NULL,
        current REAL NOT NULL, storage REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS team_names (
        id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL,
        team_id INTEGER NOT NULL, name TEXT NOT NULL, is_ai INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id),
        UNIQUE(session_id, team_id)
    )''')
    conn.commit()
    return conn

def reset_db(conn):
    c = conn.cursor()
    tables = ['solver_audit', 'eco_team_input', 'eco_team_output', 'eco_group_lift', 'eco_frame_start', 'eco_transfer', 'eco_team_waterfill', 'eco_storage_capped', 'team_names', 'game_sessions']
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
        self._load_or_create_session()
    def _load_or_create_session(self):
        c = self.conn.cursor()
        c.execute("SELECT id, end_frame FROM game_sessions ORDER BY id DESC LIMIT 1")
        row = c.fetchone()
        if row:
            self.current_session_id = row[0]
            self.last_frame = row[1] or 0
        else: self._start_new_session(None, 0, None)
    def _start_new_session(self, timestamp, frame, team_count):
        c = self.conn.cursor()
        c.execute('INSERT INTO game_sessions (start_timestamp, start_frame, team_count) VALUES (?, ?, ?)', (timestamp, frame, team_count))
        self.conn.commit()
        self.current_session_id = c.lastrowid
        self.session_start_timestamp = timestamp
        self.session_start_frame = frame
        self.session_team_count = team_count
        self.last_frame = frame
        print(f"[SessionTracker] Started new session #{self.current_session_id} at frame {frame}")
    def _end_current_session(self, timestamp, frame):
        if self.current_session_id:
            c = self.conn.cursor()
            duration = frame - (self.session_start_frame or 0)
            c.execute('UPDATE game_sessions SET end_timestamp = ?, end_frame = ?, duration_frames = ? WHERE id = ?', (timestamp, frame, duration, self.current_session_id))
            self.conn.commit()
    def check_frame(self, timestamp, frame, team_count=None):
        if frame < self.last_frame - 1000:
            self._end_current_session(timestamp, self.last_frame)
            self._start_new_session(timestamp, frame, team_count)
        self.last_frame = max(self.last_frame, frame)
        if team_count and team_count != self.session_team_count:
            self.session_team_count = team_count
            c = self.conn.cursor()
            c.execute("UPDATE game_sessions SET team_count = ? WHERE id = ?", (team_count, self.current_session_id))
        return self.current_session_id

session_tracker = None

def parse_line(conn, line):
    global session_tracker
    match = re.search(r'\[t=(.*?)\]\[f=(-?\d+)\] \[(.*?)\] (.*)', line)
    if not match: return False
    timestamp_str, frame, subsystem, content = match.groups()
    frame = int(frame)
    session_id = session_tracker.check_frame(timestamp_str, frame) if session_tracker else None
    c = conn.cursor()
    parsed = False

    if subsystem == "SolverAudit":
        parts = content.split()
        data = {}
        for part in parts:
            if '=' in part:
                k, v = part.split('=', 1)
                data[k] = v
        source_path, metric = data.get('source_path'), data.get('metric')
        time_us = float(data.get('time_us', 0))
        c.execute("INSERT INTO solver_audit (session_id, timestamp, frame, game_time, source_path, metric, time_us) VALUES (?, ?, ?, ?, ?, ?, ?)", (session_id, timestamp_str, frame, frame/30.0, source_path, metric, time_us))
        broadcast_event('solver_audit', {'frame': frame, 'source_path': source_path, 'metric': metric, 'time_us': time_us})
        parsed = True

    elif subsystem == "EconomyAudit":
        try:
            event_type, json_str = content.split(' ', 1)
            data = json.loads(json_str)
            team_count = data.get('team_count')
            if team_count and session_tracker: session_tracker.check_frame(timestamp_str, frame, team_count)
            game_time = data.get('game_time') or (frame / 30.0)
            source_path = data.get('source_path', "UNKNOWN")

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
                c.execute('INSERT INTO eco_transfer (session_id, timestamp, frame, game_time, source_path, sender_team_id, receiver_team_id, resource, amount, untaxed, taxed) VALUES (?,?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('sender_team_id'), data.get('receiver_team_id'), data.get('resource'), data.get('amount'), data.get('untaxed'), data.get('taxed')))
                parsed = True
            elif event_type == "team_waterfill":
                c.execute('INSERT INTO eco_team_waterfill (session_id, timestamp, frame, game_time, source_path, team_id, ally_team, resource, current, target, role, delta) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('team_id'), data.get('ally_team'), data.get('resource'), data.get('current', 0), data.get('target', 0), data.get('role', 'unknown'), data.get('delta', 0)))
                parsed = True
            elif event_type == "storage_capped":
                c.execute('INSERT INTO eco_storage_capped (session_id, timestamp, frame, game_time, source_path, team_id, resource, current, storage) VALUES (?,?,?,?,?,?,?,?,?)', (session_id, timestamp_str, frame, game_time, source_path, data.get('team_id'), data.get('resource'), data.get('current'), data.get('storage')))
                parsed = True
            elif event_type == "team_info":
                c.execute('INSERT OR REPLACE INTO team_names (session_id, team_id, name, is_ai) VALUES (?, ?, ?, ?)', (session_id, data.get('team_id'), data.get('name'), 1 if data.get('is_ai') else 0))
                parsed = True
        except Exception as e:
            print(f"[ERROR] Failed to parse EconomyAudit: {e}")
            print(f"  Line: {line.strip()[:200]}")
    return parsed

def tail_file(path, from_start=False, follow=True):
    if not os.path.exists(path): return
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

def main():
    global VERBOSE, session_tracker
    parser = argparse.ArgumentParser()
    parser.add_argument('--history', action='store_true')
    parser.add_argument('--follow', action='store_true')
    parser.add_argument('--verbose', '-v', action='store_true')
    parser.add_argument('--file', '-f', type=str)
    parser.add_argument('--reset', action='store_true')
    parser.add_argument('--reset-infolog', action='store_true')
    parser.add_argument('--data-dir', type=str)
    parser.add_argument('--log-path', type=str)
    args = parser.parse_args()
    
    log_file = args.file or args.log_path or LOG_FILE_PATH
    VERBOSE = args.verbose
    conn = init_db()
    if args.reset_infolog and os.path.exists(log_file):
        with open(log_file, 'w') as f: f.truncate(0)
    if args.reset: conn = reset_db(conn)
    session_tracker = SessionTracker(conn)
    
    from_start = args.history or args.file is not None
    count = 0
    try:
        for line in tail_file(log_file, from_start=from_start, follow=args.follow):
            if parse_line(conn, line):
                count += 1
                if count % 100 == 0: conn.commit()
    except KeyboardInterrupt: pass
    finally:
        conn.commit()
        try:
            # PASSIVE won't block if dashboard has db open (unlike TRUNCATE)
            conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        except (sqlite3.OperationalError, KeyboardInterrupt):
            pass
        conn.close()

if __name__ == "__main__": main()
