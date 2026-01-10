#!/usr/bin/env python3
"""
BAR Economy Audit Dashboard
Real-time visualization of economy data using Dash + WebSocket (local)
Includes: Economy Overview, Timing Analysis, Waterfill Analysis
"""

import os
import json
import time
import sqlite3
import platform
import subprocess
import urllib.parse
import base64
import io
from pathlib import Path
from datetime import datetime

import dash
from dash import dcc, html, callback, Input, Output, State, dash_table
import dash_bootstrap_components as dbc
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np


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


# === Configuration ===
BAR_DATA_DIR = find_bar_data_dir()
DB_PATH = os.path.join(BAR_DATA_DIR, "economy_audit.db")
WS_PORT = 8765

# === Dark theme colors (Dracula-inspired) ===
COLORS = {
    'background': '#0d1117',
    'card': '#161b22',
    'card_lighter': '#1c2128',
    'border': '#30363d',
    'text': '#c9d1d9',
    'text_muted': '#8b949e',
    'accent': '#58a6ff',
    'metal': '#81a2be',
    'energy': '#f0c674',
    'green': '#a3be8c',
    'red': '#bf616a',
    'purple': '#b48ead',
    'orange': '#d08770',
    'cyan': '#88c0d0',
    'yellow': '#ebcb8b',
}

PLAYER_COLORS = [
    '#58a6ff', '#a3be8c', '#bf616a', '#b48ead', 
    '#d08770', '#88c0d0', '#ebcb8b', '#81a2be',
    '#f0c674', '#8fbcbb', '#5e81ac', '#e5c07b'
]

METRIC_COLORS = {
    'PreMunge': '#4FC3F7',
    'Solver': '#EF5350',
    'PostMunge': '#66BB6A',
    'PolicyCache': '#FFD54F',
    'CppSetters': '#AB47BC',
    'BuildTeamData': '#4FC3F7',
    'WaterfillSolver': '#EF5350',
    'ApplyResults': '#66BB6A',
}

SENDER_COLOR = '#EF5350'
RECEIVER_COLOR = '#66BB6A'
NEUTRAL_COLOR = '#78909C'
TAX_COLOR = '#AB47BC'

def get_player_color(player_id):
    return PLAYER_COLORS[player_id % len(PLAYER_COLORS)]


def fig_to_base64_png(fig, width=800, height=400):
    """Convert a Plotly figure to a base64-encoded PNG string for markdown embedding."""
    try:
        img_bytes = fig.to_image(format="png", width=width, height=height, scale=2)
        return base64.b64encode(img_bytes).decode('utf-8')
    except Exception as e:
        print(f"[Export] Failed to convert figure to PNG: {e}")
        return None


def embed_chart_in_markdown(fig, alt_text="Chart", width=800, height=400):
    """Generate markdown image syntax for an embedded chart (base64 data URI)."""
    b64 = fig_to_base64_png(fig, width, height)
    if b64:
        return f'![{alt_text}](data:image/png;base64,{b64})\n\n'
    return f'*({alt_text} could not be exported)*\n\n'


def dataframe_to_markdown_table(df, float_format='.2f'):
    """Convert a pandas DataFrame to a markdown table string."""
    if df.empty:
        return '*No data*\n\n'
    
    headers = '| ' + ' | '.join(str(col) for col in df.columns) + ' |\n'
    separator = '|' + '|'.join(['---' for _ in df.columns]) + '|\n'
    
    rows = ''
    for _, row in df.iterrows():
        cells = []
        for col in df.columns:
            val = row[col]
            if isinstance(val, float):
                cells.append(f'{val:{float_format}}')
            elif isinstance(val, (int, np.integer)):
                cells.append(f'{val:,}')
            else:
                cells.append(str(val))
        rows += '| ' + ' | '.join(cells) + ' |\n'
    
    return headers + separator + rows + '\n'


def get_team_display_name(team_id, names_dict):
    if names_dict:
        # Try both int and string keys (Dash store converts int keys to strings via JSON)
        if team_id in names_dict:
            return names_dict[team_id]
        if str(team_id) in names_dict:
            return names_dict[str(team_id)]
    return f"Player {team_id}"


def format_time_mmss(seconds):
    if pd.isna(seconds):
        return "0:00"
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f"{mins}:{secs:02d}"


def get_time_axis_config(game_times, colors):
    if len(game_times) == 0:
        return {}
    
    min_t, max_t = game_times.min(), game_times.max()
    duration = max_t - min_t
    
    if duration <= 60:
        step = 10
    elif duration <= 180:
        step = 30
    elif duration <= 600:
        step = 60
    else:
        step = 120
    
    tick_vals = np.arange(0, max_t + step, step)
    tick_text = [format_time_mmss(t) for t in tick_vals]
    
    return dict(
        tickmode='array',
        tickvals=tick_vals,
        ticktext=tick_text,
        gridcolor=colors['border'],
        zerolinecolor=colors['border']
    )


# === Database queries ===
def get_db_connection():
    if not os.path.exists(DB_PATH):
        return None
    
    # Use URI format with proper path escaping for spaces
    db_uri = f"{Path(os.path.abspath(DB_PATH)).as_uri()}?mode=ro"
    conn = sqlite3.connect(db_uri, uri=True, timeout=5)
    conn.row_factory = sqlite3.Row
    return conn


def load_sessions():
    conn = get_db_connection()
    if not conn:
        return []
    try:
        df = pd.read_sql_query(
            "SELECT id, start_timestamp, start_frame, end_frame, team_count, duration_frames, session_types FROM game_sessions ORDER BY id DESC",
            conn
        )
        return df.to_dict('records')
    finally:
        conn.close()


def load_team_names(session_id):
    conn = get_db_connection()
    if not conn:
        return {}
    try:
        if session_id == 'all':
            df = pd.read_sql_query(
                "SELECT team_id, name, is_ai FROM team_names",
                conn
            )
        else:
            df = pd.read_sql_query(
                "SELECT team_id, name, is_ai FROM team_names WHERE session_id = ?",
                conn, params=(session_id,)
            )
        return {row['team_id']: row['name'] for _, row in df.iterrows()}
    finally:
        conn.close()


def load_teams(session_id):
    conn = get_db_connection()
    if not conn:
        return []
    try:
        # Filter out Gaia team using team_names table
        if session_id == 'all':
            df = pd.read_sql_query(
                """SELECT DISTINCT t.team_id FROM eco_team_input t
                   LEFT JOIN team_names n ON t.team_id = n.team_id
                   WHERE n.is_gaia = 0 OR n.is_gaia IS NULL
                   ORDER BY t.team_id""",
                conn
            )
        else:
            df = pd.read_sql_query(
                """SELECT DISTINCT t.team_id FROM eco_team_input t
                   LEFT JOIN team_names n ON t.team_id = n.team_id AND n.session_id = ?
                   WHERE t.session_id = ? AND (n.is_gaia = 0 OR n.is_gaia IS NULL)
                   ORDER BY t.team_id""",
                conn, params=(session_id, session_id)
            )
        return df['team_id'].tolist()
    finally:
        conn.close()


def load_economy_data_multi(session_id, team_ids, resource, time_range=None, limit=5000):
    conn = get_db_connection()
    if not conn or not team_ids:
        return pd.DataFrame()
    try:
        # Debug: show frame range being queried
        if time_range:
            frame_start = int(time_range[0] * 60 * 30)
            frame_end = int(time_range[1] * 60 * 30)
            print(f"[load_economy_data_multi] time_range={time_range} -> frames [{frame_start}, {frame_end}]")
        
        placeholders = ','.join(['?' for _ in team_ids])
        if session_id == 'all':
            query = f"""SELECT o.frame, o.team_id, o.current, i.storage, o.source_path 
                       FROM eco_team_output o
                       JOIN eco_team_input i ON o.session_id = i.session_id 
                           AND o.frame = i.frame AND o.team_id = i.team_id AND o.resource = i.resource
                       WHERE o.team_id IN ({placeholders}) AND o.resource = ?"""
            params = list(team_ids) + [resource]
        else:
            query = f"""SELECT o.frame, o.team_id, o.current, i.storage, o.source_path 
                       FROM eco_team_output o
                       JOIN eco_team_input i ON o.session_id = i.session_id 
                           AND o.frame = i.frame AND o.team_id = i.team_id AND o.resource = i.resource
                       WHERE o.session_id = ? AND o.team_id IN ({placeholders}) AND o.resource = ?"""
            params = [session_id] + list(team_ids) + [resource]
        
        if time_range:
            query += " AND o.frame >= ? AND o.frame <= ?"
            params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
            
        # Limit per team to avoid cutting off data
        query += f" ORDER BY o.frame DESC LIMIT {limit * len(team_ids)}"
        
        df = pd.read_sql_query(query, conn, params=params)
        
        if df.empty:
            return pd.DataFrame()
        
        df = df.sort_values('frame')
        df['game_time'] = df['frame'] / 30.0
        return df
        
    finally:
        conn.close()


def load_transfers(session_id, resource, team_ids=None, time_range=None, limit=2000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        if session_id == 'all':
            query = "SELECT frame, game_time, sender_team_id, receiver_team_id, amount, untaxed, taxed FROM eco_transfer WHERE resource = ?"
            params = [resource]
        else:
            query = "SELECT frame, game_time, sender_team_id, receiver_team_id, amount, untaxed, taxed FROM eco_transfer WHERE session_id = ? AND resource = ?"
            params = [session_id, resource]
        
        if team_ids:
            placeholders = ','.join(['?' for _ in team_ids])
            query += f" AND (sender_team_id IN ({placeholders}) OR receiver_team_id IN ({placeholders}))"
            params.extend(list(team_ids) + list(team_ids))
            
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
            
        query += " ORDER BY frame DESC LIMIT ?"
        params.append(limit)
        
        df = pd.read_sql_query(query, conn, params=params)
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_transfers_ledger(session_id, resource=None, transfer_type=None, team_filter=None, 
                          search_term=None, time_range=None, page=0, page_size=50):
    """Load paginated transfer ledger with search and filtering.
    
    Combines two data sources:
    - Active transfers: eco_transfer table (explicit player-initiated transfers)
    - Passive distributions: eco_team_output table (waterfill sent/received per team)
    """
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame(), 0
    try:
        # Build active transfers query (eco_transfer)
        active_params = []
        active_where = ["1=1"]
        
        if session_id and session_id != 'all':
            active_where.append("t.session_id = ?")
            active_params.append(session_id)
        
        if resource:
            active_where.append("t.resource = ?")
            active_params.append(resource)
        
        if team_filter:
            active_where.append("(t.sender_team_id = ? OR t.receiver_team_id = ?)")
            active_params.extend([team_filter, team_filter])
        
        if time_range:
            active_where.append("t.frame >= ? AND t.frame <= ?")
            active_params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
        
        active_where_sql = " AND ".join(active_where)
        
        active_query = f"""
            SELECT t.frame, t.game_time, t.sender_team_id, t.receiver_team_id, 
                   t.resource, t.amount, t.untaxed, t.taxed, 
                   COALESCE(t.transfer_type, 'active') as transfer_type,
                   ns.name as sender_name, nr.name as receiver_name,
                   'transfer' as source_table
            FROM eco_transfer t
            LEFT JOIN team_names ns ON t.sender_team_id = ns.team_id AND t.session_id = ns.session_id
            LEFT JOIN team_names nr ON t.receiver_team_id = nr.team_id AND t.session_id = nr.session_id
            WHERE {active_where_sql}
        """
        
        if search_term:
            active_query += " AND (ns.name LIKE ? OR nr.name LIKE ? OR CAST(t.sender_team_id AS TEXT) LIKE ? OR CAST(t.receiver_team_id AS TEXT) LIKE ?)"
            search_pattern = f"%{search_term}%"
            active_params.extend([search_pattern] * 4)
        
        # Build passive distributions query (eco_team_output with sent > 0 or received > 0)
        passive_params = []
        passive_where = ["(o.sent > 0.01 OR o.received > 0.01)"]
        
        if session_id and session_id != 'all':
            passive_where.append("o.session_id = ?")
            passive_params.append(session_id)
        
        if resource:
            passive_where.append("o.resource = ?")
            passive_params.append(resource)
        
        if team_filter:
            passive_where.append("o.team_id = ?")
            passive_params.append(team_filter)
        
        if time_range:
            passive_where.append("o.frame >= ? AND o.frame <= ?")
            passive_params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
        
        passive_where_sql = " AND ".join(passive_where)
        
        passive_query = f"""
            SELECT o.frame, o.frame / 30.0 as game_time, o.team_id as sender_team_id, 
                   NULL as receiver_team_id, o.resource, o.sent as amount, 
                   o.received as untaxed, (o.sent - o.received) as taxed,
                   'passive' as transfer_type,
                   n.name as sender_name, NULL as receiver_name,
                   'output' as source_table
            FROM eco_team_output o
            LEFT JOIN team_names n ON o.team_id = n.team_id AND o.session_id = n.session_id
            WHERE {passive_where_sql}
        """
        
        if search_term:
            passive_query += " AND (n.name LIKE ? OR CAST(o.team_id AS TEXT) LIKE ?)"
            passive_params.extend([f"%{search_term}%"] * 2)
        
        # Filter by transfer type
        if transfer_type == 'active':
            # Only active transfers
            count_query = f"SELECT COUNT(*) FROM ({active_query}) sub"
            count_df = pd.read_sql_query(count_query, conn, params=active_params)
            total_count = count_df.iloc[0, 0] if not count_df.empty else 0
            
            data_query = f"{active_query} ORDER BY frame DESC LIMIT ? OFFSET ?"
            active_params.extend([page_size, page * page_size])
            df = pd.read_sql_query(data_query, conn, params=active_params)
            
        elif transfer_type == 'passive':
            # Only passive distributions
            count_query = f"SELECT COUNT(*) FROM ({passive_query}) sub"
            count_df = pd.read_sql_query(count_query, conn, params=passive_params)
            total_count = count_df.iloc[0, 0] if not count_df.empty else 0
            
            data_query = f"{passive_query} ORDER BY frame DESC LIMIT ? OFFSET ?"
            passive_params.extend([page_size, page * page_size])
            df = pd.read_sql_query(data_query, conn, params=passive_params)
            
        else:
            # Both types - union
            union_query = f"SELECT * FROM ({active_query} UNION ALL {passive_query}) combined"
            all_params = active_params + passive_params
            
            count_query = f"SELECT COUNT(*) FROM ({union_query}) sub"
            count_df = pd.read_sql_query(count_query, conn, params=all_params)
            total_count = count_df.iloc[0, 0] if not count_df.empty else 0
            
            data_query = f"{union_query} ORDER BY frame DESC LIMIT ? OFFSET ?"
            all_params.extend([page_size, page * page_size])
            df = pd.read_sql_query(data_query, conn, params=all_params)
        
        return df, total_count
    except Exception as e:
        print(f"[load_transfers_ledger] Error: {e}")
        import traceback
        traceback.print_exc()
        return pd.DataFrame(), 0
    finally:
        conn.close()


def load_group_lift_data(session_id, resource, ally_team=None, time_range=None, limit=1000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        params = []
        if ally_team is None or ally_team == 'all':
            # Aggregate across all alliances for the session
            query = """
                SELECT frame, game_time, 
                       SUM(member_count) as member_count, 
                       AVG(lift) as lift, 
                       SUM(total_demand) as total_demand, 
                       SUM(total_supply) as total_supply 
                FROM eco_group_lift 
                WHERE 1=1
            """
        else:
            query = """
                SELECT frame, game_time, member_count, lift, total_demand, total_supply 
                FROM eco_group_lift 
                WHERE ally_team = ?
            """
            params.append(ally_team)
            
        if session_id != 'all':
            query += " AND session_id = ?"
            params.append(session_id)
        
        query += " AND resource = ?"
        params.append(resource)
        
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
            
        if ally_team is None or ally_team == 'all':
            query += " GROUP BY frame, game_time"
            
        query += " ORDER BY frame DESC LIMIT ?"
        params.append(limit)
        
        df = pd.read_sql_query(query, conn, params=params)
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_solver_timing_summary(session_id=None, time_range=None):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        query = """
            SELECT source_path, metric, COUNT(*) as count, 
                   AVG(time_us) as avg_us, 
                   MIN(time_us) as min_us,
                   MAX(time_us) as max_us,
                   MIN(frame) as first_frame,
                   MAX(frame) as last_frame
            FROM solver_audit
            WHERE 1=1
        """
        params = []
        if session_id:
            query += " AND session_id = ?"
            params.append(session_id)
            
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
            
        query += " GROUP BY source_path, metric ORDER BY source_path, avg_us DESC"
        
        df = pd.read_sql_query(query, conn, params=params)
        return df
    finally:
        conn.close()


def load_solver_timing_data(session_id=None, time_range=None, limit=5000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        query = "SELECT frame, source_path, metric, time_us FROM solver_audit WHERE 1=1"
        params = []
        
        if session_id:
            query += " AND session_id = ?"
            params.append(session_id)
            
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([int(time_range[0] * 60 * 30), int(time_range[1] * 60 * 30)])
        elif not session_id:
            # For "All Sessions", limit to recent frames if no range specified
            query += " AND frame > (SELECT MAX(frame) FROM solver_audit) - ?"
            params.append(limit)
            
        query += " ORDER BY frame"
        
        df = pd.read_sql_query(query, conn, params=params)
        return df
    finally:
        conn.close()


def load_waterfill_data(session_id, frame, resource, ally_team=None):
    """Load waterfill data for a specific frame. ally_team=None means all alliances. Filters out Gaia team."""
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
    try:
        if ally_team is None:
            wf = pd.read_sql_query("""
                SELECT w.* FROM eco_team_waterfill w
                LEFT JOIN team_names n ON w.team_id = n.team_id AND w.session_id = n.session_id
                WHERE w.session_id = ? AND w.frame = ? AND w.resource = ?
                  AND (n.is_gaia = 0 OR n.is_gaia IS NULL)
                ORDER BY w.ally_team, w.team_id
            """, conn, params=(session_id, frame, resource))
            
            inp = pd.read_sql_query("""
                SELECT i.team_id, i.storage, i.share_cursor, i.ally_team FROM eco_team_input i
                LEFT JOIN team_names n ON i.team_id = n.team_id AND i.session_id = n.session_id
                WHERE i.session_id = ? AND i.frame = ? AND i.resource = ?
                  AND (n.is_gaia = 0 OR n.is_gaia IS NULL)
                ORDER BY i.team_id
            """, conn, params=(session_id, frame, resource))
            
            lift_df = pd.read_sql_query("""
                SELECT lift, total_supply, total_demand, ally_team FROM eco_group_lift
                WHERE session_id = ? AND frame = ? AND resource = ?
                ORDER BY ally_team
            """, conn, params=(session_id, frame, resource))
        else:
            wf = pd.read_sql_query("""
                SELECT w.* FROM eco_team_waterfill w
                LEFT JOIN team_names n ON w.team_id = n.team_id AND w.session_id = n.session_id
                WHERE w.session_id = ? AND w.frame = ? AND w.resource = ? AND w.ally_team = ?
                  AND (n.is_gaia = 0 OR n.is_gaia IS NULL)
                ORDER BY w.team_id
            """, conn, params=(session_id, frame, resource, ally_team))
            
            inp = pd.read_sql_query("""
                SELECT i.team_id, i.storage, i.share_cursor FROM eco_team_input i
                LEFT JOIN team_names n ON i.team_id = n.team_id AND i.session_id = n.session_id
                WHERE i.session_id = ? AND i.frame = ? AND i.resource = ? AND i.ally_team = ?
                  AND (n.is_gaia = 0 OR n.is_gaia IS NULL)
                ORDER BY i.team_id
            """, conn, params=(session_id, frame, resource, ally_team))
            
            lift_df = pd.read_sql_query("""
                SELECT lift, total_supply, total_demand FROM eco_group_lift
                WHERE session_id = ? AND frame = ? AND resource = ? AND ally_team = ?
            """, conn, params=(session_id, frame, resource, ally_team))
        
        return wf, inp, lift_df
    finally:
        conn.close()


def load_output_data(session_id, resource, time_range=None, limit=2000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        query = """SELECT o.frame, o.resource, o.team_id, o.sent, o.received 
                   FROM eco_team_output o
                   LEFT JOIN team_names n ON o.team_id = n.team_id AND o.session_id = n.session_id
                   WHERE o.session_id = ? AND o.resource = ?
                     AND (n.is_gaia = 0 OR n.is_gaia IS NULL)"""
        params = [session_id, resource]
        
        if time_range:
            query += " AND o.frame >= ? AND o.frame <= ?"
            params.extend([time_range[0] * 60 * 30, time_range[1] * 60 * 30])
            
        query += " ORDER BY o.frame DESC LIMIT ?"
        params.append(limit)
        
        df = pd.read_sql_query(query, conn, params=params)
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_conservation_check(session_id, limit=1000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        df = pd.read_sql_query(f"""
            SELECT o.frame, o.resource, 
                   SUM(o.sent) as total_sent, 
                   SUM(o.received) as total_received
            FROM eco_team_output o
            LEFT JOIN team_names n ON o.team_id = n.team_id AND o.session_id = n.session_id
            WHERE o.session_id = ?
              AND (n.is_gaia = 0 OR n.is_gaia IS NULL)
            GROUP BY o.frame, o.resource
            ORDER BY o.frame DESC LIMIT ?
        """, conn, params=(session_id, limit))
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_ally_teams(session_id):
    """Load available ally teams, preferring team_names but falling back to eco_team_input."""
    conn = get_db_connection()
    if not conn:
        return []
    try:
        # Try team_names first (has is_gaia flag)
        if session_id == 'all':
            df = pd.read_sql_query("""
                SELECT DISTINCT ally_team 
                FROM team_names 
                WHERE is_gaia = 0
                ORDER BY ally_team
            """, conn)
        else:
            df = pd.read_sql_query("""
                SELECT DISTINCT ally_team 
                FROM team_names 
                WHERE session_id = ? AND is_gaia = 0
                ORDER BY ally_team
            """, conn, params=(session_id,))
        
        if not df.empty:
            return df['ally_team'].tolist()
        
        # Fallback: extract from eco_team_input (exclude single-member alliances as likely Gaia)
        if session_id == 'all':
            df = pd.read_sql_query("""
                SELECT ally_team, COUNT(DISTINCT team_id) as member_count
                FROM eco_team_input
                GROUP BY ally_team
                HAVING member_count > 1
                ORDER BY ally_team
            """, conn)
        else:
            df = pd.read_sql_query("""
                SELECT ally_team, COUNT(DISTINCT team_id) as member_count
                FROM eco_team_input
                WHERE session_id = ?
                GROUP BY ally_team
                HAVING member_count > 1
                ORDER BY ally_team
            """, conn, params=(session_id,))
        
        return df['ally_team'].tolist() if not df.empty else []
    finally:
        conn.close()


SLOW_UPDATE_RATE = 30  # SlowUpdate happens every 30 game frames

def load_waterfill_frame_range(session_id, resource='metal', ally_team=None):
    """Load min/max frames and generate frame list analytically (every 30 frames).
    ally_team=None means all alliances."""
    conn = get_db_connection()
    if not conn:
        return []
    try:
        if ally_team is None:
            # All alliances
            if session_id == 'all':
                df = pd.read_sql_query("""
                    SELECT MIN(frame) as min_f, MAX(frame) as max_f FROM eco_team_waterfill 
                    WHERE resource = ?
                """, conn, params=(resource,))
            else:
                df = pd.read_sql_query("""
                    SELECT MIN(frame) as min_f, MAX(frame) as max_f FROM eco_team_waterfill 
                    WHERE session_id = ? AND resource = ?
                """, conn, params=(session_id, resource))
        else:
            # Specific alliance
            if session_id == 'all':
                df = pd.read_sql_query("""
                    SELECT MIN(frame) as min_f, MAX(frame) as max_f FROM eco_team_waterfill 
                    WHERE resource = ? AND ally_team = ?
                """, conn, params=(resource, ally_team))
            else:
                df = pd.read_sql_query("""
                    SELECT MIN(frame) as min_f, MAX(frame) as max_f FROM eco_team_waterfill 
                    WHERE session_id = ? AND resource = ? AND ally_team = ?
                """, conn, params=(session_id, resource, ally_team))
        
        if df.empty or pd.isna(df['min_f'].iloc[0]):
            return []
        
        min_f = int(df['min_f'].iloc[0])
        max_f = int(df['max_f'].iloc[0])
        return list(range(min_f, max_f + 1, SLOW_UPDATE_RATE))
    finally:
        conn.close()


def load_available_frames(session_id):
    conn = get_db_connection()
    if not conn:
        return []
    try:
        if session_id == 'all':
            df = pd.read_sql_query("""
                SELECT DISTINCT frame FROM eco_team_input 
                ORDER BY frame
            """, conn)
        else:
            df = pd.read_sql_query("""
                SELECT DISTINCT frame FROM eco_team_input 
                WHERE session_id = ?
                ORDER BY frame
            """, conn, params=(session_id,))
        return df['frame'].tolist() if not df.empty else []
    finally:
        conn.close()


def load_transfer_matrix(session_id, frame, resource):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        df = pd.read_sql_query("""
            SELECT t.sender_team_id, t.receiver_team_id, SUM(t.amount) as total_amount
            FROM eco_transfer t
            LEFT JOIN team_names ns ON t.sender_team_id = ns.team_id AND t.session_id = ns.session_id
            LEFT JOIN team_names nr ON t.receiver_team_id = nr.team_id AND t.session_id = nr.session_id
            WHERE t.session_id = ? AND t.frame = ? AND t.resource = ?
              AND (ns.is_gaia = 0 OR ns.is_gaia IS NULL)
              AND (nr.is_gaia = 0 OR nr.is_gaia IS NULL)
            GROUP BY t.sender_team_id, t.receiver_team_id
        """, conn, params=(session_id, frame, resource))
        return df
    finally:
        conn.close()


# === Chart builders ===
def create_empty_fig(message, colors, chart_id='empty'):
    fig = go.Figure()
    fig.add_annotation(
        text=message,
        xref="paper", yref="paper",
        x=0.5, y=0.5, showarrow=False,
        font=dict(size=14, color=colors['text_muted'])
    )
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        margin=dict(l=50, r=20, t=50, b=40),
        uirevision=chart_id,

    )
    return fig


def create_resource_levels_chart(df, team_ids, team_names, resource, colors):
    if df.empty:
        return create_empty_fig("Select players to view resource levels", colors, 'resource-chart')
    
    fig = go.Figure()
    resource_color = colors['metal'] if resource == 'metal' else colors['energy']
    
    for team_id in team_ids:
        team_df = df[df['team_id'] == team_id]
        if team_df.empty:
            continue
            
        team_name = get_team_display_name(team_id, team_names)
        color = get_player_color(team_id)
        
        fig.add_trace(go.Scatter(
            x=team_df['game_time'], y=team_df['current'],
            mode='lines', name=f'{team_name}',
            line=dict(color=color, width=2),
            hovertemplate=f'{team_name}: %{{y:.0f}}<extra>Current</extra>'
        ))
        
        fig.add_trace(go.Scatter(
            x=team_df['game_time'], y=team_df['storage'],
            mode='lines', name=f'{team_name} Cap',
            line=dict(color=color, width=2, dash='dot'),
            opacity=0.5,
            hovertemplate=f'{team_name}: %{{y:.0f}}<extra>Storage</extra>',
            showlegend=False
        ))
    
    x_axis_config = get_time_axis_config(df['game_time'], colors)
    
    title_suffix = "Selected Players" if len(team_ids) > 1 else get_team_display_name(team_ids[0], team_names)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        title=dict(text=f"📊 {resource.title()} Levels — {title_suffix}", font=dict(size=14)),
        uirevision='resource-chart',

        margin=dict(l=50, r=20, t=50, b=40),
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1, bgcolor='rgba(0,0,0,0)'),
        hovermode='x unified',
        xaxis=x_axis_config,
        yaxis=dict(gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_transfer_flow_chart(transfers_df, team_names, selected_teams, colors):
    if transfers_df.empty:
        return create_empty_fig("No transfer data", colors)
    
    fig = go.Figure()
    
    all_teams = set(transfers_df['sender_team_id'].unique()) | set(transfers_df['receiver_team_id'].unique())
    if selected_teams:
        all_teams = all_teams & set(selected_teams)
    
    if not all_teams:
        return create_empty_fig("No transfers for selected players", colors)
    
    transfers_df = transfers_df.copy()
    time_bins = pd.cut(transfers_df['game_time'], bins=50, labels=False)
    transfers_df['time_bin'] = time_bins
    bin_centers = transfers_df.groupby('time_bin')['game_time'].mean()
    
    for team_id in sorted(all_teams):
        sent = transfers_df[transfers_df['sender_team_id'] == team_id].groupby('time_bin')['amount'].sum()
        received = transfers_df[transfers_df['receiver_team_id'] == team_id].groupby('time_bin')['untaxed'].sum()
        
        net_flow = received.subtract(sent, fill_value=0)
        
        if not net_flow.empty:
            team_name = get_team_display_name(team_id, team_names)
            color = get_player_color(team_id)
            
            x_vals = [bin_centers.get(i, 0) for i in net_flow.index]
            fig.add_trace(go.Scatter(
                x=x_vals,
                y=net_flow.values,
                mode='lines',
                name=team_name,
                line=dict(color=color, width=2),
                hovertemplate=f'{team_name}<br>Net: %{{y:.0f}}<extra></extra>'
            ))
    
    fig.add_hline(y=0, line_dash="dash", line_color=colors['text_muted'], opacity=0.5)
    
    x_axis_config = get_time_axis_config(transfers_df['game_time'], colors)
    
    scope = "Selected Players" if selected_teams else "All Players"
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        title=dict(text=f"📈 Net Transfer Flow — {scope}", font=dict(size=14)),
        uirevision='transfer-flow-chart',

        margin=dict(l=50, r=20, t=50, b=40),
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1, bgcolor='rgba(0,0,0,0)'),
        hovermode='x unified',
        xaxis=x_axis_config,
        yaxis=dict(title="+ receiving / − sending", gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_explicit_transfers_chart(transfers_df, team_names, colors):
    if transfers_df.empty:
        return create_empty_fig("No transfer data", colors)
    
    transfers_df = transfers_df.copy()
    time_bins = pd.cut(transfers_df['game_time'], bins=40, labels=False)
    transfers_df['time_bin'] = time_bins
    
    bin_data = transfers_df.groupby('time_bin').agg({
        'game_time': 'mean',
        'amount': 'sum',
        'untaxed': 'sum',
        'taxed': 'sum'
    }).reset_index()
    
    fig = go.Figure()
    
    fig.add_trace(go.Bar(
        x=bin_data['game_time'],
        y=bin_data['amount'],
        name='Total Sent',
        marker_color=colors['orange'],
        opacity=0.7,
        hovertemplate='Sent: %{y:.0f}<extra></extra>'
    ))
    
    fig.add_trace(go.Bar(
        x=bin_data['game_time'],
        y=bin_data['untaxed'],
        name='Received',
        marker_color=colors['green'],
        opacity=0.9,
        hovertemplate='Received: %{y:.0f}<extra></extra>'
    ))
    
    x_axis_config = get_time_axis_config(transfers_df['game_time'], colors)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        title=dict(text="📦 Waterfill Transfers — All Players (orange=sent, green=received)", font=dict(size=14)),
        margin=dict(l=50, r=20, t=50, b=40),
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1, bgcolor='rgba(0,0,0,0)'),
        hovermode='x unified',
        barmode='overlay',
        xaxis=x_axis_config,
        yaxis=dict(title="Amount", gridcolor=colors['border'], zerolinecolor=colors['border']),
        uirevision='explicit-transfers',

    )
    
    return fig


def create_total_sent_chart(transfers_df, team_names, colors):
    if transfers_df.empty:
        return create_empty_fig("No data", colors)
    
    totals = transfers_df.groupby('sender_team_id')['amount'].sum().sort_values(ascending=True)
    
    team_labels = [get_team_display_name(tid, team_names) for tid in totals.index]
    bar_colors = [get_player_color(tid) for tid in totals.index]
    
    fig = go.Figure()
    fig.add_trace(go.Bar(
        y=team_labels,
        x=totals.values,
        orientation='h',
        marker_color=bar_colors,
        hovertemplate='%{x:.0f}<extra></extra>'
    ))
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text'], size=10),
        title=dict(text="Total Sent — All Players", font=dict(size=12)),
        margin=dict(l=80, r=10, t=35, b=20),
        showlegend=False,
        xaxis=dict(gridcolor=colors['border'], zerolinecolor=colors['border']),
        yaxis=dict(gridcolor=colors['border']),
        uirevision='total-sent',

    )
    
    return fig


def create_supply_demand_chart(group_lift_df, colors):
    if group_lift_df.empty:
        return create_empty_fig("No data", colors)
    
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=group_lift_df['game_time'],
        y=group_lift_df['total_supply'],
        mode='markers',
        name='Supply',
        marker=dict(color=colors['green'], size=4),
        hovertemplate='Supply: %{y:.0f}<extra></extra>'
    ))
    
    fig.add_trace(go.Scatter(
        x=group_lift_df['game_time'],
        y=group_lift_df['total_demand'],
        mode='markers',
        name='Demand',
        marker=dict(color=colors['red'], size=4),
        hovertemplate='Demand: %{y:.0f}<extra></extra>'
    ))
    
    x_axis_config = get_time_axis_config(group_lift_df['game_time'], colors)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text'], size=10),
        title=dict(text="Supply / Demand — Alliance", font=dict(size=12)),
        uirevision='supply-demand-chart',

        margin=dict(l=50, r=10, t=35, b=30),
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1, bgcolor='rgba(0,0,0,0)', font=dict(size=9)),
        hovermode='x unified',
        xaxis=x_axis_config,
        yaxis=dict(gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_lift_chart(group_lift_df, colors):
    if group_lift_df.empty:
        return create_empty_fig("No data", colors)
    
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=group_lift_df['game_time'],
        y=group_lift_df['lift'],
        mode='markers',
        name='Lift',
        marker=dict(color=colors['cyan'], size=4),
        hovertemplate='Lift: %{y:.1f}<extra></extra>'
    ))
    
    x_axis_config = get_time_axis_config(group_lift_df['game_time'], colors)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text'], size=10),
        title=dict(text="Waterfill Lift — Alliance", font=dict(size=12)),
        uirevision='lift-chart',

        margin=dict(l=50, r=10, t=35, b=30),
        showlegend=False,
        hovermode='x unified',
        xaxis=x_axis_config,
        yaxis=dict(gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_transaction_ledger(transfers_df, team_names, selected_teams=None, limit=50):
    if transfers_df.empty:
        return []
    
    df = transfers_df.copy()
    if selected_teams:
        df = df[(df['sender_team_id'].isin(selected_teams)) | (df['receiver_team_id'].isin(selected_teams))]
    
    if df.empty:
        return []
    
    recent = df.tail(limit).iloc[::-1]
    
    records = []
    for _, row in recent.iterrows():
        sender = get_team_display_name(int(row['sender_team_id']), team_names)
        receiver = get_team_display_name(int(row['receiver_team_id']), team_names)
        records.append({
            'time': format_time_mmss(row['game_time']),
            'from': sender,
            'to': receiver,
            'sent': f"{int(row['amount'])}",
            'recv': f"{int(row['untaxed'])}",
            'tax': f"{int(row['taxed'])}"
        })
    
    return records


# === Timing Analysis Charts ===
METRIC_ORDER = [
    'Overall',  # Total time first
    'CppMunge',
    'LuaMunge', 
    'Solver',
    'PostMunge',
    'PolicyCache',
    'LuaTotal',
    'CppSetters',
    'LuaSetters',
]

def metric_sort_key(metric):
    """Sort metrics in chronological order, with totals at end."""
    try:
        return METRIC_ORDER.index(metric)
    except ValueError:
        return 100 + hash(metric) % 100

def create_timing_summary_table(timing_df):
    if timing_df.empty:
        return html.Div("No timing data available. Run the game with audit logging enabled.",
                       style={'color': COLORS['text_muted'], 'padding': '20px'})
    
    source_paths = timing_df['source_path'].unique() if 'source_path' in timing_df.columns else []
    
    if len(source_paths) <= 1:
        sorted_df = timing_df.copy()
        sorted_df['_order'] = sorted_df['metric'].apply(metric_sort_key)
        sorted_df = sorted_df.sort_values('_order').drop('_order', axis=1)
        
        return dash_table.DataTable(
            data=sorted_df.to_dict('records'),
            columns=[
                {'name': 'Source', 'id': 'source_path'},
                {'name': 'Metric', 'id': 'metric'},
                {'name': 'Count', 'id': 'count', 'type': 'numeric', 'format': {'specifier': ','}},
                {'name': 'Avg (μs)', 'id': 'avg_us', 'type': 'numeric', 'format': {'specifier': '.2f'}},
                {'name': 'Min (μs)', 'id': 'min_us', 'type': 'numeric', 'format': {'specifier': '.2f'}},
                {'name': 'Max (μs)', 'id': 'max_us', 'type': 'numeric', 'format': {'specifier': '.2f'}},
                {'name': 'First Frame', 'id': 'first_frame'},
                {'name': 'Last Frame', 'id': 'last_frame'},
            ],
            style_table={'overflowX': 'auto'},
            style_cell={
                'textAlign': 'left',
                'padding': '8px 12px',
                'fontFamily': 'JetBrains Mono, monospace',
                'fontSize': '12px',
                'backgroundColor': COLORS['card'],
                'color': COLORS['text'],
                'border': f"1px solid {COLORS['border']}",
            },
            style_header={
                'backgroundColor': COLORS['background'],
                'color': COLORS['text_muted'],
                'fontWeight': '600',
                'border': f"1px solid {COLORS['border']}",
            },
            style_data_conditional=[
                {'if': {'row_index': 'odd'}, 'backgroundColor': COLORS['card_lighter']}
            ],
        )
    
    metrics = sorted(timing_df['metric'].unique(), key=metric_sort_key)
    comparison_data = []
    
    for metric in metrics:
        row = {'metric': metric}
        for sp in source_paths:
            sp_data = timing_df[(timing_df['source_path'] == sp) & (timing_df['metric'] == metric)]
            if not sp_data.empty:
                row[f'{sp}_avg'] = sp_data['avg_us'].values[0]
                row[f'{sp}_count'] = sp_data['count'].values[0]
            else:
                row[f'{sp}_avg'] = None
                row[f'{sp}_count'] = 0
        
        if len(source_paths) == 2:
            sp1, sp2 = sorted(source_paths)
            if row.get(f'{sp1}_avg') and row.get(f'{sp2}_avg'):
                diff = row[f'{sp2}_avg'] - row[f'{sp1}_avg']
                pct = (diff / row[f'{sp1}_avg']) * 100 if row[f'{sp1}_avg'] > 0 else 0
                row['diff'] = diff
                row['diff_pct'] = pct
        
        comparison_data.append(row)
    
    columns = [{'name': 'Metric', 'id': 'metric'}]
    for sp in sorted(source_paths):
        sp_label = 'ResourceExcess' if sp == 'RE' else 'ProcessEconomy' if sp == 'PE' else sp
        columns.append({'name': f'{sp_label} Avg (μs)', 'id': f'{sp}_avg', 'type': 'numeric', 'format': {'specifier': '.2f'}})
        columns.append({'name': f'{sp_label} Count', 'id': f'{sp}_count', 'type': 'numeric', 'format': {'specifier': ','}})
    
    if len(source_paths) == 2:
        columns.append({'name': 'Δ (μs)', 'id': 'diff', 'type': 'numeric', 'format': {'specifier': '+.2f'}})
        columns.append({'name': 'Δ %', 'id': 'diff_pct', 'type': 'numeric', 'format': {'specifier': '+.1f'}})
    
    return dash_table.DataTable(
        data=comparison_data,
        columns=columns,
        style_table={'overflowX': 'auto'},
        style_cell={
            'textAlign': 'left',
            'padding': '8px 12px',
            'fontFamily': 'JetBrains Mono, monospace',
            'fontSize': '12px',
            'backgroundColor': COLORS['card'],
            'color': COLORS['text'],
            'border': f"1px solid {COLORS['border']}",
        },
        style_header={
            'backgroundColor': COLORS['background'],
            'color': COLORS['text_muted'],
            'fontWeight': '600',
            'border': f"1px solid {COLORS['border']}",
        },
        style_data_conditional=[
            {'if': {'row_index': 'odd'}, 'backgroundColor': COLORS['card_lighter']},
            {'if': {'filter_query': '{diff} > 0', 'column_id': 'diff'}, 'color': COLORS['red']},
            {'if': {'filter_query': '{diff} < 0', 'column_id': 'diff'}, 'color': COLORS['green']},
            {'if': {'filter_query': '{diff_pct} > 0', 'column_id': 'diff_pct'}, 'color': COLORS['red']},
            {'if': {'filter_query': '{diff_pct} < 0', 'column_id': 'diff_pct'}, 'color': COLORS['green']},
        ],
    )


def create_timing_over_time_chart(solver_df, colors):
    if solver_df.empty:
        return create_empty_fig("No solver timing data available", colors)
    
    metrics = sorted(solver_df['metric'].unique(), key=metric_sort_key)
    source_paths = sorted(solver_df['source_path'].unique()) if 'source_path' in solver_df.columns else ['ALL']
    n_metrics = len(metrics)
    
    SOURCE_COLORS = {'RE': '#FF6B6B', 'PE': '#4ECDC4'}
    SOURCE_LABELS = {'RE': 'ResourceExcess', 'PE': 'ProcessEconomy'}
    
    fig = make_subplots(rows=n_metrics, cols=1, shared_xaxes=True,
                        subplot_titles=[m for m in metrics],
                        vertical_spacing=0.06)
    
    for i, metric in enumerate(metrics, 1):
        for sp in source_paths:
            mdf = solver_df[(solver_df['metric'] == metric) & (solver_df['source_path'] == sp)].copy()
            if mdf.empty:
                continue
                
            color = SOURCE_COLORS.get(sp, METRIC_COLORS.get(metric, '#888888'))
            label = SOURCE_LABELS.get(sp, sp)
            
            mdf = mdf.sort_values('frame')
            
            # Compute game time for tooltips
            mdf['game_time'] = mdf['frame'] / 30.0
            mdf['time_str'] = mdf['game_time'].apply(lambda t: f"{int(t//60)}:{t%60:05.2f}")
            
            # Raw data with detailed tooltip
            fig.add_trace(go.Scatter(
                x=mdf['frame'], 
                y=mdf['time_us'],
                mode='lines+markers' if len(mdf) < 50 else 'lines',
                name=label,
                line=dict(color=color, width=1),
                marker=dict(size=4, color=color) if len(mdf) < 50 else None,
                opacity=0.6,
                customdata=np.column_stack([mdf['time_str'], mdf['game_time']]),
                hovertemplate=(
                    f'<b>{label} - {metric}</b><br>' +
                    'Frame: %{x}<br>' +
                    'Time: %{customdata[0]}<br>' +
                    'Duration: <b>%{y:.2f}μs</b>' +
                    '<extra></extra>'
                ),
                showlegend=(i == 1),
                legendgroup=sp,
            ), row=i, col=1)
            
            # Rolling average with thicker line
            if len(mdf) > 10:
                window = min(30, len(mdf) // 3)
                rolling_avg = mdf['time_us'].rolling(window=window, min_periods=1).mean()
                fig.add_trace(go.Scatter(
                    x=mdf['frame'], 
                    y=rolling_avg,
                    mode='lines', 
                    name=f'{label} (avg)',
                    line=dict(color=color, width=3),
                    opacity=1.0,
                    hovertemplate=f'{label} {window}-frame avg: %{{y:.1f}}μs<extra></extra>',
                    showlegend=False,
                    legendgroup=sp,
                ), row=i, col=1)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        height=max(400, 120 * n_metrics),
        margin=dict(l=60, r=20, t=40, b=40),
        showlegend=True,
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1),
        uirevision='timing-chart',
        hovermode='closest',
    )
    
    for i in range(1, n_metrics + 1):
        fig.update_yaxes(title_text="μs", gridcolor=colors['border'], row=i, col=1)
    
    fig.update_xaxes(title_text="Frame", gridcolor=colors['border'], row=n_metrics, col=1)
    
    return fig




def create_timing_histograms(solver_df, colors):
    if solver_df.empty:
        return create_empty_fig("No solver timing data available", colors)
    
    metrics = solver_df['metric'].unique()
    source_paths = solver_df['source_path'].unique() if 'source_path' in solver_df.columns else ['ALL']
    n_metrics = len(metrics)
    n_sources = len(source_paths)
    cols = min(3, n_metrics)
    rows = (n_metrics + cols - 1) // cols
    
    SOURCE_COLORS = {'RE': '#FF6B6B', 'PE': '#4ECDC4'}
    
    fig = make_subplots(rows=rows, cols=cols,
                        subplot_titles=[m for m in metrics])
    
    for idx, metric in enumerate(metrics):
        row = idx // cols + 1
        col = idx % cols + 1
        
        if n_sources > 1:
            for sp in sorted(source_paths):
                mdf = solver_df[(solver_df['metric'] == metric) & (solver_df['source_path'] == sp)]['time_us']
                if mdf.empty:
                    continue
                color = SOURCE_COLORS.get(sp, METRIC_COLORS.get(metric, '#888888'))
                sp_label = 'ResourceExcess' if sp == 'RE' else 'ProcessEconomy' if sp == 'PE' else sp
                
                fig.add_trace(go.Histogram(
                    x=mdf,
                    nbinsx=50,
                    marker_color=color,
                    opacity=0.5,
                    name=sp_label,
                    hovertemplate=f'{sp_label}: %{{x:.1f}}μs (%{{y}})<extra></extra>',
                    showlegend=(idx == 0)
                ), row=row, col=col)
        else:
            mdf = solver_df[solver_df['metric'] == metric]['time_us']
            color = METRIC_COLORS.get(metric, '#888888')
            
            fig.add_trace(go.Histogram(
                x=mdf,
                nbinsx=50,
                marker_color=color,
                opacity=0.7,
                hovertemplate='%{x:.1f}μs: %{y}<extra></extra>',
                showlegend=False
            ), row=row, col=col)
            
            fig.add_vline(x=mdf.mean(), line_dash="dash", line_color=colors['green'],
                         row=row, col=col)
            fig.add_vline(x=mdf.median(), line_dash="dot", line_color=colors['yellow'],
                         row=row, col=col)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        height=300 * rows,
        margin=dict(l=60, r=20, t=60, b=40),
        barmode='overlay' if n_sources > 1 else 'relative',
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1) if n_sources > 1 else None,
        uirevision='timing-histogram',
    )
    
    fig.update_xaxes(gridcolor=colors['border'], automargin=False)
    fig.update_yaxes(gridcolor=colors['border'], automargin=False)
    
    return fig


def create_timing_anomalies_table(solver_df, threshold_percentile=99):
    if solver_df.empty:
        return html.Div("No timing data available", style={'color': COLORS['text_muted']})
    
    has_source = 'source_path' in solver_df.columns
    
    anomalies = []
    for metric in solver_df['metric'].unique():
        if has_source:
            for sp in solver_df['source_path'].unique():
                mdf = solver_df[(solver_df['metric'] == metric) & (solver_df['source_path'] == sp)]
                if mdf.empty:
                    continue
                threshold = mdf['time_us'].quantile(threshold_percentile / 100)
                
                high_frames = mdf[mdf['time_us'] > threshold]
                for _, row in high_frames.iterrows():
                    anomalies.append({
                        'frame': int(row['frame']),
                        'source': sp,
                        'metric': metric,
                        'time_us': row['time_us'],
                        'threshold': threshold
                    })
        else:
            mdf = solver_df[solver_df['metric'] == metric]
            threshold = mdf['time_us'].quantile(threshold_percentile / 100)
            
            high_frames = mdf[mdf['time_us'] > threshold]
            for _, row in high_frames.iterrows():
                anomalies.append({
                    'frame': int(row['frame']),
                    'metric': metric,
                    'time_us': row['time_us'],
                    'threshold': threshold
                })
    
    if not anomalies:
        return html.Div("✅ No anomalies found above threshold",
                       style={'color': COLORS['green'], 'padding': '10px'})
    
    anomaly_df = pd.DataFrame(anomalies).sort_values('time_us', ascending=False).head(20)
    
    pow2_values = [2**i for i in range(8, 14)]
    suspicious = anomaly_df[anomaly_df['time_us'].apply(lambda x: any(abs(x - p) < 10 for p in pow2_values))]
    
    warning = None
    if not suspicious.empty:
        warning = html.P("⚠️ Some values are close to powers of 2, which may indicate timer resolution issues.",
                        style={'color': COLORS['red'], 'marginTop': '10px'})
    
    columns = [{'name': 'Frame', 'id': 'frame'}]
    if has_source:
        columns.append({'name': 'Source', 'id': 'source'})
    columns.extend([
        {'name': 'Metric', 'id': 'metric'},
        {'name': 'Time (μs)', 'id': 'time_us', 'type': 'numeric', 'format': {'specifier': '.2f'}},
        {'name': 'Threshold', 'id': 'threshold', 'type': 'numeric', 'format': {'specifier': '.2f'}},
    ])
    
    return html.Div([
        dash_table.DataTable(
            data=anomaly_df.to_dict('records'),
            columns=columns,
            style_table={'overflowX': 'auto'},
            style_cell={
                'textAlign': 'left',
                'padding': '6px 10px',
                'fontFamily': 'JetBrains Mono, monospace',
                'fontSize': '11px',
                'backgroundColor': COLORS['card'],
                'color': COLORS['text'],
                'border': f"1px solid {COLORS['border']}",
            },
            style_header={
                'backgroundColor': COLORS['background'],
                'color': COLORS['text_muted'],
                'fontWeight': '600',
            },
            page_size=10
        ),
        warning
    ])


# === Waterfill Analysis Charts ===
def create_waterfill_tank_diagram(wf_df, inp_df, lift_df, resource, frame, colors):
    if wf_df.empty:
        return create_empty_fig(f"No waterfill data for frame {frame}", colors)
    
    # Merge waterfill data with input data, selecting only needed columns to avoid conflicts
    wf = wf_df.merge(inp_df[['team_id', 'storage', 'share_cursor']], on='team_id', how='left')
    n_teams = len(wf)
    
    lift = lift_df['lift'].iloc[0] if not lift_df.empty else 0
    supply = lift_df['total_supply'].iloc[0] if not lift_df.empty else 0
    demand = lift_df['total_demand'].iloc[0] if not lift_df.empty else 0
    
    max_storage = wf['storage'].max() if not wf.empty else 1000
    resource_color = colors['metal'] if resource == 'metal' else colors['energy']
    
    # Compute game time for display
    game_time = frame / 30.0
    time_str = f"{int(game_time//60)}:{game_time%60:05.2f}"
    
    fig = go.Figure()
    
    for i, row in wf.iterrows():
        x_center = i * 1.2
        storage = row['storage']
        current = row['current']
        target = row['target']
        delta = row.get('delta', 0) or 0
        # share_cursor is absolute value from eco_team_input (slider × storage)
        share_cursor = row.get('share_cursor')
        if pd.isna(share_cursor):
            share_cursor = storage * 0.99  # Fallback to default slider
        share_cursor_normalized = share_cursor / storage if storage > 0 else 0.99
        role = row['role']
        
        height_scale = storage / max_storage if max_storage > 0 else 1
        tank_height = 5 * height_scale
        tank_width = 0.7
        
        # Tank outline
        fig.add_shape(
            type="rect",
            x0=x_center - tank_width/2, y0=0,
            x1=x_center + tank_width/2, y1=tank_height,
            line=dict(color='#e0e0e0', width=2),
            fillcolor='rgba(0,0,0,0)'
        )
        
        # Fill level
        fill_height = (current / storage * tank_height) if storage > 0 else 0
        fig.add_shape(
            type="rect",
            x0=x_center - tank_width/2 + 0.02, y0=0.02,
            x1=x_center + tank_width/2 - 0.02, y1=fill_height,
            fillcolor=resource_color,
            opacity=0.7,
            line=dict(width=0)
        )
        
        # Target line (white dashed)
        target_y = (target / storage * tank_height) if storage > 0 else 0
        fig.add_shape(
            type="line",
            x0=x_center - tank_width/2 - 0.1, y0=target_y,
            x1=x_center + tank_width/2 + 0.1, y1=target_y,
            line=dict(color='white', width=2, dash='dash')
        )
        
        # Share cursor line (orange dotted)
        cursor_y = (share_cursor / storage * tank_height) if storage > 0 else 0
        fig.add_shape(
            type="line",
            x0=x_center - tank_width/2, y0=cursor_y,
            x1=x_center + tank_width/2, y1=cursor_y,
            line=dict(color='#ff9800', width=1.5, dash='dot')
        )
        
        role_colors = {'sender': SENDER_COLOR, 'receiver': RECEIVER_COLOR, 'neutral': NEUTRAL_COLOR}
        role_color = role_colors.get(role, NEUTRAL_COLOR)
        
        # Add invisible scatter point for tooltip
        delta_sign = '+' if delta >= 0 else ''
        fig.add_trace(go.Scatter(
            x=[x_center],
            y=[fill_height],
            mode='markers',
            marker=dict(size=30, color='rgba(0,0,0,0)'),
            showlegend=False,
            hovertemplate=(
                f'<b>Team {int(row["team_id"])}</b> ({role.upper()})<br>'
                f'Current: {current:.1f} / {storage:.0f}<br>'
                f'Target: {target:.1f}<br>'
                f'Share Slider: {share_cursor_normalized*100:.0f}% ({share_cursor:.1f})<br>'
                f'Delta: {delta_sign}{delta:.1f}<br>'
                f'Fill %: {current/storage*100:.1f}%'
                '<extra></extra>'
            ),
        ))
        
        # Labels
        fig.add_annotation(
            x=x_center, y=-0.5,
            text=f"T{int(row['team_id'])}",
            showarrow=False,
            font=dict(size=12, color=role_color, family='JetBrains Mono')
        )
        fig.add_annotation(
            x=x_center, y=-0.9,
            text=role.upper() if role else 'N/A',
            showarrow=False,
            font=dict(size=9, color=role_color, family='JetBrains Mono')
        )
        fig.add_annotation(
            x=x_center, y=tank_height + 0.3,
            text=f"{current:.0f}/{storage:.0f}",
            showarrow=False,
            font=dict(size=9, color=colors['text_muted'], family='JetBrains Mono')
        )
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        title=dict(
            text=f"🌊 Waterfill: {resource.upper()} | Frame {frame}<br>"
                 f"<span style='font-size:12px;color:{colors['text_muted']}'>Lift: {lift:.2f} | Supply: {supply:.1f} | Demand: {demand:.1f}</span>",
            font=dict(size=14)
        ),
        margin=dict(l=40, r=40, t=80, b=60),
        xaxis=dict(showgrid=False, zeroline=False, showticklabels=False, range=[-0.8, n_teams * 1.2 - 0.4]),
        yaxis=dict(showgrid=False, zeroline=False, showticklabels=False, range=[-1.5, 6]),
        showlegend=False,
        height=400,
        uirevision='waterfill-tank',
    )
    
    return fig


def create_conservation_chart(output_df, resource, colors):
    if output_df.empty:
        return create_empty_fig("No output data for conservation check", colors)
    
    rdf = output_df[output_df['resource'] == resource] if 'resource' in output_df.columns else output_df
    
    if rdf.empty:
        return create_empty_fig(f"No {resource} data", colors)
    
    frame_totals = rdf.groupby('frame').agg({'sent': 'sum', 'received': 'sum'}).reset_index()
    frame_totals['tax'] = frame_totals['sent'] - frame_totals['received']
    frame_totals['balance_error'] = abs(frame_totals['sent'] - frame_totals['received'] - frame_totals['tax'])
    frame_totals['game_time'] = frame_totals['frame'] / 30.0
    
    resource_color = colors['metal'] if resource == 'metal' else colors['energy']
    
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        subplot_titles=['Tax Collected (Sent - Received)', 'Conservation Error'],
                        vertical_spacing=0.15)
    
    fig.add_trace(go.Scatter(
        x=frame_totals['game_time'], y=frame_totals['tax'],
        mode='lines', name=f'{resource} tax',
        line=dict(color=resource_color, width=2),
        hovertemplate='Tax: %{y:.1f}<extra></extra>'
    ), row=1, col=1)
    
    fig.add_hline(y=0, line_dash="dash", line_color=colors['orange'], opacity=0.5, row=1, col=1)
    
    fig.add_trace(go.Scatter(
        x=frame_totals['game_time'], y=frame_totals['balance_error'],
        mode='lines', name='Error',
        line=dict(color=resource_color, width=2),
        hovertemplate='Error: %{y:.6f}<extra></extra>'
    ), row=2, col=1)
    
    fig.add_hline(y=0.01, line_dash="dash", line_color=colors['red'],
                 annotation_text="Tolerance", opacity=0.7, row=2, col=1)
    
    max_error = frame_totals['balance_error'].max()
    violations = len(frame_totals[frame_totals['balance_error'] > 0.01])
    status_color = colors['green'] if violations == 0 else colors['red']
    status_text = "✅ VERIFIED" if violations == 0 else f"⚠️ {violations} violations"
    
    x_axis_config = get_time_axis_config(frame_totals['game_time'], colors)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        title=dict(
            text=f"🔬 Conservation Check: {resource.upper()} | Max Error: {max_error:.6f} | {status_text}",
            font=dict(size=14, color=status_color)
        ),
        uirevision='conservation-chart',

        margin=dict(l=60, r=20, t=60, b=40),
        height=400,
        showlegend=False,
    )
    
    fig.update_xaxes(x_axis_config, row=2, col=1)
    fig.update_yaxes(gridcolor=colors['border'], row=1, col=1)
    fig.update_yaxes(gridcolor=colors['border'], row=2, col=1)
    
    return fig


def create_transfer_matrix_heatmap(transfers_df, resource, frame, colors):
    if transfers_df.empty:
        return create_empty_fig(f"No transfer data for frame {frame}", colors)
    
    all_teams = sorted(set(transfers_df['sender_team_id'].tolist() + transfers_df['receiver_team_id'].tolist()))
    n = len(all_teams)
    team_idx = {t: i for i, t in enumerate(all_teams)}
    
    matrix = np.zeros((n, n))
    for _, row in transfers_df.iterrows():
        i = team_idx[row['sender_team_id']]
        j = team_idx[row['receiver_team_id']]
        matrix[i, j] = row['total_amount']
    
    resource_color = colors['metal'] if resource == 'metal' else colors['energy']
    
    fig = go.Figure(data=go.Heatmap(
        z=matrix,
        x=[f'T{t}' for t in all_teams],
        y=[f'T{t}' for t in all_teams],
        colorscale=[[0, colors['background']], [1, resource_color]],
        hovertemplate='From T%{y} → T%{x}: %{z:.0f}<extra></extra>'
    ))
    
    for i in range(n):
        for j in range(n):
            if matrix[i, j] > 0:
                text_color = 'white' if matrix[i, j] > matrix.max()/2 else colors['text_muted']
                fig.add_annotation(
                    x=j, y=i,
                    text=f"{matrix[i, j]:.0f}",
                    showarrow=False,
                    font=dict(size=10, color=text_color, family='JetBrains Mono')
                )
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        title=dict(text=f"🔄 Transfer Matrix: {resource.upper()} | Frame {frame}", font=dict(size=14)),
        uirevision='transfer-matrix',

        margin=dict(l=60, r=20, t=60, b=60),
        xaxis=dict(title="Receiver", side='bottom'),
        yaxis=dict(title="Sender", autorange='reversed'),
        height=400
    )
    
    return fig


# === Dash App ===
app = dash.Dash(
    __name__,
    external_stylesheets=[
        dbc.themes.DARKLY,
        "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&display=swap"
    ],
    title="BAR Economy Audit",
    suppress_callback_exceptions=True
)

app.index_string = '''
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
        <style>
            /* Minimal theme fixes for Dash components in Darkly */
            .explanation-card {
                background-color: #1c2128;
                border: 1px solid #30363d;
                border-radius: 8px;
                padding: 15px;
                margin-bottom: 20px;
            }
            .explanation-card h4 {
                color: #58a6ff;
                margin-bottom: 10px;
            }
            
            /* dcc.Slider and RangeSlider colors */
            .rc-slider-rail { background-color: #30363d; }
            .rc-slider-track { background-color: #58a6ff; }
            .rc-slider-handle { 
                background-color: #58a6ff; 
                border-color: #58a6ff;
            }
            .rc-slider-mark-text { color: #8b949e; }
            
            /* Tab styling */
            .nav-tabs .nav-link { color: #8b949e; }
            .nav-tabs .nav-link.active { 
                color: #58a6ff;
                background-color: transparent;
                border-color: transparent transparent #58a6ff;
                border-width: 0 0 2px 0;
            }
            
            /* Custom Scrollbar */
            ::-webkit-scrollbar { width: 8px; height: 8px; }
            ::-webkit-scrollbar-track { background: #0d1117; }
            ::-webkit-scrollbar-thumb { background: #30363d; border-radius: 4px; }
            ::-webkit-scrollbar-thumb:hover { background: #8b949e; }
        </style>
    </head>
    <body>
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
            <script>
                document.addEventListener('DOMContentLoaded', function() {
                    const WS_PORT = %WS_PORT%;
                    let ws = null;
                    let lastRefreshMs = 0;

                    function updateBadge(text, colorClass, connected) {
                        function tryUpdate() {
                            const indicator = document.getElementById('ws-indicator');
                            if (indicator) {
                                indicator.textContent = text;
                                indicator.className = 'badge me-2 bg-' + colorClass;
                            } else {
                                setTimeout(tryUpdate, 100);
                                return;
                            }
                            const pollCol = document.getElementById('interval-dropdown-col');
                            if (pollCol) {
                                pollCol.style.display = connected ? 'none' : '';
                            }
                        }
                        tryUpdate();
                    }

                    function requestRefreshThrottled() {
                        const now = Date.now();
                        if (now - lastRefreshMs < 500) return;
                        lastRefreshMs = now;
                        const refreshBtn = document.getElementById('refresh-btn');
                        if (refreshBtn) refreshBtn.click();
                    }

                    function connect() {
                        try {
                            const host = window.location.hostname || '127.0.0.1';
                            const url = `ws://${host}:${WS_PORT}`;
                            updateBadge('○ WS', 'secondary', false);
                            ws = new WebSocket(url);

                            ws.onopen = function() {
                                updateBadge('● WS', 'success', true);
                            };

                            ws.onclose = function() {
                                updateBadge('○ WS', 'secondary', false);
                                setTimeout(connect, 1000);
                            };

                            ws.onerror = function() {
                                updateBadge('✗ WS', 'danger', false);
                            };

                            ws.onmessage = function() {
                                updateBadge('● WS', 'success', true);
                                requestRefreshThrottled();
                            };
                        } catch (e) {
                            updateBadge('✗ WS', 'danger', false);
                            setTimeout(connect, 2000);
                        }
                    }

                    connect();
                });
            </script>
        </footer>
    </body>
</html>
'''

app.index_string = app.index_string.replace('%WS_PORT%', str(WS_PORT))


def create_explanation_card(title, content):
    return html.Div([
        html.H4(title),
        dcc.Markdown(content, dangerously_allow_html=True)
    ], className="explanation-card")


# === Tab: Economy Overview ===
def create_economy_tab():
    return html.Div([
        dbc.Row([
            dbc.Col([
                dbc.Label("Players (select for per-player charts)", style={'fontSize': '12px', 'fontWeight': '500'}),
                html.Div([
                    dbc.Button("All", id="select-all-btn", color="secondary", size="sm", className="me-2"),
                    dbc.Button("None", id="select-none-btn", color="secondary", size="sm", className="me-3"),
                    dbc.Checklist(
                        id='team-checklist',
                        options=[],
                        value=[],
                        inline=True,
                        className="d-inline",
                    )
                ], className="d-flex align-items-center flex-wrap")
            ], width=10),
            dbc.Col([
                dbc.Button("📄 Export to Markdown", id="export-economy-btn", color="primary", size="sm",
                          style={'marginTop': '24px'}),
                dcc.Download(id="download-economy-md")
            ], width=2, className="text-end"),
        ], className="mb-3"),
        
        dbc.Row([
            dbc.Col([
                dcc.Loading(
                    dcc.Graph(id='resource-chart', style={'height': '280px'}),
                    type='circle', color=COLORS['accent'], delay_show=1000
                ),
                dcc.Loading(
                    dcc.Graph(id='transfer-flow-chart', style={'height': '250px', 'marginTop': '10px'}),
                    type='circle', color=COLORS['accent'], delay_show=1000
                ),
                dcc.Loading(
                    dcc.Graph(id='explicit-transfers-chart', style={'height': '250px', 'marginTop': '10px'}),
                    type='circle', color=COLORS['accent'], delay_show=1000
                ),
            ], width=8),
            
            dbc.Col([
                dcc.Loading(
                    dcc.Graph(id='total-sent-chart', style={'height': '180px'}),
                    type='circle', color=COLORS['accent'], delay_show=1000
                ),
                dcc.Loading(
                    dcc.Graph(id='supply-demand-chart', style={'height': '180px', 'marginTop': '8px'}),
                    type='circle', color=COLORS['accent'], delay_show=1000
                ),
                dcc.Loading(
                    dcc.Graph(id='lift-chart', style={'height': '150px', 'marginTop': '8px'}),
                    type='circle', color=COLORS['accent'], delay_show=1000
                ),
                html.Div([
                    html.H6("📋 Transfer Ledger", className="mb-2", 
                            style={'color': COLORS['text'], 'fontFamily': 'JetBrains Mono', 'fontSize': '12px'}),
                    html.Small("Showing transfers for selected players", className="text-muted d-block mb-2", style={'fontSize': '10px'}),
                    dash_table.DataTable(
                        id='transfer-ledger',
                        columns=[
                            {'name': 'Time', 'id': 'time'},
                            {'name': 'From', 'id': 'from'},
                            {'name': 'To', 'id': 'to'},
                            {'name': 'Sent', 'id': 'sent'},
                            {'name': 'Recv', 'id': 'recv'},
                            {'name': 'Tax', 'id': 'tax'},
                        ],
                        style_table={'height': '180px', 'overflowY': 'auto'},
                        style_cell={
                            'textAlign': 'left',
                            'padding': '4px 6px',
                            'fontFamily': 'JetBrains Mono, monospace',
                            'fontSize': '10px',
                            'backgroundColor': COLORS['card'],
                            'color': COLORS['text'],
                            'border': f"1px solid {COLORS['border']}",
                            'minWidth': '35px',
                            'maxWidth': '70px',
                            'overflow': 'hidden',
                            'textOverflow': 'ellipsis',
                        },
                        style_header={
                            'backgroundColor': COLORS['background'],
                            'color': COLORS['text_muted'],
                            'fontWeight': '600',
                            'border': f"1px solid {COLORS['border']}",
                            'fontSize': '9px',
                        },
                        style_data_conditional=[
                            {'if': {'row_index': 'odd'}, 'backgroundColor': COLORS['card_lighter']}
                        ],
                        page_size=50
                    )
                ], style={
                    'backgroundColor': COLORS['card'],
                    'borderRadius': '6px',
                    'padding': '8px',
                    'marginTop': '8px'
                }),
            ], width=4)
        ]),
    ])


# === Tab: Timing Analysis ===
def create_timing_tab():
    return html.Div([
        dbc.Row([
            dbc.Col([
                create_explanation_card("⏱️ RE vs PE Timing Comparison", """
Compare performance between **ResourceExcess (RE)** and **ProcessEconomy (PE)** approaches.

In **Alternate mode**, the engine runs both paths on alternating frames - use this to directly compare their performance.

**Metrics:**
- **Overall**: Total end-to-end time for the economy update
- **CppMunge**: C++ time to prepare team data before calling Lua
- **LuaMunge**: Lua time to build/transform team data before solving
- **Solver**: Time in the waterfill redistribution algorithm
- **PostMunge**: Lua time to format results after solver
- **LuaSetters**: Lua time calling Spring.SetTeamResource API
- **CppSetters**: C++ time applying SetTeamResource changes
- **PolicyCache**: Time to update transfer policy cache
- **LuaTotal**: Total Lua processing time (LuaMunge + Solver + PostMunge + LuaSetters)

**Color coding:** 🟢 Green = faster, 🔴 Red = slower (in Δ columns)
"""),
            ], width=10),
            dbc.Col([
                dbc.Button("📄 Export to Markdown", id="export-timing-btn", color="primary", size="sm"),
                dcc.Download(id="download-timing-md")
            ], width=2, className="text-end"),
        ], className="mb-3"),

        html.H5("📊 Timing Summary", style={'marginBottom': '15px'}),
        html.Div(id='timing-summary-table'),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        create_explanation_card("📈 Timing Over Time", """
Individual charts for each metric help identify anomalies and performance spikes.
- **Solid line**: Raw timing values  
- **Thicker line**: 30-frame rolling average
- In **Alternate mode**: RE and PE run on alternating SlowUpdate frames (every 30 game frames)
- In other modes: Only one path runs per SlowUpdate
"""),
        dcc.Loading(
            dcc.Graph(id='timing-over-time-chart'),
            type='circle', color=COLORS['accent'], delay_show=1000
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        create_explanation_card("📊 Timing Distributions", """
Histograms show the distribution of timing values per metric.
- **Green line**: Mean value
- **Yellow line**: Median value
- Wide distributions or long tails may indicate inconsistent performance.
"""),
        dcc.Loading(
            dcc.Graph(id='timing-histogram-chart'),
            type='circle', color=COLORS['accent'], delay_show=1000
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        html.H5("🚨 Anomaly Detection (>99th percentile)", style={'marginBottom': '15px'}),
        html.Div(id='timing-anomalies-table'),
    ])


# === Transfer Ledger Datagrid ===
def create_transfer_ledger_grid():
    """Create the full transfer ledger datagrid with independent filters."""
    return html.Div([
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '30px 0 20px 0'}),
        
        html.Div([
            html.H4("📒 Transfer Ledger", className="mb-0",
                    style={'fontFamily': 'JetBrains Mono', 'color': COLORS['text']}),
            html.P([
                html.Span("🔄 Passive", style={'color': COLORS['cyan']}),
                " = Waterfill auto-redistribution (to/from alliance pool) • ",
                html.Span("👆 Active", style={'color': COLORS['yellow']}),
                " = Manual player-initiated transfers"
            ], className="text-muted mb-0", style={'fontSize': '12px'})
        ], className="mb-3"),
        
        # Ledger-specific filters (one-way bound from global by default)
        dbc.Row([
            dbc.Col([
                dbc.Label("Session", style={'fontSize': '11px', 'fontWeight': '500'}),
                dbc.Select(
                    id='ledger-session-dropdown',
                    options=[{'label': '(use global)', 'value': ''}],
                    value='',
                )
            ], width=2),
            dbc.Col([
                dbc.Label("Resource", style={'fontSize': '11px', 'fontWeight': '500'}),
                dbc.Select(
                    id='ledger-resource-dropdown',
                    options=[
                        {'label': '(use global)', 'value': ''},
                        {'label': '🪨 Metal', 'value': 'metal'},
                        {'label': '⚡ Energy', 'value': 'energy'}
                    ],
                    value='',
                )
            ], width=2),
            dbc.Col([
                dbc.Label("Transfer Type", style={'fontSize': '11px', 'fontWeight': '500'}),
                dbc.Select(
                    id='ledger-type-dropdown',
                    options=[
                        {'label': 'All', 'value': 'all'},
                        {'label': '🔄 Passive (Waterfill)', 'value': 'passive'},
                        {'label': '👆 Active (Manual)', 'value': 'active'}
                    ],
                    value='all',
                )
            ], width=2),
            dbc.Col([
                dbc.Label("Team Filter", style={'fontSize': '11px', 'fontWeight': '500'}),
                dbc.Select(
                    id='ledger-team-dropdown',
                    placeholder="All teams",
                    options=[],
                )
            ], width=2),
            dbc.Col([
                dbc.Label("Search", style={'fontSize': '11px', 'fontWeight': '500'}),
                dbc.Input(
                    id='ledger-search-input',
                    type='text',
                    placeholder='Search team names...',
                    debounce=True,
                    style={'fontSize': '12px'}
                )
            ], width=3),
            dbc.Col([
                dbc.Label(" ", style={'fontSize': '11px'}),
                dbc.Button("🔗 Sync from Global", id="ledger-sync-btn", color="secondary", 
                          size="sm", className="d-block", style={'marginTop': '2px'}),
            ], width=1),
        ], className="mb-3"),
        
        # Pagination info
        html.Div([
            html.Span(id='ledger-showing-text', style={'color': COLORS['text_muted'], 'fontSize': '12px'}),
        ], className="mb-2"),
        
        # The DataTable
        dash_table.DataTable(
            id='transfer-ledger-grid',
            columns=[
                {'name': 'Time', 'id': 'time', 'type': 'text'},
                {'name': 'Frame', 'id': 'frame', 'type': 'numeric'},
                {'name': 'Type', 'id': 'type', 'type': 'text'},
                {'name': 'Resource', 'id': 'resource', 'type': 'text'},
                {'name': 'From', 'id': 'from', 'type': 'text'},
                {'name': 'To', 'id': 'to', 'type': 'text'},
                {'name': 'Sent', 'id': 'sent', 'type': 'numeric'},
                {'name': 'Received', 'id': 'received', 'type': 'numeric'},
                {'name': 'Tax', 'id': 'tax', 'type': 'numeric'},
            ],
            data=[],
            page_size=50,
            page_current=0,
            page_action='custom',
            sort_action='none',
            style_table={'overflowX': 'auto'},
            style_cell={
                'textAlign': 'left',
                'padding': '8px 12px',
                'fontFamily': 'JetBrains Mono, monospace',
                'fontSize': '12px',
                'backgroundColor': COLORS['card'],
                'color': COLORS['text'],
                'border': f"1px solid {COLORS['border']}",
                'minWidth': '60px',
                'maxWidth': '180px',
                'overflow': 'hidden',
                'textOverflow': 'ellipsis',
            },
            style_header={
                'backgroundColor': COLORS['background'],
                'color': COLORS['text_muted'],
                'fontWeight': '600',
                'border': f"1px solid {COLORS['border']}",
            },
            style_data_conditional=[
                {'if': {'row_index': 'odd'}, 'backgroundColor': COLORS['card_lighter']},
                {'if': {'filter_query': '{type} = "Passive"'}, 
                 'backgroundColor': 'rgba(136, 192, 208, 0.1)'},
                {'if': {'filter_query': '{type} = "Active"'}, 
                 'backgroundColor': 'rgba(235, 203, 139, 0.1)'},
            ],
        ),
        
        # Store for ledger state
        dcc.Store(id='ledger-total-count', data=0),
    ], style={
        'backgroundColor': COLORS['card'],
        'borderRadius': '8px',
        'padding': '20px',
        'marginBottom': '30px',
        'border': f"1px solid {COLORS['border']}"
    })


# === Tab: Waterfill Analysis ===
def create_waterfill_tab():
    return html.Div([
        # Frame navigator - inline in tab content
        html.Div([
            html.Div([
                html.Span("Frame ", className="text-muted", style={'fontSize': '13px'}),
                html.Span(id='wf-frame-display', style={'color': COLORS['accent'], 'fontWeight': 'bold', 'fontSize': '14px'}),
                html.Span(" / ", className="text-muted", style={'fontSize': '13px'}),
                html.Span(id='wf-frame-total', className="text-muted", style={'fontSize': '13px'}),
                html.Span(" • ", style={'color': COLORS['border'], 'margin': '0 10px'}),
                html.Span(id='wf-time-display', style={'fontSize': '13px'}),
            ], className="d-flex align-items-center"),
            html.Div([
                dbc.ButtonGroup([
                    dbc.Button("⏮", id='wf-first-btn', size="sm", color="secondary", outline=True, title="First frame"),
                    dbc.Button("◀", id='wf-prev-btn', size="sm", color="secondary", outline=True, title="Previous frame"),
                    dbc.Button("▶", id='wf-play-btn', size="sm", color="primary", outline=True, title="Play/Pause"),
                    dbc.Button("▶", id='wf-next-btn', size="sm", color="secondary", outline=True, title="Next frame"),
                    dbc.Button("⏭", id='wf-last-btn', size="sm", color="secondary", outline=True, title="Last frame (live)"),
                ], size="sm"),
                dbc.Badge("LIVE", id='wf-live-badge', color="success", className="ms-2", style={'display': 'none'}),
            ], className="d-flex align-items-center"),
        ], className="mb-3 py-2 px-3 d-flex justify-content-between align-items-center", 
           style={'backgroundColor': COLORS['card'], 'borderRadius': '6px', 
                  'border': f"1px solid {COLORS['border']}"}),
        
        dbc.Row([
            dbc.Col([
                create_explanation_card("🌊 Waterfill Resource Sharing Algorithm", """
The waterfill algorithm balances resources within team alliances:

1. **Share Cursor**: Each team sets a threshold (`storage × shareSlider`) - resources above this get shared
2. **Lift**: A common "water level lift" is computed to balance supply = demand across the alliance
3. **Target**: Each team's target = `min(shareCursor + lift, storage)`
4. **Flow**: Resources flow from teams above target (senders) to teams below target (receivers)
5. **Tax**: Transfers above the tax-free threshold are taxed (resources destroyed)

**Key Invariant**: `Σ Received = Σ Sent - Tax`
"""),
            ], width=10),
            dbc.Col([
                dbc.Button("📄 Export to Markdown", id="export-waterfill-btn", color="primary", size="sm"),
                dcc.Download(id="download-waterfill-md")
            ], width=2, className="text-end"),
        ], className="mb-3"),


        html.H5("🏗️ Tank Diagram", style={'marginBottom': '15px'}),
        html.P("Visual representation of each team's resource levels, targets, and roles:",
               style={'color': COLORS['text_muted'], 'fontSize': '13px'}),
        dcc.Loading(
            dcc.Graph(id='waterfill-tank-chart'),
            type='circle', color=COLORS['accent'], delay_show=1000
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        html.H5("🔄 Transfer Matrix", style={'marginBottom': '15px'}),
        html.P("Who sent resources to whom? Heatmap showing flow between teams:",
               style={'color': COLORS['text_muted'], 'fontSize': '13px'}),
        dcc.Loading(
            dcc.Graph(id='transfer-matrix-chart'),
            type='circle', color=COLORS['accent'], delay_show=1000
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        create_explanation_card("🔬 Conservation Verification", """
The solver must maintain the conservation law: **Total Received = Total Sent - Tax**.

This chart verifies that the invariant holds across all frames. Any violations indicate bugs in the solver.
"""),
        dcc.Loading(
            dcc.Graph(id='conservation-chart'),
            type='circle', color=COLORS['accent'], delay_show=1000
        ),
    ])


# === Main Layout ===
app.layout = dbc.Container([
    dbc.Row([
        dbc.Col([
            html.H1("⚡ Economy Audit", className="mb-0",
                    style={'fontFamily': 'JetBrains Mono', 'fontWeight': '600'}),
            html.P("Real-time resource flow visualization", 
                   className="text-muted mb-0", style={'fontFamily': 'JetBrains Mono'})
        ], width=6),
        dbc.Col([
            dbc.Badge("○ WS", color="secondary", className="me-2", id="ws-indicator"),
            dbc.Button("↻ Refresh", id="refresh-btn", color="secondary", size="sm", className="me-2"),
        ], width=6, className="text-end d-flex align-items-center justify-content-end")
    ], className="mb-3 pt-3"),
    
    dbc.Row([
        dbc.Col([
            dbc.Label("Session Filters", style={'fontSize': '12px', 'fontWeight': '500'}),
            dbc.Checklist(
                id='session-type-filter',
                options=[
                    {'label': ' RE (ResourceExcess)', 'value': 'RE'},
                    {'label': ' PE (ProcessEconomy)', 'value': 'PE'},
                    {'label': ' Other', 'value': 'Alternate'}
                ],
                value=['RE', 'PE', 'Alternate'],
                inline=True,
            )
        ], width=12),
    ], className="mb-2"),
    
    dbc.Row([
        dbc.Col([
            dbc.Label("Session", style={'fontSize': '12px', 'fontWeight': '500'}),
            dbc.Select(
                id='session-dropdown',
                placeholder="Select session...",
            )
        ], width=3),
        dbc.Col([
            dbc.Label("Resource", style={'fontSize': '12px', 'fontWeight': '500'}),
            dbc.Select(
                id='resource-dropdown',
                options=[
                    {'label': '🪨 Metal', 'value': 'metal'},
                    {'label': '⚡ Energy', 'value': 'energy'}
                ],
                value='metal',
            )
        ], width=2),
        dbc.Col([
            dbc.Label("Time Range", style={'fontSize': '12px', 'fontWeight': '500'}),
            html.Div([
                # Mode toggle and Last N input
                html.Div([
                    dbc.Select(
                        id='time-mode-select',
                        options=[
                            {'label': 'Last N mins', 'value': 'last'},
                            {'label': 'Range', 'value': 'range'},
                        ],
                        value='last',
                        style={'width': '132px', 'fontSize': '12px'}
                    ),
                    dbc.Input(
                        id='last-n-minutes-input',
                        type='number',
                        value=2,
                        min=1,
                        step=1,
                        style={'width': '60px', 'textAlign': 'center', 'fontFamily': 'JetBrains Mono, monospace', 'marginLeft': '6px'}
                    ),
                ], id='last-n-controls', style={'display': 'flex', 'alignItems': 'center'}),
                # Range controls (hidden by default)
                html.Div([
                    dbc.Input(
                        id='time-range-start-input',
                        type='text',
                        value='0:00',
                        placeholder='0:00',
                        style={'width': '60px', 'textAlign': 'center', 'fontFamily': 'JetBrains Mono, monospace', 'fontSize': '12px'}
                    ),
                    html.Div([
                        dcc.RangeSlider(
                            id='global-time-slider',
                            min=0, max=60, step=0.1, value=[0, 60],
                            marks=None,
                            tooltip={"placement": "bottom", "always_visible": False},
                        )
                    ], style={'flex': '1', 'margin': '0 8px'}),
                    dbc.Input(
                        id='time-range-end-input',
                        type='text',
                        value='60:00',
                        placeholder='60:00',
                        style={'width': '60px', 'textAlign': 'center', 'fontFamily': 'JetBrains Mono, monospace', 'fontSize': '12px'}
                    ),
                ], id='range-controls', style={'display': 'none', 'flex': '1', 'alignItems': 'center'}),
            ], style={'display': 'flex', 'alignItems': 'center', 'gap': '8px'})
        ], width=5),
        dbc.Col([
            dbc.Label("Alliance", style={'fontSize': '12px', 'fontWeight': '500'}),
            dbc.Select(
                id='waterfill-ally-dropdown',
                options=[],
                value=None,
                placeholder="All",
            )
        ], width=2),
        dbc.Col([
            dbc.Label("Fallback Poll", style={'fontSize': '12px', 'fontWeight': '500'}),
            dbc.Select(
                id='interval-dropdown',
                options=[
                    {'label': '2s', 'value': '2000'},
                    {'label': '5s', 'value': '5000'},
                    {'label': '10s', 'value': '10000'},
                    {'label': 'Off', 'value': '0'}
                ],
                value='5000',
            )
        ], width=2, id='interval-dropdown-col'),
    ], className="mb-3"),
    
    dbc.Tabs([
        dbc.Tab(create_economy_tab(), label="📊 Economy Overview", tab_id="tab-economy"),
        dbc.Tab(create_timing_tab(), label="⏱️ Timing Analysis", tab_id="tab-timing"),
        dbc.Tab(create_waterfill_tab(), label="🌊 Waterfill Analysis", tab_id="tab-waterfill"),
    ], id="tabs", active_tab="tab-economy", className="mb-3", persistence=True, persistence_type='local'),
    
    # Transfer Ledger Datagrid (below tabs, scoped to global filters by default)
    create_transfer_ledger_grid(),
    
    # Hidden slider for frame state (callbacks still use it)
    html.Div([
        dcc.Slider(id='wf-frame-slider', min=0, max=100, value=100, marks={}),
    ], style={'display': 'none'}),
    
    # Stores for waterfill state
    dcc.Store(id='wf-frames-store', data=[]),
    dcc.Store(id='wf-current-idx', data=0),
    dcc.Store(id='wf-is-playing', data=False),
    dcc.Interval(id='wf-play-interval', interval=200, disabled=True),
    
    # SocketIO handles real-time updates via JavaScript (see index_string)
    dcc.Store(id='ws-trigger', data=0),
    dcc.Store(id='team-names-store'),
    dcc.Store(id='available-frames-store'),
    # Fallback interval for when websocket is not available or disconnected
    dcc.Interval(id='fallback-refresh', interval=5000, n_intervals=0),
    
], fluid=True, style={
    'backgroundColor': COLORS['background'],
    'minHeight': '100vh',
    'fontFamily': 'JetBrains Mono, monospace'
})


# === Callbacks ===
@app.callback(
    Output('session-dropdown', 'options'),
    Output('session-dropdown', 'value'),
    Input('refresh-btn', 'n_clicks'),
    Input('session-type-filter', 'value'),
    State('session-dropdown', 'value'),
    prevent_initial_call=False
)
def update_sessions(n_clicks, type_filters, current_value):
    sessions = load_sessions()
    
    filtered_sessions = []
    for s in sessions:
        s_types = (s.get('session_types') or "").split(',')
        s_types = [t for t in s_types if t]
        
        # If no types recorded, we treat it as unknown/Alternate for filtering
        check_types = s_types if s_types else ["Alternate"]
        
        if any(t in type_filters for t in check_types):
            filtered_sessions.append(s)
    
    options = []
    for s in filtered_sessions:
        s_types = (s.get('session_types') or "").split(',')
        s_types = [t for t in s_types if t]
        type_str = f"[{'/'.join(s_types)}]" if s_types else "[?]"
        
        start_f = s['start_frame'] or 0
        end_f = s['end_frame'] or '?'
        teams = s['team_count'] or '?'
        
        label = f"#{s['id']} {type_str} F:{start_f}-{end_f} ({teams}T)"
        options.append({'label': label, 'value': str(s['id'])})
    
    if filtered_sessions:
        options.append({'label': '🌐 All Sessions (Global Analysis)', 'value': 'all'})
    
    # Default to first (latest) session, not 'all'
    current_str = str(current_value) if current_value is not None else None
    value = current_str if any(o['value'] == current_str for o in options) else (options[0]['value'] if options else None)
    return options, value


@app.callback(
    Output('team-checklist', 'options'),
    Output('team-checklist', 'value'),
    Output('team-names-store', 'data'),
    Output('available-frames-store', 'data'),
    Input('session-dropdown', 'value'),
    Input('refresh-btn', 'n_clicks'),
    State('team-checklist', 'value')
)
def update_teams(session_id, _refresh_clicks, current_teams):
    if not session_id:
        return [], [], {}, []

    # Handle session_id from dbc.Select (string)
    try:
        if session_id != 'all':
            session_id = int(session_id)
    except (ValueError, TypeError):
        pass

    # Use same session resolution logic as update_economy_charts
    actual_session_id = session_id
    if session_id == 'all':
        # For economy overview, "All Sessions" isn't very useful/performant
        # We'll just show a message or use the latest session
        sessions = load_sessions()
        if not sessions:
            return [], [], {}, []
        actual_session_id = sessions[0]['id']

    teams = load_teams(actual_session_id)
    names = load_team_names(actual_session_id)
    frames = load_available_frames(actual_session_id)
    
    options = [
        {'label': get_team_display_name(t, names), 'value': t}
        for t in teams
    ]
    
    valid_teams = [t for t in (current_teams or []) if t in teams]
    if not valid_teams and teams:
        valid_teams = [teams[0]]
    
    return options, valid_teams, names, frames


@app.callback(
    Output('global-time-slider', 'min'),
    Output('global-time-slider', 'max'),
    Output('global-time-slider', 'value'),
    Output('global-time-slider', 'marks'),
    Input('available-frames-store', 'data'),
    State('time-mode-select', 'value'),
    State('last-n-minutes-input', 'value'),
    State('global-time-slider', 'value')
)
def update_global_slider(frames, time_mode, last_n, current_value):
    if not frames:
        return 0, 60, [0, 60], {0: '0:00', 60: '60:00'}
    
    min_f = min(frames)
    max_f = max(frames)
    print(f"[Slider] frames={min_f}-{max_f}, mode={time_mode}, last_n={last_n}, current={current_value}")
    
    min_m = min_f / (30.0 * 60.0)
    max_m = max_f / (30.0 * 60.0)
    
    # Round to 1 decimal place for the slider
    min_m = round(min_m, 1)
    max_m = round(max_m, 1)
    
    if min_m == max_m:
        max_m += 1.0 # Ensure some range
        
    n_marks = 5
    step = (max_m - min_m) / n_marks if n_marks > 0 else 1
    marks = {round(min_m + i * step, 1): format_time_mmss((min_m + i * step) * 60) for i in range(n_marks + 1)}
    
    # Respect "Last N minutes" mode - don't reset slider to full range
    if time_mode == 'last' and last_n:
        try:
            last_n_val = float(last_n)
            start_m = max(min_m, max_m - last_n_val)
            return min_m, max_m, [start_m, max_m], marks
        except (ValueError, TypeError):
            pass
    
    # In "range" mode, try to preserve current selection if still valid
    if current_value and len(current_value) == 2:
        start, end = current_value
        # Clamp to new bounds
        start = max(min_m, min(max_m, start))
        end = max(min_m, min(max_m, end))
        if start < end:
            return min_m, max_m, [start, end], marks
    
    return min_m, max_m, [min_m, max_m], marks


@app.callback(
    Output('time-range-start-input', 'value'),
    Output('time-range-end-input', 'value'),
    Input('global-time-slider', 'value'),
    prevent_initial_call=True
)
def sync_inputs_from_slider(time_range):
    if not time_range:
        return '0:00', '60:00'
    start_min, end_min = time_range
    return format_time_mmss(start_min * 60), format_time_mmss(end_min * 60)


def parse_time_input(time_str):
    """Parse mm:ss or m:ss format to minutes (float)"""
    try:
        if ':' in time_str:
            parts = time_str.split(':')
            mins = int(parts[0])
            secs = int(parts[1]) if len(parts) > 1 else 0
            return mins + secs / 60.0
        else:
            return float(time_str)
    except (ValueError, IndexError):
        return None


@app.callback(
    Output('global-time-slider', 'value', allow_duplicate=True),
    Input('time-range-start-input', 'n_blur'),
    Input('time-range-end-input', 'n_blur'),
    State('time-range-start-input', 'value'),
    State('time-range-end-input', 'value'),
    State('global-time-slider', 'min'),
    State('global-time-slider', 'max'),
    prevent_initial_call=True
)
def sync_slider_from_inputs(start_blur, end_blur, start_val, end_val, slider_min, slider_max):
    start_min = parse_time_input(start_val)
    end_min = parse_time_input(end_val)
    
    if start_min is None:
        start_min = slider_min
    if end_min is None:
        end_min = slider_max
    
    start_min = max(slider_min, min(slider_max, start_min))
    end_min = max(slider_min, min(slider_max, end_min))
    
    if start_min > end_min:
        start_min, end_min = end_min, start_min
    
    return [start_min, end_min]


# Time mode toggle - show/hide controls (dropdown always visible)
@app.callback(
    Output('last-n-minutes-input', 'style'),
    Output('range-controls', 'style'),
    Input('time-mode-select', 'value'),
)
def toggle_time_mode_controls(mode):
    last_n_style = {'width': '60px', 'textAlign': 'center', 'fontFamily': 'JetBrains Mono, monospace', 'marginLeft': '6px'}
    if mode == 'last':
        return last_n_style, {'display': 'none'}
    else:
        last_n_style['display'] = 'none'
        return last_n_style, {'display': 'flex', 'flex': '1', 'alignItems': 'center'}


# Last N minutes mode - update slider to show last N minutes
@app.callback(
    Output('global-time-slider', 'value', allow_duplicate=True),
    Input('last-n-minutes-input', 'value'),
    Input('ws-trigger', 'data'),
    Input('refresh-btn', 'n_clicks'),
    State('time-mode-select', 'value'),
    State('global-time-slider', 'max'),
    prevent_initial_call=True
)
def update_slider_from_last_n(last_n, ws_trigger, _refresh_clicks, mode, slider_max):
    if mode != 'last' or not last_n:
        raise dash.exceptions.PreventUpdate
    
    try:
        last_n = float(last_n)
    except (ValueError, TypeError):
        last_n = 2
    
    end_min = slider_max or 60
    start_min = max(0, end_min - last_n)
    return [start_min, end_min]


@app.callback(
    Output('team-checklist', 'value', allow_duplicate=True),
    Input('select-all-btn', 'n_clicks'),
    State('team-checklist', 'options'),
    prevent_initial_call=True
)
def select_all_teams(n_clicks, options):
    if not options:
        return []
    return [o['value'] for o in options]


@app.callback(
    Output('team-checklist', 'value', allow_duplicate=True),
    Input('select-none-btn', 'n_clicks'),
    prevent_initial_call=True
)
def select_no_teams(n_clicks):
    return []


# SocketIO handles updates via JavaScript in index_string
# The refresh button click is triggered by socket.on('data_update')
# which updates the charts automatically


@app.callback(
    Output('resource-chart', 'figure'),
    Output('transfer-ledger', 'data'),
    Output('transfer-flow-chart', 'figure'),
    Output('explicit-transfers-chart', 'figure'),
    Output('total-sent-chart', 'figure'),
    Output('supply-demand-chart', 'figure'),
    Output('lift-chart', 'figure'),
    Input('ws-trigger', 'data'),
    Input('session-dropdown', 'value'),
    Input('team-checklist', 'value'),
    Input('resource-dropdown', 'value'),
    Input('waterfill-ally-dropdown', 'value'),
    Input('global-time-slider', 'value'),
    Input('refresh-btn', 'n_clicks'),
    State('team-names-store', 'data')
)
def update_economy_charts(ws_trigger, session_id, selected_teams, resource, ally_team, time_range, n_clicks, team_names):
    # Debug: log timing and inputs
    now = time.time()
    print(f"[Economy] Update triggered at {now:.2f}. Range={time_range}, Session={session_id}, Teams={len(selected_teams) if selected_teams else 0}")
    
    if not session_id:
        ef = create_empty_fig("Select a session", COLORS, 'empty-session')
        return ef, [], ef, ef, ef, ef, ef
    
    # Handle session_id from dbc.Select (string)
    try:
        if session_id != 'all':
            session_id = int(session_id)
    except (ValueError, TypeError):
        pass
    
    if session_id == 'all':
        # For economy overview, "All Sessions" isn't very useful/performant
        # We'll just show a message or use the latest session
        sessions = load_sessions()
        if not sessions:
            ef = create_empty_fig("No sessions found", COLORS, 'no-sessions')
            return ef, [], ef, ef, ef, ef, ef
        session_id = sessions[0]['id']
    
    # Load team names if not provided (fallback) - session_id is always a specific int at this point
    if not team_names:
        team_names = load_team_names(session_id)

    team_names = team_names or {}
    selected_teams = selected_teams or []
    
    # Handle ally_team from dropdown
    actual_ally_team = None if not ally_team or ally_team == 'all' else int(ally_team)
    
    eco_df = load_economy_data_multi(session_id, selected_teams, resource, time_range) if selected_teams else pd.DataFrame()
    transfers_df = load_transfers(session_id, resource, time_range=time_range)
    group_lift_df = load_group_lift_data(session_id, resource, ally_team=actual_ally_team, time_range=time_range)
    
    resource_fig = create_resource_levels_chart(eco_df, selected_teams, team_names, resource, COLORS)
    resource_fig.layout.uirevision = f'economy-levels-{session_id}-{resource}'
    
    ledger_data = create_transaction_ledger(transfers_df, team_names, selected_teams if selected_teams else None)
    
    flow_fig = create_transfer_flow_chart(transfers_df, team_names, selected_teams if selected_teams else None, COLORS)
    flow_fig.layout.uirevision = f'economy-flow-{session_id}-{resource}'
    
    explicit_fig = create_explicit_transfers_chart(transfers_df, team_names, COLORS)
    explicit_fig.layout.uirevision = f'economy-explicit-{session_id}-{resource}'
    
    sent_fig = create_total_sent_chart(transfers_df, team_names, COLORS)
    sent_fig.layout.uirevision = f'economy-sent-{session_id}-{resource}'
    
    supply_demand_fig = create_supply_demand_chart(group_lift_df, COLORS)
    supply_demand_fig.layout.uirevision = f'economy-supply-demand-{session_id}-{resource}'
    
    lift_fig = create_lift_chart(group_lift_df, COLORS)
    lift_fig.layout.uirevision = f'economy-lift-{session_id}-{resource}'
    
    return resource_fig, ledger_data, flow_fig, explicit_fig, sent_fig, supply_demand_fig, lift_fig


@app.callback(
    Output('timing-summary-table', 'children'),
    Output('timing-over-time-chart', 'figure'),
    Output('timing-histogram-chart', 'figure'),
    Output('timing-anomalies-table', 'children'),
    Input('ws-trigger', 'data'),
    Input('session-dropdown', 'value'),
    Input('global-time-slider', 'value'),
    Input('refresh-btn', 'n_clicks'),
)
def update_timing_charts(ws_trigger, session_id, time_range, n_clicks):
    # Handle session_id from dbc.Select (string)
    try:
        if session_id and session_id != 'all':
            session_id = int(session_id)
    except (ValueError, TypeError):
        pass
        
    actual_session_id = None if session_id == 'all' else session_id
    timing_summary = load_solver_timing_summary(actual_session_id, time_range=time_range)
    solver_df = load_solver_timing_data(actual_session_id, time_range=time_range)
    
    summary_table = create_timing_summary_table(timing_summary)
    time_chart = create_timing_over_time_chart(solver_df, COLORS)
    time_chart.layout.uirevision = f'timing-over-time-{actual_session_id}'
    
    hist_chart = create_timing_histograms(solver_df, COLORS)
    hist_chart.layout.uirevision = f'timing-histograms-{actual_session_id}'
    
    anomalies = create_timing_anomalies_table(solver_df)
    
    return summary_table, time_chart, hist_chart, anomalies


# === Waterfill Ally Dropdown ===
@app.callback(
    Output('waterfill-ally-dropdown', 'options'),
    Output('waterfill-ally-dropdown', 'value'),
    Input('session-dropdown', 'value'),
    State('waterfill-ally-dropdown', 'value'),
)
def update_ally_dropdown(session_id, current_value):
    if not session_id or session_id == 'all':
        return [{'label': 'All', 'value': 'all'}], 'all'
    
    # Handle session_id from dbc.Select (string)
    try:
        session_id = int(session_id)
    except (ValueError, TypeError):
        pass
    
    allies = load_ally_teams(session_id)
    if not allies:
        return [{'label': 'All', 'value': 'all'}], 'all'
    
    # Add "All" option at the start, then individual alliances
    options = [{'label': 'All', 'value': 'all'}]
    options += [{'label': f'Alliance {a}', 'value': str(a)} for a in allies]
    
    # Default to "All" unless user already selected something valid
    valid_values = ['all'] + [str(a) for a in allies]
    current_str = str(current_value) if current_value is not None else None
    value = current_str if current_str in valid_values else 'all'
    return options, value


# === Waterfill Frame Controls ===
@app.callback(
    Output('wf-frames-store', 'data'),
    Output('wf-frame-slider', 'max'),
    Output('wf-frame-slider', 'value'),
    Output('wf-frame-slider', 'marks'),
    Input('session-dropdown', 'value'),
    Input('resource-dropdown', 'value'),
    Input('waterfill-ally-dropdown', 'value'),
    Input('refresh-btn', 'n_clicks'),
    State('wf-frames-store', 'data'),
    State('wf-frame-slider', 'value'),
)
def update_waterfill_frames(session_id, resource, ally_team, _refresh_clicks, prev_frames, prev_value):
    if not session_id or session_id == 'all':
        return [], 0, 0, {}
    
    # Handle session_id from dbc.Select (string)
    try:
        session_id = int(session_id)
    except (ValueError, TypeError):
        pass
    
    if ally_team is None:
        return [], 0, 0, {}
    
    # ally_team comes as string from dbc.Select, "all" means no filter
    ally_team_int = None if ally_team == 'all' else None
    if ally_team != 'all':
        try:
            ally_team_int = int(ally_team)
        except (ValueError, TypeError):
            ally_team_int = None
    
    frames = load_waterfill_frame_range(session_id, resource, ally_team_int)
    if not frames:
        return [], 0, 0, {}
    
    max_idx = len(frames) - 1
    
    # Generate marks at regular intervals
    marks = {}
    if len(frames) > 1:
        step = max(1, len(frames) // 6)
        for i in range(0, len(frames), step):
            t_sec = frames[i] / 30.0
            marks[i] = f"{int(t_sec//60)}:{int(t_sec%60):02d}"
        marks[max_idx] = f"{int(frames[-1]/30.0//60)}:{int(frames[-1]/30.0%60):02d}"
    
    # If new frames added and we were at the end, stay at end (live mode)
    if prev_frames and prev_value == len(prev_frames) - 1 and len(frames) > len(prev_frames):
        new_value = max_idx
    elif prev_value is not None and prev_value <= max_idx:
        new_value = prev_value
    else:
        new_value = max_idx  # Default to latest
    
    return frames, max_idx, new_value, marks


@app.callback(
    Output('wf-frame-display', 'children'),
    Output('wf-time-display', 'children'),
    Output('wf-frame-total', 'children'),
    Output('wf-live-badge', 'style'),
    Input('wf-frame-slider', 'value'),
    State('wf-frames-store', 'data'),
)
def update_frame_display(idx, frames):
    if not frames or idx is None or idx >= len(frames):
        return "—", "—", "—", {'display': 'none'}
    
    frame = frames[idx]
    max_frame = frames[-1] if frames else 0
    t_sec = frame / 30.0
    time_str = f"{int(t_sec//60)}:{t_sec%60:05.2f}"
    is_live = idx == len(frames) - 1
    
    return str(frame), time_str, str(max_frame), {} if is_live else {'display': 'none'}


@app.callback(
    Output('wf-frame-slider', 'value', allow_duplicate=True),
    Input('wf-first-btn', 'n_clicks'),
    Input('wf-prev-btn', 'n_clicks'),
    Input('wf-next-btn', 'n_clicks'),
    Input('wf-last-btn', 'n_clicks'),
    Input('wf-play-interval', 'n_intervals'),
    State('wf-frame-slider', 'value'),
    State('wf-frame-slider', 'max'),
    State('wf-is-playing', 'data'),
    prevent_initial_call=True
)
def handle_frame_navigation(first, prev, next_btn, last, interval, current, max_val, is_playing):
    ctx = dash.callback_context
    if not ctx.triggered:
        return dash.no_update
    
    trigger = ctx.triggered[0]['prop_id'].split('.')[0]
    
    if trigger == 'wf-first-btn':
        return 0
    elif trigger == 'wf-prev-btn':
        return max(0, (current or 0) - 1)
    elif trigger == 'wf-next-btn':
        return min(max_val, (current or 0) + 1)
    elif trigger == 'wf-last-btn':
        return max_val
    elif trigger == 'wf-play-interval' and is_playing:
        new_val = (current or 0) + 1
        if new_val > max_val:
            return 0  # Loop back to start
        return new_val
    
    return dash.no_update


@app.callback(
    Output('wf-is-playing', 'data'),
    Output('wf-play-interval', 'disabled'),
    Output('wf-play-btn', 'children'),
    Input('wf-play-btn', 'n_clicks'),
    State('wf-is-playing', 'data'),
    prevent_initial_call=True
)
def toggle_play(n_clicks, is_playing):
    new_state = not is_playing
    return new_state, not new_state, "⏸" if new_state else "▶"


@app.callback(
    Output('waterfill-tank-chart', 'figure'),
    Output('transfer-matrix-chart', 'figure'),
    Output('conservation-chart', 'figure'),
    Input('wf-frame-slider', 'value'),
    Input('session-dropdown', 'value'),
    Input('resource-dropdown', 'value'),
    Input('waterfill-ally-dropdown', 'value'),
    State('wf-frames-store', 'data'),
)
def update_waterfill_charts(frame_idx, session_id, resource, ally_team, frames):
    if not session_id or session_id == 'all':
        ef = create_empty_fig("Select a session", COLORS, 'empty-waterfill')
        return ef, ef, ef
    
    # Handle session_id from dbc.Select (string)
    try:
        session_id = int(session_id)
    except (ValueError, TypeError):
        pass
    
    if ally_team is None:
        ef = create_empty_fig("Select an alliance", COLORS, 'no-ally')
        return ef, ef, ef
    
    # ally_team comes as string from dbc.Select, "all" means None for query
    ally_team_int = None if ally_team == 'all' else None
    if ally_team != 'all':
        try:
            ally_team_int = int(ally_team)
        except (ValueError, TypeError):
            ally_team_int = None
    
    if not frames or frame_idx is None or frame_idx >= len(frames):
        ef = create_empty_fig("No waterfill data available", COLORS, 'no-frame')
        return ef, ef, ef
    
    frame = frames[frame_idx]
    
    wf_df, inp_df, lift_df = load_waterfill_data(session_id, frame, resource, ally_team_int)
    tank_fig = create_waterfill_tank_diagram(wf_df, inp_df, lift_df, resource, frame, COLORS)
    tank_fig.layout.uirevision = f'waterfill-tank-{session_id}-{resource}-{ally_team}'
    
    transfer_matrix = load_transfer_matrix(session_id, frame, resource)
    matrix_fig = create_transfer_matrix_heatmap(transfer_matrix, resource, frame, COLORS)
    matrix_fig.layout.uirevision = f'transfer-matrix-{session_id}-{resource}-{ally_team}'
    
    output_df = load_output_data(session_id, resource)
    conservation_fig = create_conservation_chart(output_df, resource, COLORS)
    conservation_fig.layout.uirevision = f'conservation-{session_id}-{resource}-{ally_team}'
    
    return tank_fig, matrix_fig, conservation_fig


@app.callback(
    Output('fallback-refresh', 'interval'),
    Output('fallback-refresh', 'disabled'),
    Input('interval-dropdown', 'value')
)
def update_interval(value):
    print(f"[Interval] Dropdown value: {value!r}")
    try:
        val = int(value)
    except (ValueError, TypeError):
        val = 5000
        
    if val == 0:
        print("[Interval] Setting disabled=True")
        return 5000, True
    
    print(f"[Interval] Setting interval={val}, disabled=False")
    return val, False


# === Transfer Ledger Datagrid Callbacks ===
@app.callback(
    Output('ledger-session-dropdown', 'options'),
    Output('ledger-session-dropdown', 'value'),
    Input('session-dropdown', 'options'),
    State('ledger-session-dropdown', 'value'),
)
def sync_ledger_session_options(session_options, current_value):
    """Populate ledger session dropdown with same options + 'use global' default."""
    base_option = [{'label': '(use global)', 'value': ''}]
    if not session_options:
        return base_option, ''
    
    options = base_option + session_options
    
    # Preserve current value if still valid, otherwise default to '(use global)'
    valid_values = [o['value'] for o in options]
    if current_value in valid_values:
        return options, current_value
    return options, ''


@app.callback(
    Output('ledger-team-dropdown', 'options'),
    Input('team-checklist', 'options'),
)
def sync_ledger_team_options(team_options):
    """Populate ledger team filter dropdown from available teams."""
    if not team_options:
        return [{'label': 'All teams', 'value': ''}]
    return [{'label': 'All teams', 'value': ''}] + team_options


@app.callback(
    Output('ledger-session-dropdown', 'value', allow_duplicate=True),
    Output('ledger-resource-dropdown', 'value', allow_duplicate=True),
    Input('ledger-sync-btn', 'n_clicks'),
    prevent_initial_call=True
)
def sync_ledger_from_global(n_clicks):
    """Reset ledger filters to 'use global' when sync button clicked."""
    return '', ''


@app.callback(
    Output('transfer-ledger-grid', 'data'),
    Output('transfer-ledger-grid', 'page_count'),
    Output('ledger-showing-text', 'children'),
    Output('ledger-total-count', 'data'),
    Input('transfer-ledger-grid', 'page_current'),
    Input('ledger-session-dropdown', 'value'),
    Input('ledger-resource-dropdown', 'value'),
    Input('ledger-type-dropdown', 'value'),
    Input('ledger-team-dropdown', 'value'),
    Input('ledger-search-input', 'value'),
    Input('refresh-btn', 'n_clicks'),
    State('session-dropdown', 'value'),
    State('resource-dropdown', 'value'),
    State('global-time-slider', 'value'),
    State('team-names-store', 'data'),
)
def update_transfer_ledger(page, ledger_session, ledger_resource, transfer_type,
                           team_filter, search_term, _refresh,
                           global_session, global_resource, global_time_range, team_names):
    """Update the transfer ledger datagrid with pagination and filtering."""
    
    # Resolve effective session (ledger override or global)
    session_id = ledger_session if ledger_session else global_session
    if not session_id:
        return [], 1, "No session selected", 0
    
    try:
        if session_id and session_id != 'all':
            session_id = int(session_id)
    except (ValueError, TypeError):
        pass
    
    # Resolve effective resource
    resource = ledger_resource if ledger_resource else global_resource
    
    # Resolve team filter
    team_id = None
    if team_filter:
        try:
            team_id = int(team_filter)
        except (ValueError, TypeError):
            pass
    
    page_size = 50
    page = page or 0
    
    df, total_count = load_transfers_ledger(
        session_id=session_id,
        resource=resource,
        transfer_type=transfer_type,
        team_filter=team_id,
        search_term=search_term,
        time_range=global_time_range,
        page=page,
        page_size=page_size
    )
    
    if df.empty:
        return [], 1, "No transfers found", 0
    
    team_names = team_names or {}
    
    records = []
    for _, row in df.iterrows():
        sender_id = int(row['sender_team_id']) if pd.notna(row['sender_team_id']) else None
        receiver_id = int(row['receiver_team_id']) if pd.notna(row['receiver_team_id']) else None
        
        is_passive = row.get('transfer_type', 'passive') == 'passive'
        transfer_type_display = "🔄 Passive" if is_passive else "👆 Active"
        resource_display = "🪨 M" if row['resource'] == 'metal' else "⚡ E"
        
        if is_passive and row.get('source_table') == 'output':
            # Passive distribution from eco_team_output (per-team aggregate)
            team_name = row.get('sender_name') or get_team_display_name(sender_id, team_names)
            sent = float(row['amount']) if pd.notna(row['amount']) else 0
            received = float(row['untaxed']) if pd.notna(row['untaxed']) else 0
            
            if sent > 0.01:
                records.append({
                    'time': format_time_mmss(row['game_time']),
                    'frame': int(row['frame']),
                    'type': transfer_type_display,
                    'resource': resource_display,
                    'from': team_name,
                    'to': "(pool)",
                    'sent': f"{sent:.1f}",
                    'received': "—",
                    'tax': "—",
                })
            if received > 0.01:
                records.append({
                    'time': format_time_mmss(row['game_time']),
                    'frame': int(row['frame']),
                    'type': transfer_type_display,
                    'resource': resource_display,
                    'from': "(pool)",
                    'to': team_name,
                    'sent': "—",
                    'received': f"{received:.1f}",
                    'tax': "—",
                })
        else:
            # Active transfer (explicit sender → receiver)
            sender_name = row.get('sender_name') or get_team_display_name(sender_id, team_names)
            receiver_name = row.get('receiver_name') or get_team_display_name(receiver_id, team_names)
            
            records.append({
                'time': format_time_mmss(row['game_time']),
                'frame': int(row['frame']),
                'type': transfer_type_display,
                'resource': resource_display,
                'from': sender_name,
                'to': receiver_name,
                'sent': f"{float(row['amount']):.1f}",
                'received': f"{float(row['untaxed']):.1f}",
                'tax': f"{float(row['taxed']):.1f}",
            })
    
    page_count = max(1, (total_count + page_size - 1) // page_size)
    start = page * page_size + 1
    end = min((page + 1) * page_size, total_count)
    showing_text = f"Showing {start}-{end} of {total_count:,} transfers"
    
    return records, page_count, showing_text, total_count


# === Export to Markdown Callbacks ===
@app.callback(
    Output("download-economy-md", "data"),
    Input("export-economy-btn", "n_clicks"),
    State("session-dropdown", "value"),
    State("resource-dropdown", "value"),
    State("team-checklist", "value"),
    State("team-names-store", "data"),
    prevent_initial_call=True
)
def export_economy_markdown(n_clicks, session_id, resource, selected_teams, team_names):
    if not n_clicks or not session_id:
        return None

    team_names = team_names or {}
    selected_teams = selected_teams or []
    
    # Handle session_id from dbc.Select
    try:
        if session_id != 'all':
            session_id = int(session_id)
    except (ValueError, TypeError):
        pass
    
    if session_id == 'all':
        sessions = load_sessions()
        if sessions:
            session_id = sessions[0]['id']

    # Load actual data
    eco_df = load_economy_data_multi(session_id, selected_teams, resource) if selected_teams else pd.DataFrame()
    transfers_df = load_transfers(session_id, resource)
    group_lift_df = load_group_lift_data(session_id, resource)

    # Generate markdown content
    md_content = f"""# 📊 Economy Overview - {resource.title()}

**Session:** {session_id}
**Resource:** {resource.title()}
**Selected Teams:** {', '.join([get_team_display_name(t, team_names) for t in selected_teams]) or 'All'}

"""

    # Resource Levels chart
    if not eco_df.empty:
        resource_fig = create_resource_levels_chart(eco_df, selected_teams, team_names, resource, COLORS)
        md_content += "## Resource Levels\n\n"
        md_content += embed_chart_in_markdown(resource_fig, "Resource Levels", width=900, height=400)

    # Transfer Flow chart
    if not transfers_df.empty:
        flow_fig = create_transfer_flow_chart(transfers_df, team_names, selected_teams, COLORS)
        md_content += "## Transfer Flow\n\n"
        md_content += embed_chart_in_markdown(flow_fig, "Transfer Flow", width=900, height=400)
        
        # Total Sent chart
        sent_fig = create_total_sent_chart(transfers_df, team_names, COLORS)
        md_content += "## Total Sent by Team\n\n"
        md_content += embed_chart_in_markdown(sent_fig, "Total Sent", width=600, height=300)
        
        # Transfer Ledger table
        ledger_data = create_transaction_ledger(transfers_df, team_names, selected_teams)
        if ledger_data:
            md_content += "## Transfer Ledger\n\n"
            ledger_df = pd.DataFrame(ledger_data)
            md_content += dataframe_to_markdown_table(ledger_df)

    # Supply/Demand chart
    if not group_lift_df.empty:
        supply_demand_fig = create_supply_demand_chart(group_lift_df, COLORS)
        md_content += "## Supply vs Demand\n\n"
        md_content += embed_chart_in_markdown(supply_demand_fig, "Supply vs Demand", width=900, height=300)
        
        lift_fig = create_lift_chart(group_lift_df, COLORS)
        md_content += "## Waterfill Lift\n\n"
        md_content += embed_chart_in_markdown(lift_fig, "Waterfill Lift", width=900, height=300)

    md_content += """
---
*Generated by BAR Economy Audit Dashboard*
"""

    return dict(content=md_content, filename=f"economy_overview_{session_id}_{resource}.md")


@app.callback(
    Output("download-timing-md", "data"),
    Input("export-timing-btn", "n_clicks"),
    State("session-dropdown", "value"),
    prevent_initial_call=True
)
def export_timing_markdown(n_clicks, session_id):
    if not n_clicks:
        return None

    # Load timing data
    actual_session_id = None if session_id == 'all' else session_id
    timing_summary = load_solver_timing_summary(actual_session_id)
    solver_df = load_solver_timing_data(actual_session_id)

    md_content = f"""# ⏱️ Timing Analysis Report

**Session:** {session_id or 'All Sessions'}

## Overview
This report analyzes the performance of different economy processing components.

## Timing Summary
"""

    if not timing_summary.empty:
        # Check if we have source_path column to separate RE vs PE
        has_source = 'source_path' in timing_summary.columns
        
        if has_source:
            # Separate by source
            for source in timing_summary['source_path'].unique():
                source_df = timing_summary[timing_summary['source_path'] == source].copy()
                source_label = "ResourceExcess" if source == "RE" else "ProcessEconomy" if source == "PE" else source
                
                md_content += f"### {source_label}\n\n"
                md_content += "| Metric | Count | Avg (μs) | Min (μs) | Max (μs) |\n"
                md_content += "|--------|-------|----------|----------|----------|\n"
                
                for _, row in source_df.iterrows():
                    md_content += f"| {row['metric']} | {row['count']:,} | {row['avg_us']:.2f} | {row['min_us']:.2f} | {row['max_us']:.2f} |\n"
                
                md_content += "\n"
                
                # Mermaid bar chart for this source
                metrics = source_df['metric'].tolist()
                avgs = source_df['avg_us'].tolist()
                
                if metrics:
                    md_content += f"```mermaid\nxychart-beta\n"
                    md_content += f'    title "{source_label} Timing (μs)"\n'
                    md_content += '    x-axis [' + ', '.join([f'"{m}"' for m in metrics]) + ']\n'
                    md_content += '    y-axis "Time (μs)"\n'
                    md_content += '    bar [' + ', '.join([f'{v:.1f}' for v in avgs]) + ']\n'
                    md_content += "```\n\n"
        else:
            # No source distinction
            md_content += "| Metric | Count | Avg (μs) | Min (μs) | Max (μs) | First Frame | Last Frame |\n"
            md_content += "|--------|-------|----------|----------|----------|-------------|------------|\n"
            
            for _, row in timing_summary.iterrows():
                md_content += f"| {row['metric']} | {row['count']:,} | {row['avg_us']:.2f} | {row['min_us']:.2f} | {row['max_us']:.2f} | {int(row['first_frame'])} | {int(row['last_frame'])} |\n"
            
            md_content += "\n"
            
            # Mermaid bar chart
            metrics = timing_summary['metric'].tolist()
            avgs = timing_summary['avg_us'].tolist()
            
            if metrics:
                md_content += "```mermaid\nxychart-beta\n"
                md_content += '    title "Average Timing by Metric (μs)"\n'
                md_content += '    x-axis [' + ', '.join([f'"{m}"' for m in metrics]) + ']\n'
                md_content += '    y-axis "Time (μs)"\n'
                md_content += '    bar [' + ', '.join([f'{v:.1f}' for v in avgs]) + ']\n'
                md_content += "```\n\n"

    # Generate and embed actual charts as PNG
    md_content += "## Performance Charts\n\n"
    
    if not solver_df.empty:
        # Timing Over Time chart
        time_chart = create_timing_over_time_chart(solver_df, COLORS)
        md_content += "### Timing Over Time\n\n"
        md_content += embed_chart_in_markdown(time_chart, "Timing Over Time", width=1000, height=500)
        
        # Timing Distribution chart
        hist_chart = create_timing_histograms(solver_df, COLORS)
        md_content += "### Timing Distributions\n\n"
        md_content += embed_chart_in_markdown(hist_chart, "Timing Distributions", width=1000, height=400)
    
    md_content += """
## Key Metrics Explained
- **LuaMunge**: Time to prepare data before solver (Lua)
- **Solver**: Time in the waterfill algorithm
- **PostMunge**: Time to format results for engine
- **PolicyCache**: Time to update transfer policy cache
- **CppMunge**: Time for C++ to build team data tables
- **CppSetters**: Time for C++ to apply Lua results
- **LuaTotal**: Total Lua execution time
- **Overall**: Complete frame processing time

---
*Generated by BAR Economy Audit Dashboard*
"""

    return dict(content=md_content, filename=f"timing_analysis_{session_id or 'all'}.md")


@app.callback(
    Output("download-waterfill-md", "data"),
    Input("export-waterfill-btn", "n_clicks"),
    State("session-dropdown", "value"),
    State("resource-dropdown", "value"),
    State("waterfill-ally-dropdown", "value"),
    State("wf-frame-slider", "value"),
    State("wf-frames-store", "data"),
    prevent_initial_call=True
)
def export_waterfill_markdown(n_clicks, session_id, resource, ally_team, frame_idx, frames):
    if not n_clicks or not session_id:
        return None

    closest_frame = frames[frame_idx] if frames and frame_idx is not None and frame_idx < len(frames) else 0
    
    # Load actual data for this frame
    try:
        session_id_int = int(session_id) if session_id != 'all' else None
    except (ValueError, TypeError):
        session_id_int = None
    
    ally_team_int = None if ally_team == 'all' else None
    if ally_team and ally_team != 'all':
        try:
            ally_team_int = int(ally_team)
        except (ValueError, TypeError):
            pass
    
    wf_df, inp_df, lift_df = load_waterfill_data(session_id_int, closest_frame, resource, ally_team_int)
    transfer_matrix = load_transfer_matrix(session_id_int, closest_frame, resource)

    md_content = f"""# 🌊 Waterfill Analysis Report

**Session:** {session_id}
**Resource:** {resource.title()}
**Frame:** {closest_frame}
**Alliance:** {ally_team}

## Waterfill Algorithm Overview

The waterfill algorithm balances resources within team alliances through the following steps:

1. **Share Cursor**: Each team sets a threshold (`storage × shareSlider`) - resources above this get shared
2. **Lift**: A common "water level lift" is computed to balance supply = demand across the alliance
3. **Target**: Each team's target = `min(shareCursor + lift, storage)`
4. **Flow**: Resources flow from teams above target (senders) to teams below target (receivers)
5. **Tax**: Transfers above the tax-free threshold are taxed (resources destroyed)

**Key Invariant**: `Σ Received = Σ Sent - Tax`

"""
    
    # Add team data table
    if not wf_df.empty:
        wf = wf_df.merge(inp_df, on='team_id', how='left') if not inp_df.empty else wf_df
        md_content += "## Team Status at Frame " + str(closest_frame) + "\n\n"
        md_content += "| Team | Role | Current | Target | Storage | Delta |\n"
        md_content += "|------|------|---------|--------|---------|-------|\n"
        for _, row in wf.iterrows():
            delta = row.get('delta', 0) or 0
            delta_str = f"+{delta:.1f}" if delta >= 0 else f"{delta:.1f}"
            md_content += f"| T{int(row['team_id'])} | {row['role']} | {row['current']:.1f} | {row['target']:.1f} | {row.get('storage', 0):.0f} | {delta_str} |\n"
        md_content += "\n"
        
        # Add Mermaid flowchart for transfers
        if not transfer_matrix.empty and transfer_matrix.values.sum() > 0:
            md_content += "### Transfer Flow - Mermaid Diagram\n\n"
            md_content += "```mermaid\n"
            md_content += "flowchart LR\n"
            for sender in transfer_matrix.index:
                for receiver in transfer_matrix.columns:
                    amount = transfer_matrix.loc[sender, receiver]
                    if amount > 0:
                        md_content += f'    T{sender}["Team {sender}"] -->|{amount:.1f}| T{receiver}["Team {receiver}"]\n'
            md_content += "```\n\n"
    
    # Tank Diagram as PNG
    if not wf_df.empty:
        tank_fig = create_waterfill_tank_diagram(wf_df, inp_df, lift_df, resource, closest_frame, COLORS)
        md_content += "## Tank Diagram\n\n"
        md_content += embed_chart_in_markdown(tank_fig, "Tank Diagram", width=900, height=500)

    # Transfer Matrix as PNG
    if not transfer_matrix.empty:
        matrix_fig = create_transfer_matrix_heatmap(transfer_matrix, resource, closest_frame, COLORS)
        md_content += "## Transfer Matrix\n\n"
        md_content += embed_chart_in_markdown(matrix_fig, "Transfer Matrix", width=600, height=500)

    # Conservation chart
    if session_id_int:
        output_df = load_output_data(session_id_int, resource)
        if not output_df.empty:
            conservation_fig = create_conservation_chart(output_df, resource, COLORS)
            md_content += "## Conservation Verification\n\n"
            md_content += embed_chart_in_markdown(conservation_fig, "Conservation", width=900, height=400)

    md_content += """
---
*Generated by BAR Economy Audit Dashboard*
"""

    return dict(content=md_content, filename=f"waterfill_analysis_{session_id}_{resource}_frame_{closest_frame}.md")




# === Main ===
if __name__ == '__main__':
    # Debug: print registered callbacks
    print(f"\n[DEBUG] Registered callbacks: {len(app.callback_map)}")
    for key in list(app.callback_map.keys())[:5]:
        print(f"  - {key[:80]}...")
    
    print(f"\n{'='*60}")
    print("  BAR Economy Audit Dashboard")
    print(f"{'='*60}")
    print(f"  Database: {DB_PATH}")
    print(f"  Dashboard: http://localhost:8050")
    print(f"  Live updates: ws://<host>:{WS_PORT} (start parser to enable)")
    print(f"{'='*60}\n")
    
    app.run(debug=True, use_reloader=False, port=8050)
