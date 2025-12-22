#!/usr/bin/env python3
"""
BAR Economy Audit Dashboard
Real-time visualization of economy data using Dash + WebSockets
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

# WebSocket for real-time updates
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

# Player colors for distinguishing teams
PLAYER_COLORS = [
    '#58a6ff', '#a3be8c', '#bf616a', '#b48ead', 
    '#d08770', '#88c0d0', '#ebcb8b', '#81a2be',
    '#f0c674', '#8fbcbb', '#5e81ac', '#e5c07b'
]

def get_player_color(player_id):
    return PLAYER_COLORS[player_id % len(PLAYER_COLORS)]


def get_team_display_name(team_id, names_dict):
    """Get display name for a team, using player name if available."""
    if names_dict and team_id in names_dict:
        return names_dict[team_id]
    return f"Player {team_id}"


def format_time_mmss(seconds):
    """Format seconds as m:ss (e.g., 1:45, 0:30)"""
    if pd.isna(seconds):
        return "0:00"
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f"{mins}:{secs:02d}"


def get_time_axis_config(game_times, colors):
    """Generate tick values and labels for mm:ss time axis."""
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
    """Get a read-only database connection."""
    if not os.path.exists(DB_PATH):
        return None
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True, timeout=5)
    conn.row_factory = sqlite3.Row
    return conn


def load_sessions():
    """Load all game sessions."""
    conn = get_db_connection()
    if not conn:
        return []
    try:
        df = pd.read_sql_query(
            "SELECT id, start_timestamp, start_frame, end_frame, team_count, duration_frames FROM game_sessions ORDER BY id DESC",
            conn
        )
        return df.to_dict('records')
    finally:
        conn.close()


def load_team_names(session_id):
    """Load team names for a session."""
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
    """Load distinct teams from economy data."""
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


def load_economy_data_multi(session_id, team_ids, resource, limit=500):
    """Load economy data for multiple teams."""
    conn = get_db_connection()
    if not conn or not team_ids:
        return pd.DataFrame()
    try:
        placeholders = ','.join(['?' for _ in team_ids])
        input_df = pd.read_sql_query(
            f"""SELECT frame, team_id, current, storage, source_path 
               FROM eco_team_input 
               WHERE session_id = ? AND team_id IN ({placeholders}) AND resource = ?
               ORDER BY frame DESC LIMIT ?""",
            conn, params=[session_id] + list(team_ids) + [resource, limit * len(team_ids)]
        )
        
        if input_df.empty:
            return pd.DataFrame()
        
        input_df = input_df.sort_values('frame')
        input_df['game_time'] = input_df['frame'] / 30.0
        return input_df
        
    finally:
        conn.close()


def load_transfers(session_id, resource, team_ids=None, limit=1000):
    """Load explicit resource transfers, optionally filtered by teams."""
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        if team_ids:
            placeholders = ','.join(['?' for _ in team_ids])
            df = pd.read_sql_query(
                f"""SELECT frame, game_time, sender_team_id, receiver_team_id, 
                          amount, untaxed, taxed
                   FROM eco_transfer
                   WHERE session_id = ? AND resource = ? 
                         AND (sender_team_id IN ({placeholders}) OR receiver_team_id IN ({placeholders}))
                   ORDER BY frame DESC LIMIT ?""",
                conn, params=[session_id, resource] + list(team_ids) + list(team_ids) + [limit]
            )
        else:
            df = pd.read_sql_query(
                """SELECT frame, game_time, sender_team_id, receiver_team_id, 
                          amount, untaxed, taxed
                   FROM eco_transfer
                   WHERE session_id = ? AND resource = ?
                   ORDER BY frame DESC LIMIT ?""",
                conn, params=(session_id, resource, limit)
            )
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


def load_group_lift_data(session_id, resource, limit=500):
    """Load group lift (supply/demand totals) data."""
    conn = get_db_connection()
    if not conn:
        return pd.DataFrame()
    try:
        df = pd.read_sql_query(
            """SELECT frame, game_time, member_count, lift, total_demand, total_supply
               FROM eco_group_lift
               WHERE session_id = ? AND resource = ?
               ORDER BY frame DESC LIMIT ?""",
            conn, params=(session_id, resource, limit)
        )
        return df.sort_values('frame') if not df.empty else df
    finally:
        conn.close()


# === Chart builders ===
def create_empty_fig(message, colors):
    """Create an empty figure with a message."""
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
    """Create resource levels chart for one or more teams."""
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
        margin=dict(l=50, r=20, t=50, b=40),
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1, bgcolor='rgba(0,0,0,0)'),
        hovermode='x unified',
        xaxis=x_axis_config,
        yaxis=dict(gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_transfer_flow_chart(transfers_df, team_names, selected_teams, colors):
    """Create transfer flow chart - showing net flow per player."""
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
        margin=dict(l=50, r=20, t=50, b=40),
        legend=dict(orientation='h', yanchor='bottom', y=1.02, xanchor='right', x=1, bgcolor='rgba(0,0,0,0)'),
        hovermode='x unified',
        xaxis=x_axis_config,
        yaxis=dict(title="+ receiving / − sending", gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_explicit_transfers_chart(transfers_df, team_names, colors):
    """Create bar chart showing taxed vs received amounts per time window."""
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
        yaxis=dict(title="Amount", gridcolor=colors['border'], zerolinecolor=colors['border'])
    )
    
    return fig


def create_total_sent_chart(transfers_df, team_names, colors):
    """Create horizontal bar chart of total sent by each player."""
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
        yaxis=dict(gridcolor=colors['border'])
    )
    
    return fig


def create_supply_demand_chart(group_lift_df, colors):
    """Create supply/demand over time line chart."""
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
    """Create lift value over time."""
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
    """Create data for transaction ledger table."""
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


# === Dash App ===
app = dash.Dash(
    __name__,
    external_stylesheets=[
        dbc.themes.DARKLY,
        "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&display=swap"
    ],
    title="BAR Economy Audit"
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
            /* Dropdown menu styling */
            .Select-menu-outer, [class*="-menu"] {
                background-color: #1c2128 !important;
                border: 1px solid #30363d !important;
            }
            [class*="-option"] {
                background-color: #1c2128 !important;
                color: #c9d1d9 !important;
            }
            [class*="-option"]:hover {
                background-color: #30363d !important;
                color: #ffffff !important;
            }
            [class*="-option"][aria-selected="true"] {
                background-color: #21262d !important;
                color: #58a6ff !important;
            }
            [class*="-control"] {
                background-color: #161b22 !important;
                border-color: #30363d !important;
            }
            [class*="-control"]:hover {
                border-color: #58a6ff !important;
            }
            [class*="-singleValue"], [class*="-placeholder"], [class*="-multiValue"] {
                color: #c9d1d9 !important;
            }
            [class*="-input"] input {
                color: #c9d1d9 !important;
            }
            [class*="-indicatorContainer"] {
                color: #8b949e !important;
            }
            [class*="-multiValue"] {
                background-color: #30363d !important;
            }
            [class*="-multiValueLabel"] {
                color: #c9d1d9 !important;
            }
            [class*="-multiValueRemove"]:hover {
                background-color: #bf616a !important;
                color: white !important;
            }
            
            /* Checklist styling */
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
            
            /* Data table styling */
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

app.layout = dbc.Container([
    # Header
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
    
    # Controls row
    dbc.Row([
        dbc.Col([
            dbc.Label("Session", className="text-muted small"),
            dcc.Dropdown(
                id='session-dropdown',
                placeholder="Select session...",
                className="dash-dropdown"
            )
        ], width=3),
        dbc.Col([
            dbc.Label("Resource", className="text-muted small"),
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
            dbc.Label("Update", className="text-muted small"),
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
    ], className="mb-2"),
    
    # Team selection row
    dbc.Row([
        dbc.Col([
            dbc.Label("Players (select for per-player charts)", className="text-muted small"),
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
        ], width=12),
    ], className="mb-3"),
    
    # Main content area
    dbc.Row([
        # Left column - main timeline charts
        dbc.Col([
            # Resource levels (per selected teams)
            dcc.Loading(
                dcc.Graph(id='resource-chart', style={'height': '280px'}),
                type='circle', color=COLORS['accent']
            ),
            
            # Transfer flow chart (per selected teams)
            dcc.Loading(
                dcc.Graph(id='transfer-flow-chart', style={'height': '250px', 'marginTop': '10px'}),
                type='circle', color=COLORS['accent']
            ),
            
            # Explicit transfers (all teams)
            dcc.Loading(
                dcc.Graph(id='explicit-transfers-chart', style={'height': '250px', 'marginTop': '10px'}),
                type='circle', color=COLORS['accent']
            ),
            
        ], width=8),
        
        # Right column - summary charts and ledger
        dbc.Col([
            # Total sent by player (all teams)
            dcc.Loading(
                dcc.Graph(id='total-sent-chart', style={'height': '180px'}),
                type='circle', color=COLORS['accent']
            ),
            
            # Supply/demand chart (alliance)
            dcc.Loading(
                dcc.Graph(id='supply-demand-chart', style={'height': '180px', 'marginTop': '8px'}),
                type='circle', color=COLORS['accent']
            ),
            
            # Lift chart (alliance)
            dcc.Loading(
                dcc.Graph(id='lift-chart', style={'height': '150px', 'marginTop': '8px'}),
                type='circle', color=COLORS['accent']
            ),
            
            # Transaction ledger (filtered by selected teams)
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
    
    # Hidden components
    html.Div(id='ws-status', style={'display': 'none'}),
    dcc.Interval(id='auto-refresh', interval=2000, n_intervals=0),
    dcc.Store(id='ws-data-store'),
    dcc.Store(id='team-names-store'),
    
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
    State('session-dropdown', 'value'),
    prevent_initial_call=False
)
def update_sessions(n_clicks, current_value):
    sessions = load_sessions()
    options = [
        {
            'label': f"#{s['id']} — Frame {s['start_frame'] or 0}-{s['end_frame'] or '?'} ({s['team_count'] or '?'} teams)",
            'value': s['id']
        }
        for s in sessions
    ]
    value = current_value if any(o['value'] == current_value for o in options) else (options[0]['value'] if options else None)
    return options, value


@callback(
    Output('team-checklist', 'options'),
    Output('team-checklist', 'value'),
    Output('team-names-store', 'data'),
    Input('session-dropdown', 'value'),
    State('team-checklist', 'value')
)
def update_teams(session_id, current_teams):
    if not session_id:
        return [], [], {}
    
    teams = load_teams(session_id)
    names = load_team_names(session_id)
    
    options = [
        {'label': get_team_display_name(t, names), 'value': t}
        for t in teams
    ]
    
    # Keep current selection if valid, else select first team
    valid_teams = [t for t in (current_teams or []) if t in teams]
    if not valid_teams and teams:
        valid_teams = [teams[0]]
    
    return options, valid_teams, names


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
    Input('refresh-btn', 'n_clicks'),
    State('team-names-store', 'data')
)
def update_charts(n_intervals, session_id, selected_teams, resource, n_clicks, team_names):
    if not session_id:
        ef = create_empty_fig("Select a session", COLORS)
        return ef, [], ef, ef, ef, ef, ef
    
    team_names = team_names or {}
    selected_teams = selected_teams or []
    
    # Load data
    eco_df = load_economy_data_multi(session_id, selected_teams, resource) if selected_teams else pd.DataFrame()
    transfers_df = load_transfers(session_id, resource)
    group_lift_df = load_group_lift_data(session_id, resource)
    
    # Build charts
    resource_fig = create_resource_levels_chart(eco_df, selected_teams, team_names, resource, COLORS)
    ledger_data = create_transaction_ledger(transfers_df, team_names, selected_teams if selected_teams else None)
    flow_fig = create_transfer_flow_chart(transfers_df, team_names, selected_teams if selected_teams else None, COLORS)
    explicit_fig = create_explicit_transfers_chart(transfers_df, team_names, COLORS)
    sent_fig = create_total_sent_chart(transfers_df, team_names, COLORS)
    supply_demand_fig = create_supply_demand_chart(group_lift_df, COLORS)
    lift_fig = create_lift_chart(group_lift_df, COLORS)
    
    return resource_fig, ledger_data, flow_fig, explicit_fig, sent_fig, supply_demand_fig, lift_fig


@callback(
    Output('auto-refresh', 'interval'),
    Output('auto-refresh', 'disabled'),
    Input('interval-dropdown', 'value')
)
def update_interval(value):
    if value == 0:
        return 1000, True
    return value, False


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
