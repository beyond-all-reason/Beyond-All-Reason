# BAR Audit Log Analyzer

Parses `EconomyAudit` and `SolverAudit` log entries from BAR's `infolog.txt` into a SQLite database for visualization and analysis.

## Setup

```bash
cd log_analysis
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Usage

### Parser

```bash
# Reset DB and parse existing log from beginning
python3 parser.py --reset --history

# Tail log in real-time (waits for new lines)
python3 parser.py

# Verbose mode (debug output)
python3 parser.py --history --verbose

# Parse a specific file
python3 parser.py --file /path/to/infolog.txt
```

**Note:** Edit `WIN_USER` in `parser.py` if your Windows username differs from `Daniel`.

### Visualization

```bash
jupyter notebook analysis.ipynb
```

Run the cells to generate graphs. The last cell provides a real-time dashboard that refreshes every 5 seconds.

## Troubleshooting

**Database locked?** The parser checkpoints WAL on exit. If you see lock files (`audit_logs.db-wal`, `audit_logs.db-shm`), ensure the parser has exited properly (Ctrl+C). You can safely delete these files if the parser isn't running.

## Database Schema

| Table | Description |
|-------|-------------|
| `solver_audit` | Timing metrics (PreMunge, Solver, PolicyCache, etc.) |
| `eco_team_input` | Team resource state before processing (current, storage, share_cursor) |
| `eco_team_output` | Team resource state after processing (current, sent, received) |
| `eco_team_waterfill` | Per-team waterfill state with target levels and sender/receiver role |
| `eco_group_lift` | Alliance-level lift calculations (supply/demand balance) |
| `eco_transfer` | Individual resource transfers between teams (amount, taxed/untaxed) |
| `eco_frame_start` | Frame metadata (tax rate, thresholds) |

## Understanding the Waterfill Algorithm

The solver uses a "waterfill" algorithm to balance resources within alliances:

1. **Share Cursor**: Each team sets a threshold (`storage × shareSlider`) - they'll give away resources above this level
2. **Lift**: The algorithm finds a common "lift" value added to all cursors that balances supply and demand
3. **Target**: Each team's target = `min(shareCursor + lift, storage)`
4. **Senders**: Teams with `current > target` - they give excess to receivers
5. **Receivers**: Teams with `current < target` - they receive from senders
6. **Tax**: Resources transferred above the tax-free threshold are taxed (destroyed)

The key invariant: **Total Received = Total Sent - Tax**

