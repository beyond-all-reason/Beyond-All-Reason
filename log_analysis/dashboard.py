#!/usr/bin/env python3
"""
BAR Economy Audit Dashboard
Real-time visualization of economy data using Dash + WebSockets
Includes: Economy Overview, Timing Analysis, Waterfill Analysis
"""

import os
import json
import sqlite3
import asyncio
import threading
import platform
from datetime import datetime

import dash
from dash import dcc, html, callback, Input, Output, State, dash_table
import dash_bootstrap_components as dbc
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np

import websockets
from websockets.sync.client import connect as ws_connect


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


# === Configuration ===
STATE_DIR = get_state_dir()
DB_PATH = os.path.join(STATE_DIR, "audit_logs.db")
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
    'metal': '#f0c674',
    'energy': '#81a2be',
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


def get_team_display_name(team_id, names_dict):
    if names_dict and team_id in names_dict:
        return names_dict[team_id]
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
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True, timeout=5)
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
        df = pd.read_sql_query(
            "SELECT DISTINCT team_id FROM eco_team_input WHERE session_id = ? ORDER BY team_id",
            conn, params=(session_id,)
        )
        return df['team_id'].tolist()
    finally:
        conn.close()


def load_economy_data_multi(session_id, team_ids, resource, time_range=None, limit=2000):
    conn = get_db_connection()
    if not conn or not team_ids:
        return pd.DataFrame()
    try:
        placeholders = ','.join(['?' for _ in team_ids])
        query = f"""SELECT o.frame, o.team_id, o.current, i.storage, o.source_path 
                   FROM eco_team_output o
                   JOIN eco_team_input i ON o.session_id = i.session_id 
                       AND o.frame = i.frame AND o.team_id = i.team_id AND o.resource = i.resource
                   WHERE o.session_id = ? AND o.team_id IN ({placeholders}) AND o.resource = ?"""
        params = [session_id] + list(team_ids) + [resource]
        
        if time_range:
            query += " AND o.frame >= ? AND o.frame <= ?"
            params.extend([time_range[0] * 60 * 30, time_range[1] * 60 * 30])
            
        query += " ORDER BY o.frame DESC LIMIT ?"
        params.append(limit * len(team_ids))
        
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
        query = "SELECT frame, game_time, sender_team_id, receiver_team_id, amount, untaxed, taxed FROM eco_transfer WHERE session_id = ? AND resource = ?"
        params = [session_id, resource]
        
        if team_ids:
            placeholders = ','.join(['?' for _ in team_ids])
            query += f" AND (sender_team_id IN ({placeholders}) OR receiver_team_id IN ({placeholders}))"
            params.extend(list(team_ids) + list(team_ids))
            
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([time_range[0] * 60 * 30, time_range[1] * 60 * 30])
            
        query += " ORDER BY frame DESC LIMIT ?"
        params.append(limit)
        
        df = pd.read_sql_query(query, conn, params=params)
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_group_lift_data(session_id, resource, time_range=None, limit=1000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        query = "SELECT frame, game_time, member_count, lift, total_demand, total_supply FROM eco_group_lift WHERE session_id = ? AND resource = ?"
        params = [session_id, resource]
        
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([time_range[0] * 60 * 30, time_range[1] * 60 * 30])
            
        query += " ORDER BY frame DESC LIMIT ?"
        params.append(limit)
        
        df = pd.read_sql_query(query, conn, params=params)
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_solver_timing_summary(session_id=None):
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
        """
        params = []
        if session_id:
            query += " WHERE session_id = ?"
            params.append(session_id)
        
        query += " GROUP BY source_path, metric ORDER BY source_path, avg_us DESC"
        
        df = pd.read_sql_query(query, conn, params=params)
        return df
    finally:
        conn.close()


def load_solver_timing_data(session_id=None, limit=5000):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        if session_id:
            df = pd.read_sql_query("""
                SELECT frame, source_path, metric, time_us FROM solver_audit
                WHERE session_id = ? AND metric != 'Overall'
                ORDER BY frame
            """, conn, params=(session_id,))
        else:
            df = pd.read_sql_query(f"""
                SELECT frame, source_path, metric, time_us FROM solver_audit
                WHERE frame > (SELECT MAX(frame) FROM solver_audit) - {limit}
                AND metric != 'Overall'
                ORDER BY frame
            """, conn)
        return df
    finally:
        conn.close()


def load_waterfill_data(session_id, frame, resource, ally_team=0):
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
    try:
        wf = pd.read_sql_query("""
            SELECT * FROM eco_team_waterfill 
            WHERE session_id = ? AND frame = ? AND resource = ? AND ally_team = ?
            ORDER BY team_id
        """, conn, params=(session_id, frame, resource, ally_team))
        
        inp = pd.read_sql_query("""
            SELECT team_id, storage, share_cursor FROM eco_team_input
            WHERE session_id = ? AND frame = ? AND resource = ? AND ally_team = ?
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
        query = "SELECT frame, resource, team_id, sent, received FROM eco_team_output WHERE session_id = ? AND resource = ?"
        params = [session_id, resource]
        
        if time_range:
            query += " AND frame >= ? AND frame <= ?"
            params.extend([time_range[0] * 60 * 30, time_range[1] * 60 * 30])
            
        query += " ORDER BY frame DESC LIMIT ?"
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
            SELECT frame, resource, 
                   SUM(sent) as total_sent, 
                   SUM(received) as total_received
            FROM eco_team_output
            WHERE session_id = ?
            GROUP BY frame, resource
            ORDER BY frame DESC LIMIT ?
        """, conn, params=(session_id, limit))
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_available_frames(session_id):
    conn = get_db_connection()
    if not conn:
        return []
    try:
        df = pd.read_sql_query("""
            SELECT DISTINCT frame FROM eco_team_waterfill 
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
            SELECT sender_team_id, receiver_team_id, SUM(amount) as total_amount
            FROM eco_transfer
            WHERE session_id = ? AND frame = ? AND resource = ?
            GROUP BY sender_team_id, receiver_team_id
        """, conn, params=(session_id, frame, resource))
        return df
    finally:
        conn.close()


# === Chart builders ===
def create_empty_fig(message, colors):
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
    )
    return fig


def create_resource_levels_chart(df, team_ids, team_names, resource, colors):
    if df.empty:
        return create_empty_fig("Select players to view resource levels", colors)
    
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
        transition=dict(duration=300, easing='cubic-in-out'),
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
        transition=dict(duration=300, easing='cubic-in-out'),
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
        transition=dict(duration=300, easing='cubic-in-out'),
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
        transition=dict(duration=300, easing='cubic-in-out'),
    )
    
    return fig


def create_supply_demand_chart(group_lift_df, colors):
    if group_lift_df.empty:
        return create_empty_fig("No data", colors)
    
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=group_lift_df['game_time'],
        y=group_lift_df['total_supply'],
        mode='lines',
        name='Supply',
        line=dict(color=colors['green'], width=2),
        hovertemplate='Supply: %{y:.0f}<extra></extra>'
    ))
    
    fig.add_trace(go.Scatter(
        x=group_lift_df['game_time'],
        y=group_lift_df['total_demand'],
        mode='lines',
        name='Demand',
        line=dict(color=colors['red'], width=2),
        hovertemplate='Demand: %{y:.0f}<extra></extra>'
    ))
    
    x_axis_config = get_time_axis_config(group_lift_df['game_time'], colors)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text'], size=10),
        title=dict(text="Supply / Demand — Alliance", font=dict(size=12)),
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
        mode='lines',
        name='Lift',
        line=dict(color=colors['cyan'], width=2),
        fill='tozeroy',
        fillcolor=f"rgba(136, 192, 208, 0.2)",
        hovertemplate='Lift: %{y:.1f}<extra></extra>'
    ))
    
    x_axis_config = get_time_axis_config(group_lift_df['game_time'], colors)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text'], size=10),
        title=dict(text="Waterfill Lift — Alliance", font=dict(size=12)),
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
    'CppMunge',
    'LuaMunge', 
    'Solver',
    'PostMunge',
    'PolicyCache',
    'LuaTotal',
    'CppSetters',
    'LuaSetters',
    'Overall',
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
    n_sources = len(source_paths)
    
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
            
            fig.add_trace(go.Scatter(
                x=mdf['frame'], y=mdf['time_us'],
                mode='lines', name=label,
                line=dict(color=color, width=1),
                opacity=0.6,
                hovertemplate=f'{label}: %{{y:.1f}}μs<extra></extra>',
                showlegend=(i == 1),
                legendgroup=sp,
            ), row=i, col=1)
            
            if len(mdf) > 30:
                rolling_avg = mdf['time_us'].rolling(window=30).mean()
                fig.add_trace(go.Scatter(
                    x=mdf['frame'], y=rolling_avg,
                    mode='lines', name=f'{label} (avg)',
                    line=dict(color=color, width=2, dash='solid'),
                    opacity=1.0,
                    hovertemplate=f'{label} avg: %{{y:.1f}}μs<extra></extra>',
                    showlegend=False,
                    legendgroup=sp,
                ), row=i, col=1)
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor=colors['card'],
        plot_bgcolor=colors['background'],
        font=dict(family='JetBrains Mono, monospace', color=colors['text']),
        height=150 * n_metrics,
        margin=dict(l=60, r=20, t=40, b=40),
        showlegend=True,
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1),
        uirevision='timing-chart',
        transition=dict(duration=300, easing='cubic-in-out'),
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
        transition=dict(duration=300, easing='cubic-in-out'),
    )
    
    fig.update_xaxes(gridcolor=colors['border'])
    fig.update_yaxes(gridcolor=colors['border'])
    
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
    
    wf = wf_df.merge(inp_df, on='team_id', how='left')
    n_teams = len(wf)
    
    lift = lift_df['lift'].iloc[0] if not lift_df.empty else 0
    supply = lift_df['total_supply'].iloc[0] if not lift_df.empty else 0
    demand = lift_df['total_demand'].iloc[0] if not lift_df.empty else 0
    
    max_storage = wf['storage'].max() if not wf.empty else 1000
    resource_color = colors['metal'] if resource == 'metal' else colors['energy']
    
    fig = go.Figure()
    
    for i, row in wf.iterrows():
        x_center = i * 1.2
        storage = row['storage']
        current = row['current']
        target = row['target']
        share_cursor = row['share_cursor'] if pd.notna(row.get('share_cursor')) else 0
        role = row['role']
        
        height_scale = storage / max_storage if max_storage > 0 else 1
        tank_height = 5 * height_scale
        tank_width = 0.7
        
        fig.add_shape(
            type="rect",
            x0=x_center - tank_width/2, y0=0,
            x1=x_center + tank_width/2, y1=tank_height,
            line=dict(color='#e0e0e0', width=2),
            fillcolor='rgba(0,0,0,0)'
        )
        
        fill_height = (current / storage * tank_height) if storage > 0 else 0
        fig.add_shape(
            type="rect",
            x0=x_center - tank_width/2 + 0.02, y0=0.02,
            x1=x_center + tank_width/2 - 0.02, y1=fill_height,
            fillcolor=resource_color,
            opacity=0.7,
            line=dict(width=0)
        )
        
        target_y = (target / storage * tank_height) if storage > 0 else 0
        fig.add_shape(
            type="line",
            x0=x_center - tank_width/2 - 0.1, y0=target_y,
            x1=x_center + tank_width/2 + 0.1, y1=target_y,
            line=dict(color='white', width=2, dash='dash')
        )
        
        cursor_y = (share_cursor / storage * tank_height) if storage > 0 else 0
        fig.add_shape(
            type="line",
            x0=x_center - tank_width/2, y0=cursor_y,
            x1=x_center + tank_width/2, y1=cursor_y,
            line=dict(color='#ff9800', width=1.5, dash='dot')
        )
        
        role_colors = {'sender': SENDER_COLOR, 'receiver': RECEIVER_COLOR, 'neutral': NEUTRAL_COLOR}
        role_color = role_colors.get(role, NEUTRAL_COLOR)
        
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
        height=400
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
            [class*="-menu"] {
                background-color: #1c2128 !important;
                border: 1px solid #30363d !important;
            }
            [class*="-option"] {
                background-color: #1c2128 !important;
                color: #e6edf3 !important;
                font-size: 14px !important;
            }
            [class*="-option"]:hover {
                background-color: #30363d !important;
                color: #ffffff !important;
            }
            [class*="-option"][aria-selected="true"] {
                background-color: #21262d !important;
                color: #79c0ff !important;
            }
            [class*="-control"] {
                background-color: #161b22 !important;
                border-color: #30363d !important;
                min-height: 38px !important;
            }
            [class*="-control"]:hover {
                border-color: #58a6ff !important;
            }
            [class*="-singleValue"], [class*="-placeholder"], [class*="-multiValue"] {
                color: #e6edf3 !important;
                font-size: 14px !important;
                font-weight: 500 !important;
            }
            [class*="-placeholder"] {
                color: #8b949e !important;
                font-weight: 400 !important;
            }
            [class*="-input"] input {
                color: #ffffff !important;
                font-size: 14px !important;
            }
            [class*="-indicatorContainer"] {
                color: #8b949e !important;
            }
            [class*="-indicatorContainer"]:hover {
                color: #e6edf3 !important;
            }
            [class*="-multiValue"] {
                background-color: #30363d !important;
            }
            [class*="-multiValueLabel"] {
                color: #e6edf3 !important;
                font-size: 13px !important;
            }
            [class*="-multiValueRemove"]:hover {
                background-color: #bf616a !important;
                color: white !important;
            }
            
            .team-checklist .form-check {
                display: inline-block;
                margin-right: 12px;
                margin-bottom: 4px;
            }
            .team-checklist .form-check-input {
                background-color: #161b22;
                border-color: #30363d;
            }
            .team-checklist .form-check-input:checked {
                background-color: #58a6ff;
                border-color: #58a6ff;
            }
            .team-checklist .form-check-label {
                color: #c9d1d9;
                font-size: 12px;
            }
            
            .dash-table-container .dash-spreadsheet-container .dash-spreadsheet-inner td {
                background-color: #161b22 !important;
                color: #c9d1d9 !important;
                border-color: #30363d !important;
            }
            .dash-table-container .dash-spreadsheet-container .dash-spreadsheet-inner th {
                background-color: #0d1117 !important;
                color: #8b949e !important;
                border-color: #30363d !important;
            }
            
            .nav-tabs .nav-link {
                color: #8b949e !important;
                border: none !important;
                background: transparent !important;
            }
            .nav-tabs .nav-link.active {
                color: #58a6ff !important;
                border-bottom: 2px solid #58a6ff !important;
                background: transparent !important;
            }
            .nav-tabs .nav-link:hover {
                color: #c9d1d9 !important;
            }
            
            .explanation-card {
                background-color: #161b22;
                border: 1px solid #30363d;
                border-radius: 6px;
                padding: 16px;
                margin-bottom: 16px;
            }
            .explanation-card h4 {
                color: #58a6ff;
                margin-bottom: 12px;
            }
            .explanation-card p, .explanation-card li {
                color: #c9d1d9;
                font-size: 14px;
                line-height: 1.6;
            }
            .explanation-card code {
                background-color: #21262d;
                padding: 2px 6px;
                border-radius: 3px;
                color: #f0c674;
            }
            
            .time-input:focus {
                outline: none;
                border-color: #58a6ff !important;
                box-shadow: 0 0 0 2px rgba(88, 166, 255, 0.2);
            }
            .time-input::placeholder {
                color: #8b949e;
            }
        </style>
    </head>
    <body>
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
    </body>
</html>
'''


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
                dbc.Label("Players (select for per-player charts)", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
                html.Div([
                    dbc.Button("All", id="select-all-btn", color="secondary", size="sm", className="me-2"),
                    dbc.Button("None", id="select-none-btn", color="secondary", size="sm", className="me-3"),
                    dcc.Checklist(
                        id='team-checklist',
                        options=[],
                        value=[],
                        inline=True,
                        className="team-checklist d-inline",
                        labelStyle={'marginRight': '15px'}
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
                    type='circle', color=COLORS['accent']
                ),
                dcc.Loading(
                    dcc.Graph(id='transfer-flow-chart', style={'height': '250px', 'marginTop': '10px'}),
                    type='circle', color=COLORS['accent']
                ),
                dcc.Loading(
                    dcc.Graph(id='explicit-transfers-chart', style={'height': '250px', 'marginTop': '10px'}),
                    type='circle', color=COLORS['accent']
                ),
            ], width=8),
            
            dbc.Col([
                dcc.Loading(
                    dcc.Graph(id='total-sent-chart', style={'height': '180px'}),
                    type='circle', color=COLORS['accent']
                ),
                dcc.Loading(
                    dcc.Graph(id='supply-demand-chart', style={'height': '180px', 'marginTop': '8px'}),
                    type='circle', color=COLORS['accent']
                ),
                dcc.Loading(
                    dcc.Graph(id='lift-chart', style={'height': '150px', 'marginTop': '8px'}),
                    type='circle', color=COLORS['accent']
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
- **CppMunge**: C++ time to prepare data for Lua
- **Solver**: Time in the waterfill algorithm
- **PostMunge**: Time to format and apply results
- **PolicyCache**: Time to update transfer policy cache
- **LuaTotal**: Total Lua processing time

**Color coding:** 🟢 Green = faster, 🔴 Red = slower (in Δ columns)
"""),
            ], width=10),
            dbc.Col([
                dbc.Button("📄 Export to Markdown", id="export-timing-btn", color="primary", size="sm"),
                dcc.Download(id="download-timing-md")
            ], width=2, className="text-end"),
        ], className="mb-3"),

        html.H5("📊 Timing Summary", style={'color': COLORS['text'], 'marginBottom': '15px'}),
        html.Div(id='timing-summary-table'),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        create_explanation_card("📈 Timing Over Time", """
Individual charts for each metric help identify anomalies and performance spikes.
- **Solid line**: Raw timing values
- **White line**: 30-frame rolling average  
- **Green dashed**: Average value
- **Yellow dotted**: 95th percentile
"""),
        dcc.Loading(
            dcc.Graph(id='timing-over-time-chart'),
            type='circle', color=COLORS['accent']
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
            type='circle', color=COLORS['accent']
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        html.H5("🚨 Anomaly Detection (>99th percentile)", style={'color': COLORS['text'], 'marginBottom': '15px'}),
        html.Div(id='timing-anomalies-table'),
    ])


# === Tab: Waterfill Analysis ===
def create_waterfill_tab():
    return html.Div([
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

        html.H5("🏗️ Tank Diagram", style={'color': COLORS['text'], 'marginBottom': '15px'}),
        html.P("Visual representation of each team's resource levels, targets, and roles:",
               style={'color': COLORS['text_muted'], 'fontSize': '13px'}),
        dcc.Loading(
            dcc.Graph(id='waterfill-tank-chart'),
            type='circle', color=COLORS['accent']
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        html.H5("🔄 Transfer Matrix", style={'color': COLORS['text'], 'marginBottom': '15px'}),
        html.P("Who sent resources to whom? Heatmap showing flow between teams:",
               style={'color': COLORS['text_muted'], 'fontSize': '13px'}),
        dcc.Loading(
            dcc.Graph(id='transfer-matrix-chart'),
            type='circle', color=COLORS['accent']
        ),
        
        html.Hr(style={'borderColor': COLORS['border'], 'margin': '20px 0'}),
        
        create_explanation_card("🔬 Conservation Verification", """
The solver must maintain the conservation law: **Total Received = Total Sent - Tax**.

This chart verifies that the invariant holds across all frames. Any violations indicate bugs in the solver.
"""),
        dcc.Loading(
            dcc.Graph(id='conservation-chart'),
            type='circle', color=COLORS['accent']
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
            dbc.Badge("● LIVE", color="success", className="me-2", id="live-indicator"),
            dbc.Button("↻ Refresh", id="refresh-btn", color="secondary", size="sm", className="me-2"),
        ], width=6, className="text-end d-flex align-items-center justify-content-end")
    ], className="mb-3 pt-3"),
    
    dbc.Row([
        dbc.Col([
            dbc.Label("Session Filters", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
            dcc.Checklist(
                id='session-type-filter',
                options=[
                    {'label': ' RE (ResourceExcess)', 'value': 'RE'},
                    {'label': ' PE (ProcessEconomy)', 'value': 'PE'},
                    {'label': ' Other', 'value': 'Alternate'}
                ],
                value=['RE', 'PE', 'Alternate'],
                inline=True,
                className="team-checklist",
                labelStyle={'marginRight': '15px'}
            )
        ], width=12),
    ], className="mb-2"),
    
    dbc.Row([
        dbc.Col([
            dbc.Label("Session", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
            dcc.Dropdown(
                id='session-dropdown',
                placeholder="Select session...",
                className="dash-dropdown"
            )
        ], width=3),
        dbc.Col([
            dbc.Label("Resource", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
            dcc.Dropdown(
                id='resource-dropdown',
                options=[
                    {'label': '🪨 Metal', 'value': 'metal'},
                    {'label': '⚡ Energy', 'value': 'energy'}
                ],
                value='metal',
                clearable=False,
                className="dash-dropdown"
            )
        ], width=2),
        dbc.Col([
            dbc.Label("Time Range", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
            html.Div([
                dbc.Input(
                    id='time-range-start-input',
                    type='text',
                    value='0:00',
                    placeholder='0:00',
                    className='time-input',
                    style={
                        'width': '65px',
                        'backgroundColor': COLORS['card'],
                        'border': f"1px solid {COLORS['border']}",
                        'color': COLORS['text'],
                        'borderRadius': '4px',
                        'padding': '6px 8px',
                        'fontSize': '13px',
                        'textAlign': 'center',
                        'fontFamily': 'JetBrains Mono, monospace',
                    }
                ),
                html.Div([
                    dcc.RangeSlider(
                        id='global-time-slider',
                        min=0, max=60, step=0.1, value=[0, 60],
                        marks=None,
                        tooltip={"placement": "bottom", "always_visible": False},
                    )
                ], style={'flex': '1', 'margin': '0 12px'}),
                dbc.Input(
                    id='time-range-end-input',
                    type='text',
                    value='60:00',
                    placeholder='60:00',
                    className='time-input',
                    style={
                        'width': '65px',
                        'backgroundColor': COLORS['card'],
                        'border': f"1px solid {COLORS['border']}",
                        'color': COLORS['text'],
                        'borderRadius': '4px',
                        'padding': '6px 8px',
                        'fontSize': '13px',
                        'textAlign': 'center',
                        'fontFamily': 'JetBrains Mono, monospace',
                    }
                ),
            ], style={'display': 'flex', 'alignItems': 'center'})
        ], width=5),
        dbc.Col([
            dbc.Label("Alliance", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
            dcc.Dropdown(
                id='waterfill-ally-dropdown',
                options=[{'label': f'Alliance {i}', 'value': i} for i in range(10)],
                value=0,
                clearable=False,
                className="dash-dropdown"
            )
        ], width=1, id='waterfill-ally-col', style={'display': 'none'}),
        dbc.Col([
            dbc.Label("Update", style={'color': COLORS['text'], 'fontSize': '12px', 'fontWeight': '500'}),
            dcc.Dropdown(
                id='interval-dropdown',
                options=[
                    {'label': '1s', 'value': 1000},
                    {'label': '2s', 'value': 2000},
                    {'label': '5s', 'value': 5000},
                    {'label': 'Off', 'value': 0}
                ],
                value=2000,
                clearable=False,
                className="dash-dropdown"
            )
        ], width=2),
    ], className="mb-3"),
    
    dbc.Tabs([
        dbc.Tab(create_economy_tab(), label="📊 Economy Overview", tab_id="tab-economy"),
        dbc.Tab(create_timing_tab(), label="⏱️ Timing Analysis", tab_id="tab-timing"),
        dbc.Tab(create_waterfill_tab(), label="🌊 Waterfill Analysis", tab_id="tab-waterfill"),
    ], id="tabs", active_tab="tab-economy", className="mb-3"),
    
    html.Div(id='ws-status', style={'display': 'none'}),
    dcc.Interval(id='auto-refresh', interval=2000, n_intervals=0),
    dcc.Store(id='ws-data-store'),
    dcc.Store(id='team-names-store'),
    dcc.Store(id='available-frames-store'),
    
], fluid=True, style={
    'backgroundColor': COLORS['background'],
    'minHeight': '100vh',
    'fontFamily': 'JetBrains Mono, monospace'
})


# === Callbacks ===
@callback(
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
    if filtered_sessions:
        options.append({'label': '🌐 All Sessions (Global Analysis)', 'value': 'all'})

    for s in filtered_sessions:
        s_types = (s.get('session_types') or "").split(',')
        s_types = [t for t in s_types if t]
        type_str = f"[{'/'.join(s_types)}]" if s_types else "[?]"
        
        start_f = s['start_frame'] or 0
        end_f = s['end_frame'] or '?'
        teams = s['team_count'] or '?'
        
        label = f"#{s['id']} {type_str} F:{start_f}-{end_f} ({teams}T)"
        options.append({'label': label, 'value': s['id']})
    
    value = current_value if any(o['value'] == current_value for o in options) else (options[0]['value'] if options else None)
    return options, value


@callback(
    Output('team-checklist', 'options'),
    Output('team-checklist', 'value'),
    Output('team-names-store', 'data'),
    Output('available-frames-store', 'data'),
    Input('session-dropdown', 'value'),
    State('team-checklist', 'value')
)
def update_teams(session_id, current_teams):
    if not session_id:
        return [], [], {}, []
    
    teams = load_teams(session_id)
    names = load_team_names(session_id)
    frames = load_available_frames(session_id)
    
    options = [
        {'label': get_team_display_name(t, names), 'value': t}
        for t in teams
    ]
    
    valid_teams = [t for t in (current_teams or []) if t in teams]
    if not valid_teams and teams:
        valid_teams = [teams[0]]
    
    return options, valid_teams, names, frames


@callback(
    Output('global-time-slider', 'min'),
    Output('global-time-slider', 'max'),
    Output('global-time-slider', 'value'),
    Output('global-time-slider', 'marks'),
    Input('available-frames-store', 'data')
)
def update_global_slider(frames):
    if not frames:
        return 0, 60, [0, 60], {0: '0:00', 60: '60:00'}
    
    min_f = min(frames)
    max_f = max(frames)
    
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
    
    return min_m, max_m, [min_m, max_m], marks


@callback(
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


@callback(
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


@callback(
    Output('team-checklist', 'value', allow_duplicate=True),
    Input('select-all-btn', 'n_clicks'),
    State('team-checklist', 'options'),
    prevent_initial_call=True
)
def select_all_teams(n_clicks, options):
    if not options:
        return []
    return [o['value'] for o in options]


@callback(
    Output('team-checklist', 'value', allow_duplicate=True),
    Input('select-none-btn', 'n_clicks'),
    prevent_initial_call=True
)
def select_no_teams(n_clicks):
    return []


@callback(
    Output('resource-chart', 'figure'),
    Output('transfer-ledger', 'data'),
    Output('transfer-flow-chart', 'figure'),
    Output('explicit-transfers-chart', 'figure'),
    Output('total-sent-chart', 'figure'),
    Output('supply-demand-chart', 'figure'),
    Output('lift-chart', 'figure'),
    Input('auto-refresh', 'n_intervals'),
    Input('session-dropdown', 'value'),
    Input('team-checklist', 'value'),
    Input('resource-dropdown', 'value'),
    Input('global-time-slider', 'value'),
    Input('refresh-btn', 'n_clicks'),
    State('team-names-store', 'data')
)
def update_economy_charts(n_intervals, session_id, selected_teams, resource, time_range, n_clicks, team_names):
    if not session_id:
        ef = create_empty_fig("Select a session", COLORS)
        return ef, [], ef, ef, ef, ef, ef
    
    if session_id == 'all':
        # For economy overview, "All Sessions" isn't very useful/performant
        # We'll just show a message or use the latest session
        sessions = load_sessions()
        if not sessions:
            ef = create_empty_fig("No sessions found", COLORS)
            return ef, [], ef, ef, ef, ef, ef
        session_id = sessions[0]['id']
    
    team_names = team_names or {}
    selected_teams = selected_teams or []
    
    eco_df = load_economy_data_multi(session_id, selected_teams, resource, time_range) if selected_teams else pd.DataFrame()
    transfers_df = load_transfers(session_id, resource, time_range=time_range)
    group_lift_df = load_group_lift_data(session_id, resource, time_range=time_range)
    
    resource_fig = create_resource_levels_chart(eco_df, selected_teams, team_names, resource, COLORS)
    ledger_data = create_transaction_ledger(transfers_df, team_names, selected_teams if selected_teams else None)
    flow_fig = create_transfer_flow_chart(transfers_df, team_names, selected_teams if selected_teams else None, COLORS)
    explicit_fig = create_explicit_transfers_chart(transfers_df, team_names, COLORS)
    sent_fig = create_total_sent_chart(transfers_df, team_names, COLORS)
    supply_demand_fig = create_supply_demand_chart(group_lift_df, COLORS)
    lift_fig = create_lift_chart(group_lift_df, COLORS)
    
    return resource_fig, ledger_data, flow_fig, explicit_fig, sent_fig, supply_demand_fig, lift_fig


@callback(
    Output('timing-summary-table', 'children'),
    Output('timing-over-time-chart', 'figure'),
    Output('timing-histogram-chart', 'figure'),
    Output('timing-anomalies-table', 'children'),
    Input('auto-refresh', 'n_intervals'),
    Input('session-dropdown', 'value'),
    Input('refresh-btn', 'n_clicks'),
)
def update_timing_charts(n_intervals, session_id, n_clicks):
    actual_session_id = None if session_id == 'all' else session_id
    timing_summary = load_solver_timing_summary(actual_session_id)
    solver_df = load_solver_timing_data(actual_session_id)
    
    summary_table = create_timing_summary_table(timing_summary)
    time_chart = create_timing_over_time_chart(solver_df, COLORS)
    hist_chart = create_timing_histograms(solver_df, COLORS)
    anomalies = create_timing_anomalies_table(solver_df)
    
    return summary_table, time_chart, hist_chart, anomalies


@callback(
    Output('waterfill-tank-chart', 'figure'),
    Output('transfer-matrix-chart', 'figure'),
    Output('conservation-chart', 'figure'),
    Input('session-dropdown', 'value'),
    Input('resource-dropdown', 'value'),
    Input('global-time-slider', 'value'),
    Input('waterfill-ally-dropdown', 'value'),
    Input('available-frames-store', 'data'),
    Input('refresh-btn', 'n_clicks'),
)
def update_waterfill_charts(session_id, resource, time_range, ally_team, available_frames, n_clicks):
    if not session_id:
        ef = create_empty_fig("Select a session", COLORS)
        return ef, ef, ef
    
    # Use the end of the time range to pick the frame for detailed waterfill analysis
    if time_range and available_frames:
        end_minutes = time_range[1]
        end_frame = int(end_minutes * 60 * 30)
        # Find the closest available frame
        closest_frame = min(available_frames, key=lambda f: abs(f - end_frame)) if available_frames else end_frame
    else:
        closest_frame = max(available_frames) if available_frames else 0
    
    if not closest_frame:
        ef = create_empty_fig("No frame data available", COLORS)
        return ef, ef, ef
    
    wf_df, inp_df, lift_df = load_waterfill_data(session_id, closest_frame, resource, ally_team)
    tank_fig = create_waterfill_tank_diagram(wf_df, inp_df, lift_df, resource, closest_frame, COLORS)
    
    transfer_matrix = load_transfer_matrix(session_id, closest_frame, resource)
    matrix_fig = create_transfer_matrix_heatmap(transfer_matrix, resource, closest_frame, COLORS)
    
    output_df = load_output_data(session_id, resource)
    conservation_fig = create_conservation_chart(output_df, resource, COLORS)
    
    return tank_fig, matrix_fig, conservation_fig


@callback(
    Output('waterfill-ally-col', 'style'),
    Input('tabs', 'active_tab')
)
def toggle_tab_controls(active_tab):
    if active_tab == 'tab-waterfill':
        return {}
    return {'display': 'none'}

@callback(
    Output('auto-refresh', 'interval'),
    Output('auto-refresh', 'disabled'),
    Input('interval-dropdown', 'value')
)
def update_interval(value):
    if value == 0:
        return 1000, True
    return value, False


# === Export to Markdown Callbacks ===
@callback(
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

    # Generate markdown content
    md_content = f"""# 📊 Economy Overview - {resource.title()}

**Session:** {session_id}
**Resource:** {resource.title()}
**Selected Teams:** {', '.join([get_team_display_name(t, team_names) for t in (selected_teams or [])]) or 'All'}

## Resource Levels
- Real-time resource levels for selected teams
- Shows current levels vs storage capacity
- Time-based visualization

## Transfer Flow
- Net transfer flow between teams (+ receiving / − sending)
- Binned over time for clarity
- Shows redistribution patterns

## Explicit Transfers
- Total transfers sent and received
- Orange bars: total sent
- Green bars: received amount
- Shows transfer activity over time

## Summary Statistics
- Total sent by each team (horizontal bar chart)
- Supply vs demand balance
- Waterfill lift values

## Transfer Ledger
Recent transfer transactions between teams.

---
*Generated by BAR Economy Audit Dashboard*
"""

    return dict(content=md_content, filename=f"economy_overview_{session_id}_{resource}.md")


@callback(
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
        md_content += "| Metric | Count | Avg (μs) | Min (μs) | Max (μs) | First Frame | Last Frame |\n"
        md_content += "|--------|-------|----------|----------|----------|-------------|------------|\n"

        for _, row in timing_summary.iterrows():
            md_content += f"| {row['metric']} | {row['count']:,} | {row['avg_us']:.2f} | {row['min_us']:.2f} | {row['max_us']:.2f} | {int(row['first_frame'])} | {int(row['last_frame'])} |\n"

        md_content += "\n"

    md_content += """## Performance Analysis

### Timing Over Time
- Individual charts for each metric showing performance over game time
- Solid lines: raw timing values
- White lines: 30-frame rolling averages
- Green dashed: average values
- Yellow dotted: 95th percentiles

### Timing Distributions
- Histograms showing the distribution of timing values per metric
- Green lines: mean values
- Yellow lines: median values
- Wide distributions indicate inconsistent performance

## Anomaly Detection
Timing values exceeding the 99th percentile threshold.

### Key Metrics Explained
- **PreMunge**: Time to prepare data before solver
- **Solver**: Time in the waterfill algorithm
- **PostMunge**: Time to format results
- **PolicyCache**: Time to update transfer policy cache
- **CppSetters**: Time in C++ to apply Lua results

---
*Generated by BAR Economy Audit Dashboard*
"""

    return dict(content=md_content, filename=f"timing_analysis_{session_id or 'all'}.md")


@callback(
    Output("download-waterfill-md", "data"),
    Input("export-waterfill-btn", "n_clicks"),
    State("session-dropdown", "value"),
    State("resource-dropdown", "value"),
    State("global-time-slider", "value"),
    State("waterfill-ally-dropdown", "value"),
    State("available-frames-store", "data"),
    prevent_initial_call=True
)
def export_waterfill_markdown(n_clicks, session_id, resource, time_range, ally_team, available_frames):
    if not n_clicks or not session_id:
        return None

    # Determine the frame for analysis
    if time_range and available_frames:
        end_minutes = time_range[1]
        end_frame = int(end_minutes * 60 * 30)
        closest_frame = min(available_frames, key=lambda f: abs(f - end_frame)) if available_frames else end_frame
    else:
        closest_frame = max(available_frames) if available_frames else 0

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

## Tank Diagram
Visual representation showing:
- Each team's current resource level (filled portion)
- Target levels (dashed white lines)
- Share cursors (dotted orange lines)
- Team roles: Sender (red), Receiver (green), Neutral (gray)

## Transfer Matrix
Heatmap showing resource flow between teams:
- Rows: sending teams
- Columns: receiving teams
- Cell values: amount transferred
- Darker colors indicate higher transfer amounts

## Conservation Verification
Chart verifying the conservation law across all frames:
- Tax collected (sent - received)
- Conservation errors
- Green status: invariant holds
- Red status: violations detected

## Analysis Insights
- **Balance**: How evenly resources are distributed
- **Efficiency**: Transfer amounts vs tax paid
- **Stability**: How consistently the algorithm maintains balance

---
*Generated by BAR Economy Audit Dashboard*
"""

    return dict(content=md_content, filename=f"waterfill_analysis_{session_id}_{resource}_frame_{closest_frame}.md")


# === WebSocket server for real-time push ===
ws_clients = set()


async def ws_handler(websocket):
    ws_clients.add(websocket)
    try:
        async for message in websocket:
            pass
    except websockets.exceptions.ConnectionClosedError:
        pass
    finally:
        ws_clients.discard(websocket)


async def broadcast(message):
    if ws_clients:
        await asyncio.gather(
            *[client.send(message) for client in ws_clients],
            return_exceptions=True
        )


def run_ws_server():
    async def serve():
        async with websockets.serve(ws_handler, "localhost", WS_PORT):
            print(f"WebSocket server running on ws://localhost:{WS_PORT}")
            await asyncio.Future()
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(serve())


# === Main ===
if __name__ == '__main__':
    import sys
    
    ws_thread = threading.Thread(target=run_ws_server, daemon=True)
    ws_thread.start()
    
    print(f"\n{'='*60}")
    print("  BAR Economy Audit Dashboard")
    print(f"{'='*60}")
    print(f"  Database: {DB_PATH}")
    print(f"  WebSocket: ws://localhost:{WS_PORT}")
    print(f"  Dashboard: http://localhost:8050")
    print(f"{'='*60}\n")
    
    app.run(debug=True, use_reloader=False, port=8050)
