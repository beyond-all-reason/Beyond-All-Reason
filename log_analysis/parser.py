import re
import sqlite3
import json
import time
import os
import sys
import argparse
from datetime import datetime

# Configuration
# WSL path to the log file.
# Using the user provided path logic: /mnt/c/Users/<User>/AppData/Local/Programs/Beyond-All-Reason/data/infolog.txt
WIN_USER = 'Daniel' 
LOG_FILE_PATH = f"/mnt/c/Users/{WIN_USER}/AppData/Local/Programs/Beyond-All-Reason/data/infolog.txt"
DB_PATH = "audit_logs.db"

# Global verbose flag
VERBOSE = False

def log(msg):
    """Print if verbose mode is enabled."""
    if VERBOSE:
        print(f"[DEBUG] {msg}")

def init_db():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    c = conn.cursor()
    
    # Enable WAL mode to prevent locking issues with concurrent reads (Jupyter)
    c.execute("PRAGMA journal_mode=WAL;")
    log("Enabled WAL mode for database")
    
    # Game Sessions Table - tracks distinct game runs
    c.execute('''CREATE TABLE IF NOT EXISTS game_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_timestamp TEXT,
        end_timestamp TEXT,
        start_frame INTEGER,
        end_frame INTEGER,
        team_count INTEGER,
        duration_frames INTEGER
    )''')
    
    # Solver Audit Table
    c.execute('''CREATE TABLE IF NOT EXISTS solver_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        metric TEXT,
        time_us REAL,
        teams TEXT,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')

    # Economy Audit Tables - all include session_id for multi-game support
    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_input (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        team_id INTEGER,
        current REAL,
        resource TEXT,
        cumulative_sent REAL,
        share_slider REAL,
        storage REAL,
        ally_team INTEGER,
        share_cursor REAL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')

    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_output (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        team_id INTEGER,
        current REAL,
        resource TEXT,
        received REAL,
        sent REAL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')

    c.execute('''CREATE TABLE IF NOT EXISTS eco_group_lift (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        member_count INTEGER,
        resource TEXT,
        lift REAL,
        total_demand REAL,
        total_supply REAL,
        ally_team INTEGER,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS eco_frame_start (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        tax_rate REAL,
        metal_threshold REAL,
        energy_threshold REAL,
        team_count INTEGER,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')

    c.execute('''CREATE TABLE IF NOT EXISTS eco_transfer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        sender_team_id INTEGER,
        receiver_team_id INTEGER,
        resource TEXT,
        amount REAL,
        untaxed REAL,
        taxed REAL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')

    c.execute('''CREATE TABLE IF NOT EXISTS eco_team_waterfill (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        timestamp TEXT,
        frame INTEGER,
        team_id INTEGER,
        ally_team INTEGER,
        resource TEXT,
        current REAL,
        target REAL,
        role TEXT,
        delta REAL,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
    )''')

    conn.commit()
    return conn

def reset_db(conn):
    """Drop all tables to start fresh."""
    c = conn.cursor()
    tables = ['solver_audit', 'eco_team_input', 'eco_team_output', 'eco_group_lift', 'eco_frame_start', 'eco_transfer', 'eco_team_waterfill', 'game_sessions']
    for table in tables:
        c.execute(f"DROP TABLE IF EXISTS {table}")
        log(f"Dropped table: {table}")
    conn.commit()
    print("Database reset complete. All tables dropped.")

# Session tracking state
class SessionTracker:
    """Tracks game sessions by detecting frame resets."""
    
    def __init__(self, conn):
        self.conn = conn
        self.current_session_id = None
        self.last_frame = -1
        self.session_start_timestamp = None
        self.session_start_frame = None
        self.session_team_count = None
        self._load_or_create_session()
    
    def _load_or_create_session(self):
        """Load the most recent session or create a new one."""
        c = self.conn.cursor()
        c.execute("SELECT id, end_frame FROM game_sessions ORDER BY id DESC LIMIT 1")
        row = c.fetchone()
        if row:
            self.current_session_id = row[0]
            self.last_frame = row[1] or 0
            log(f"Resuming session {self.current_session_id}, last frame {self.last_frame}")
        else:
            self._start_new_session(None, 0, None)
    
    def _start_new_session(self, timestamp, frame, team_count):
        """Start a new game session."""
        c = self.conn.cursor()
        c.execute('''INSERT INTO game_sessions (start_timestamp, start_frame, team_count)
                     VALUES (?, ?, ?)''', (timestamp, frame, team_count))
        self.conn.commit()
        self.current_session_id = c.lastrowid
        self.session_start_timestamp = timestamp
        self.session_start_frame = frame
        self.session_team_count = team_count
        self.last_frame = frame
        print(f"[SessionTracker] Started new session #{self.current_session_id} at frame {frame}")
    
    def _end_current_session(self, timestamp, frame):
        """Finalize the current session."""
        if self.current_session_id:
            c = self.conn.cursor()
            duration = frame - (self.session_start_frame or 0)
            c.execute('''UPDATE game_sessions 
                         SET end_timestamp = ?, end_frame = ?, duration_frames = ?
                         WHERE id = ?''',
                      (timestamp, frame, duration, self.current_session_id))
            self.conn.commit()
            log(f"Ended session {self.current_session_id} at frame {frame}")
    
    def check_frame(self, timestamp, frame, team_count=None):
        """Check if this frame indicates a new session and return the current session_id."""
        # Detect session boundary: frame resets to a much lower value
        # (e.g., going from frame 50000 to frame 0 means new game)
        if frame < self.last_frame - 1000:  # Allow some tolerance for out-of-order logs
            log(f"Frame reset detected: {self.last_frame} -> {frame}")
            self._end_current_session(timestamp, self.last_frame)
            self._start_new_session(timestamp, frame, team_count)
        
        self.last_frame = max(self.last_frame, frame)
        
        # Update team count if provided and different
        if team_count and team_count != self.session_team_count:
            self.session_team_count = team_count
            c = self.conn.cursor()
            c.execute("UPDATE game_sessions SET team_count = ? WHERE id = ?",
                      (team_count, self.current_session_id))
        
        return self.current_session_id

# Global session tracker (initialized in main)
session_tracker = None

def parse_line(conn, line):
    global session_tracker
    
    # Basic log format: [t=00:04:42.811145][f=0001950] [EconomyAudit] ...
    # Regex to extract timestamp, frame, subsystem, and content
    match = re.search(r'\[t=(.*?)\]\[f=(\d+)\] \[(.*?)\] (.*)', line)
    if not match:
        return False  # Return False if line wasn't parsed

    timestamp_str = match.group(1)
    frame = int(match.group(2))
    subsystem = match.group(3)
    content = match.group(4)
    
    # Get session_id (may trigger new session detection)
    session_id = session_tracker.check_frame(timestamp_str, frame) if session_tracker else None

    c = conn.cursor()
    parsed = False

    if subsystem == "SolverAudit":
        # Format: metric=PreMunge time_us=0.00
        # Optional: teams=0
        parts = content.split()
        data = {}
        for part in parts:
            if '=' in part:
                k, v = part.split('=', 1)
                data[k] = v
        
        metric = data.get('metric')
        time_us = float(data.get('time_us', 0))
        teams = data.get('teams') # Optional
        
        c.execute("INSERT INTO solver_audit (session_id, timestamp, frame, metric, time_us, teams) VALUES (?, ?, ?, ?, ?, ?)",
                  (session_id, timestamp_str, frame, metric, time_us, teams))
        log(f"Inserted SolverAudit: session={session_id} frame={frame} metric={metric}")
        parsed = True

    elif subsystem == "EconomyAudit":
        # Format: event_type {"json": "data"}
        # Expecting: team_input {...}
        try:
            event_type, json_str = content.split(' ', 1)
            data = json.loads(json_str)
            
            # Update session team count from frame_start events
            team_count = data.get('team_count')
            if team_count and session_tracker:
                session_tracker.check_frame(timestamp_str, frame, team_count)
            
            if event_type == "team_input":
                c.execute('''INSERT INTO eco_team_input 
                             (session_id, timestamp, frame, team_id, current, resource, cumulative_sent, share_slider, storage, ally_team, share_cursor)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                          (session_id, timestamp_str, frame, data.get('team_id'), data.get('current'), data.get('resource'),
                           data.get('cumulative_sent'), data.get('share_slider'), data.get('storage'), data.get('ally_team'),
                           data.get('share_cursor')))
                log(f"Inserted EconomyAudit team_input: session={session_id} frame={frame} team={data.get('team_id')}")
                parsed = True
            
            elif event_type == "team_output":
                c.execute('''INSERT INTO eco_team_output
                             (session_id, timestamp, frame, team_id, current, resource, received, sent)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
                          (session_id, timestamp_str, frame, data.get('team_id'), data.get('current'), data.get('resource'),
                           data.get('received'), data.get('sent')))
                log(f"Inserted EconomyAudit team_output: session={session_id} frame={frame} team={data.get('team_id')}")
                parsed = True

            elif event_type == "group_lift":
                c.execute('''INSERT INTO eco_group_lift
                             (session_id, timestamp, frame, member_count, resource, lift, total_demand, total_supply, ally_team)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                          (session_id, timestamp_str, frame, data.get('member_count'), data.get('resource'), data.get('lift'),
                           data.get('total_demand'), data.get('total_supply'), data.get('ally_team')))
                log(f"Inserted EconomyAudit group_lift: session={session_id} frame={frame}")
                parsed = True

            elif event_type == "frame_start":
                c.execute('''INSERT INTO eco_frame_start
                             (session_id, timestamp, frame, tax_rate, metal_threshold, energy_threshold, team_count)
                             VALUES (?, ?, ?, ?, ?, ?, ?)''',
                          (session_id, timestamp_str, frame, data.get('tax_rate'), data.get('metal_threshold'),
                           data.get('energy_threshold'), data.get('team_count')))
                log(f"Inserted EconomyAudit frame_start: session={session_id} frame={frame}")
                parsed = True

            elif event_type == "transfer":
                c.execute('''INSERT INTO eco_transfer
                             (session_id, timestamp, frame, sender_team_id, receiver_team_id, resource, amount, untaxed, taxed)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                          (session_id, timestamp_str, frame, data.get('sender_team_id'), data.get('receiver_team_id'),
                           data.get('resource'), data.get('amount'), data.get('untaxed'), data.get('taxed')))
                log(f"Inserted EconomyAudit transfer: session={session_id} frame={frame} {data.get('sender_team_id')}->{data.get('receiver_team_id')}")
                parsed = True

            elif event_type == "team_waterfill":
                c.execute('''INSERT INTO eco_team_waterfill
                             (session_id, timestamp, frame, team_id, ally_team, resource, current, target, role, delta)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                          (session_id, timestamp_str, frame, data.get('team_id'), data.get('ally_team'),
                           data.get('resource'), data.get('current'), data.get('target'),
                           data.get('role'), data.get('delta')))
                log(f"Inserted EconomyAudit team_waterfill: session={session_id} frame={frame} team={data.get('team_id')} role={data.get('role')}")
                parsed = True
                           
        except json.JSONDecodeError:
            print(f"Failed to decode JSON in line: {line}")
        except ValueError:
            print(f"Failed to split content in line: {line}")

    # Note: commit is now handled in batches by the caller
    return parsed

def tail_file(path, from_start=False):
    print(f"Opening log file: {path}")
    if not os.path.exists(path):
        print(f"Error: File not found at {path}")
        return

    with open(path, "r", encoding='utf-8', errors='ignore') as f:
        if not from_start:
            # Move to the end of file
            f.seek(0, 2)
            print("Seeking to end of file. Waiting for new log lines...")
        else:
            print("Reading from beginning of file...")
        
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.1)
                continue
            yield line

def main():
    global VERBOSE, session_tracker
    
    parser = argparse.ArgumentParser(description='Parse BAR infolog.txt audit logs into SQLite')
    parser.add_argument('--history', action='store_true', 
                        help='Parse existing log from the beginning instead of tailing')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Enable verbose debug output')
    parser.add_argument('--file', '-f', type=str, default=None,
                        help='Path to a specific log file to parse (reads entire file)')
    parser.add_argument('--reset', action='store_true',
                        help='Wipe all existing data before parsing')
    parser.add_argument('--new-session', action='store_true',
                        help='Force start a new game session')
    args = parser.parse_args()
    
    VERBOSE = args.verbose
    
    conn = init_db()
    log("Database initialized")
    
    # Handle reset flag
    if args.reset:
        reset_db(conn)
        # Recreate tables after dropping
        conn.close()
        conn = init_db()
    
    # Initialize session tracker
    session_tracker = SessionTracker(conn)
    
    # Force new session if requested
    if args.new_session:
        session_tracker._start_new_session(None, 0, None)
        print(f"Forced new session #{session_tracker.current_session_id}")
    
    # If a specific file is provided, read it completely
    if args.file:
        file_path = args.file
        print(f"Parsing file: {file_path}")
        count = 0
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                if parse_line(conn, line):
                    count += 1
                    if count % 100 == 0:
                        conn.commit()  # Batch commit every 100 records
        conn.commit()  # Final commit
        print(f"Finished parsing. Inserted {count} records.")
        # Checkpoint WAL to flush to main db file and release locks
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        conn.close()
        return

    print(f"Log file: {LOG_FILE_PATH}")
    print(f"DB Path: {os.path.abspath(DB_PATH)}")
    
    if args.history:
        print("=== HISTORY MODE: Parsing existing log from beginning ===")
    else:
        print("=== TAIL MODE: Waiting for new log lines ===")
        print("(Run with --history to parse existing log first)")
    
    try:
        count = 0
        for line in tail_file(LOG_FILE_PATH, from_start=args.history):
            if parse_line(conn, line):
                count += 1
                if count % 100 == 0:
                    conn.commit()  # Batch commit every 100 records
                    print(f"Processed {count} audit log entries...")
    except KeyboardInterrupt:
        print(f"\nStopping parser... Total records inserted: {count}")
    finally:
        conn.commit()  # Final commit
        # Checkpoint WAL to flush to main db file and release locks
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        conn.close()
        print("Database connection closed and WAL checkpointed.")

if __name__ == "__main__":
    main()
