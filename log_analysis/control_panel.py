"""
BAR Economy Analysis Control Panel

A reusable control panel widget for Jupyter notebooks that provides:
- Game session selection (for multiple game runs)
- Frame range slider with dual handles
- Team/AllyTeam selection
- Resource type selection
- Aggregation level (Overall/AllyTeam/Team)

Usage:
    from control_panel import ControlPanel
    panel = ControlPanel('audit_logs.db')
    panel.display()
    
    # Access current selections:
    panel.session_id
    panel.frame_range
    panel.resource
    panel.team_id
    panel.ally_team
    panel.aggregation
"""

import sqlite3
import pandas as pd
import ipywidgets as widgets
from IPython.display import display, HTML, clear_output


class ControlPanel:
    """Global control panel for economy analysis notebooks."""
    
    def __init__(self, db_path='audit_logs.db'):
        self.db_path = db_path
        self.conn = None
        
        # Current selections (defaults)
        self.session_id = None
        self.frame_range = (0, 0)
        self.resource = 'metal'
        self.team_id = None  # None = all teams
        self.ally_team = None  # None = all alliances
        self.aggregation = 'overall'  # 'overall', 'ally_team', 'team'
        
        # Widget references
        self._widgets = {}
        self._output = widgets.Output()
        
        # Load initial data
        self._connect()
        self._load_sessions()
    
    def _connect(self):
        """Connect to the database."""
        self.conn = sqlite3.connect(self.db_path, timeout=10)
    
    def _query(self, sql, params=None):
        """Execute a query and return DataFrame."""
        try:
            return pd.read_sql_query(sql, self.conn, params=params)
        except Exception as e:
            print(f"Query error: {e}")
            return pd.DataFrame()
    
    def _load_sessions(self):
        """Load available game sessions."""
        self.sessions_df = self._query("""
            SELECT id, start_timestamp, end_timestamp, start_frame, end_frame, 
                   team_count, duration_frames
            FROM game_sessions
            ORDER BY id DESC
        """)
        
        if self.sessions_df.empty:
            # No sessions table or empty - try to infer from data
            self.sessions_df = pd.DataFrame([{
                'id': 1, 
                'start_timestamp': None, 
                'end_timestamp': None,
                'start_frame': 0,
                'end_frame': 0,
                'team_count': 0,
                'duration_frames': 0
            }])
            
            # Get frame range from actual data
            frame_info = self._query("""
                SELECT MIN(frame) as min_f, MAX(frame) as max_f, COUNT(DISTINCT team_id) as teams
                FROM eco_team_input
            """)
            if not frame_info.empty and frame_info['min_f'].iloc[0] is not None:
                self.sessions_df.loc[0, 'start_frame'] = int(frame_info['min_f'].iloc[0])
                self.sessions_df.loc[0, 'end_frame'] = int(frame_info['max_f'].iloc[0])
                self.sessions_df.loc[0, 'team_count'] = int(frame_info['teams'].iloc[0] or 0)
                self.sessions_df.loc[0, 'duration_frames'] = int(frame_info['max_f'].iloc[0] - frame_info['min_f'].iloc[0])
        
        # Set default session to most recent
        if not self.sessions_df.empty:
            self.session_id = int(self.sessions_df['id'].iloc[0])
            self._update_session_data()
    
    def _update_session_data(self):
        """Update data for the currently selected session."""
        if self.session_id is None:
            return
        
        session = self.sessions_df[self.sessions_df['id'] == self.session_id]
        if session.empty:
            return
        
        session = session.iloc[0]
        start_frame = int(session['start_frame'] or 0)
        end_frame = int(session['end_frame'] or 0)
        self.frame_range = (start_frame, end_frame)
        
        # Load teams for this session
        self._load_teams()
    
    def _load_teams(self):
        """Load team/alliance info for current session."""
        # Try with session_id filter first
        self.teams_df = self._query("""
            SELECT DISTINCT team_id, ally_team 
            FROM eco_team_input 
            WHERE session_id = ? OR ? IS NULL
            ORDER BY ally_team, team_id
        """, (self.session_id, self.session_id))
        
        if self.teams_df.empty:
            # Fallback without session filter
            self.teams_df = self._query("""
                SELECT DISTINCT team_id, ally_team 
                FROM eco_team_input 
                ORDER BY ally_team, team_id
            """)
    
    def _build_widgets(self):
        """Build all control widgets."""
        style = {'description_width': '100px'}
        layout = widgets.Layout(width='100%')
        
        # Session selector
        session_options = [
            (f"Game #{row['id']} ({row['duration_frames'] or 0} frames, {row['team_count'] or 0} teams)", row['id'])
            for _, row in self.sessions_df.iterrows()
        ]
        if not session_options:
            session_options = [("No sessions", None)]
        
        self._widgets['session'] = widgets.Dropdown(
            options=session_options,
            value=self.session_id,
            description='Game Session:',
            style=style,
            layout=layout
        )
        self._widgets['session'].observe(self._on_session_change, names='value')
        
        # Frame range slider
        min_frame, max_frame = self.frame_range
        self._widgets['frame_range'] = widgets.IntRangeSlider(
            value=[min_frame, max_frame],
            min=min_frame,
            max=max(max_frame, min_frame + 1),
            step=30,
            description='Frame Range:',
            continuous_update=False,
            style=style,
            layout=layout
        )
        self._widgets['frame_range'].observe(self._on_frame_change, names='value')
        
        # Resource selector
        self._widgets['resource'] = widgets.ToggleButtons(
            options=[('🔩 Metal', 'metal'), ('⚡ Energy', 'energy')],
            value=self.resource,
            description='Resource:',
            style=style
        )
        self._widgets['resource'].observe(self._on_resource_change, names='value')
        
        # Aggregation level
        self._widgets['aggregation'] = widgets.ToggleButtons(
            options=[('Overall', 'overall'), ('By Alliance', 'ally_team'), ('By Team', 'team')],
            value=self.aggregation,
            description='Group By:',
            style=style
        )
        self._widgets['aggregation'].observe(self._on_aggregation_change, names='value')
        
        # Alliance selector
        ally_options = [('All Alliances', None)]
        if not self.teams_df.empty:
            unique_alliances = sorted(self.teams_df['ally_team'].dropna().unique())
            ally_options += [(f'Alliance {int(a)}', int(a)) for a in unique_alliances]
        
        self._widgets['ally_team'] = widgets.Dropdown(
            options=ally_options,
            value=self.ally_team,
            description='Alliance:',
            style=style,
            layout=widgets.Layout(width='200px')
        )
        self._widgets['ally_team'].observe(self._on_ally_change, names='value')
        
        # Team selector
        self._update_team_options()
        
    def _update_team_options(self):
        """Update team dropdown based on selected alliance."""
        team_options = [('All Teams', None)]
        
        if not self.teams_df.empty:
            if self.ally_team is not None:
                teams = self.teams_df[self.teams_df['ally_team'] == self.ally_team]['team_id']
            else:
                teams = self.teams_df['team_id']
            
            team_options += [(f'Team {int(t)}', int(t)) for t in sorted(teams.unique())]
        
        if 'team' in self._widgets:
            self._widgets['team'].options = team_options
            if self.team_id not in [v for _, v in team_options]:
                self.team_id = None
                self._widgets['team'].value = None
        else:
            style = {'description_width': '100px'}
            self._widgets['team'] = widgets.Dropdown(
                options=team_options,
                value=self.team_id,
                description='Team:',
                style=style,
                layout=widgets.Layout(width='200px')
            )
            self._widgets['team'].observe(self._on_team_change, names='value')
    
    # Event handlers
    def _on_session_change(self, change):
        self.session_id = change['new']
        self._update_session_data()
        # Update frame range widget
        min_f, max_f = self.frame_range
        self._widgets['frame_range'].min = min_f
        self._widgets['frame_range'].max = max(max_f, min_f + 1)
        self._widgets['frame_range'].value = [min_f, max_f]
        self._load_teams()
        self._update_team_options()
        self._show_status()
    
    def _on_frame_change(self, change):
        self.frame_range = tuple(change['new'])
        self._show_status()
    
    def _on_resource_change(self, change):
        self.resource = change['new']
        self._show_status()
    
    def _on_aggregation_change(self, change):
        self.aggregation = change['new']
        self._show_status()
    
    def _on_ally_change(self, change):
        self.ally_team = change['new']
        self._update_team_options()
        self._show_status()
    
    def _on_team_change(self, change):
        self.team_id = change['new']
        self._show_status()
    
    def _show_status(self):
        """Display current selection status."""
        with self._output:
            clear_output(wait=True)
            frame_count = self.frame_range[1] - self.frame_range[0]
            team_str = f"Team {self.team_id}" if self.team_id else ("Alliance " + str(self.ally_team) if self.ally_team else "All")
            print(f"📊 Session #{self.session_id} | Frames {self.frame_range[0]}-{self.frame_range[1]} ({frame_count} frames)")
            print(f"   {self.resource.upper()} | {self.aggregation.replace('_', ' ').title()} | {team_str}")
    
    def display(self):
        """Display the control panel."""
        self._build_widgets()
        
        # Layout the widgets
        header = HTML("<h3 style='margin:0;padding:10px 0;'>🎛️ Analysis Control Panel</h3>")
        
        row1 = widgets.HBox([self._widgets['session']])
        row2 = widgets.HBox([self._widgets['frame_range']])
        row3 = widgets.HBox([
            self._widgets['resource'],
            self._widgets['aggregation']
        ])
        row4 = widgets.HBox([
            self._widgets['ally_team'],
            self._widgets['team']
        ])
        
        panel = widgets.VBox([
            header,
            row1,
            row2,
            row3,
            row4,
            self._output
        ], layout=widgets.Layout(
            padding='10px',
            border='1px solid #444',
            border_radius='5px',
            background_color='#1a1a2e'
        ))
        
        display(panel)
        self._show_status()
    
    # Query helpers for use in notebooks
    def get_where_clause(self, table_alias='', include_session=True, include_frame=True, 
                         include_resource=True, include_team=True):
        """Generate a WHERE clause based on current selections."""
        conditions = []
        prefix = f"{table_alias}." if table_alias else ""
        
        if include_session and self.session_id is not None:
            conditions.append(f"({prefix}session_id = {self.session_id} OR {prefix}session_id IS NULL)")
        
        if include_frame:
            min_f, max_f = self.frame_range
            conditions.append(f"{prefix}frame BETWEEN {min_f} AND {max_f}")
        
        if include_resource:
            conditions.append(f"{prefix}resource = '{self.resource}'")
        
        if include_team and self.team_id is not None:
            conditions.append(f"{prefix}team_id = {self.team_id}")
        elif include_team and self.ally_team is not None:
            conditions.append(f"{prefix}ally_team = {self.ally_team}")
        
        return "WHERE " + " AND ".join(conditions) if conditions else ""
    
    def get_group_by(self, table_alias=''):
        """Get GROUP BY clause based on aggregation level."""
        prefix = f"{table_alias}." if table_alias else ""
        
        if self.aggregation == 'team':
            return f"GROUP BY {prefix}frame, {prefix}team_id"
        elif self.aggregation == 'ally_team':
            return f"GROUP BY {prefix}frame, {prefix}ally_team"
        else:  # overall
            return f"GROUP BY {prefix}frame"
    
    def query(self, sql, params=None):
        """Execute a query with current connection."""
        return self._query(sql, params)
    
    def close(self):
        """Close the database connection."""
        if self.conn:
            self.conn.close()

