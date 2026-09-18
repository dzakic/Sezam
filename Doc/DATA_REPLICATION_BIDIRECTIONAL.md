# Bidirectional (Circular) MySQL Replication

## Context

Sezam nodes run independent MySQL 8.4 instances and need inserts + updates to flow
between them, outside application code. Message tables use GUID PKs (`binary(16)`)
whose ids are assigned centrally ("once in never events"), so cross-node PK conflicts
cannot occur. Conflicts are assumed rare; policy is **last write wins** — no detection,
no resolution, nothing is ever rejected.

This documents the chosen design: **plain MySQL GTID circular replication** (each node is
both source and replica of the other). Low overhead, built into MySQL, zero app code.

## Topology

```
        +--------+  CHANGE REPLICATION SOURCE (AUTO_POSITION)  +--------+
        | Node A |  <--------------------------------------->  | Node B |
        +--------+  server-id=1  gtid flow both ways           +--------+
```

Each transaction keeps its **origin server-id/GTID** as it travels around the ring. A
server skips any transaction it has already executed, so the circle does not loop
forever. This is what makes circular replication safe with GTIDs.

## Semantics (read carefully)

- Async: eventual consistency. Each node converges to the last-applied transaction.
- Row events are applied **by column position**, not by name.
- With default `binlog_row_image = FULL`, an applied UPDATE overwrites the **whole row**
  (whole-row LWW). Concurrent edits of *different columns* of the same row on the two
  nodes can lose an update (a diverging split-brain), so treat rows as single-writer.
- With `binlog_row_image = MINIMAL`, row events carry only the **changed columns**, so a
  different-column edit from each source **merges** cleanly. Pick this if two admins can
  ever edit the same row's different columns concurrently.
- Consequence trade-off of MINIMAL: binlog no longer has full before/after images, so
  binlog-based rollback/audit and CDC (Debezium) see only the changed columns.
- Schema mismatch does **not** merge; see "Schema migration" below.

## Configuration

On BOTH nodes (`my.cnf`), only `server-id` differs:

```ini
[mysqld]
server-id = 1                    # Node A. Node B uses 2 — MUST differ
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_format = ROW
log_slave_updates = ON           # REQUIRED for circular: re-log what the peer sends
binlog_row_image = MINIMAL       # optional; FULL (default) = whole-row LWW
slave_exec_mode = IDEMPOTENT     # skip dup-key / row-not-found races instead of stopping
binlog_expire_logs_seconds = 2592000
```

Notes:
- `log_slave_updates = ON` is mandatory: without it the peer's changes never leave the
  node that applied them, so the loop dies.
- `slave_exec_mode = IDEMPOTENT` keeps the applier alive through the exact races the
  "don't care, LWW" policy accepts. It does **not** fix schema-type mismatches.
- Identity columns on `User`/`Conference`/`ConfTopic` are irrelevant while inserts to
  those tables stay single-writer (centrally created). If you ever allow concurrent
  inserts on both nodes, add to each node `auto_increment_increment = 2` and
  `auto_increment_offset = 1` (A) / `2` (B).
- If you prefer to replicate *only* message tables, add `replicate-wild-do-table =
  sezam.ConfMessage` + `sezam.MessageText` + `sezam.PrivateMessage` on both nodes. DDL
  from EF migrations then needs manual application on each node (see below).

## Initiating the circular relationship

Prereq: GTID config above set on both, restarted, and MySQL listening on both.

1. **Create the replication user on both nodes** (needed on B so A can connect too):

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY '<strong password>';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
```

2. **Seed B from A** (skips if both are already at the same state). On A, as a
   consistent snapshot:

```bash
mysqldump -u sezam -p --single-transaction --set-gtid-purged=ON \
  --default-character-set=utf8mb4 sezam > sezam-$(date +%F).sql
mysql -u sezam -p sezam < sezam-$(date +%F).sql   # run on B
```

   `--set-gtid-purged=ON` transfers A's executed-GTID set into B, so B treats A's
   history as already applied. After import, do **not** purge A's binlogs until both
   links below are live (GTID auto-position needs them).

3. **Point B at A** (run on B):

```sql
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST = '<node-a>', SOURCE_PORT = 3306,
  SOURCE_USER = 'repl', SOURCE_PASSWORD = '<password>',
  SOURCE_AUTO_POSITION = 1;
START REPLICA;
```

4. **Point A at B** (run on A):

```sql
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST = '<node-b>', SOURCE_PORT = 3306,
  SOURCE_USER = 'repl', SOURCE_PASSWORD = '<password>',
  SOURCE_AUTO_POSITION = 1;
START REPLICA;
```

5. **Verify** — on both nodes: `SHOW REPLICA STATUS\G`. `Replica_IO_Running` and
   `Replica_SQL_Running` must both be `Yes`, and `Seconds_Behind_Source` should trend to
   `0` (the old term `Seconds_Behind_Master` still appears).

Bootstrap from scratch (no existing data): do steps 1, 3, 4; the ring builds itself.

## Schema migration — the one-node-only rule

DDL is replicated as a statement, so the whole migration travels as one contiguous
segment: `ALTER … ALTER TABLE` followed by all the new-schema row events. The peer
applies the ALTER then the rows — no mismatch window, **as long as only one node drives
the DDL**.

The current EF `Store.ApplyMigrations()` runs on **every** node at startup and swallows
errors — that will fight the replicated DDL ("duplicate column") and silently diverge. For
the replication world:

1. Apply migrations from **one** node (or let only Node A's boot run them).
2. `__EFMigrationsHistory` replicates too, so Node B's EF sees it as already applied and
   no-ops naturally.
3. Never place a new column in the middle — EF appends at the end, which is what makes
   both mismatch directions behave (see below). Don't reorder/rename/drop common columns.

If a mismatch happens anyway, the applier behavior is:

| Situation | Result |
|---|---|
| Target has MORE columns than the event (peer migrated first) | Extra columns set to their DEFAULT (must be nullable or have default) — works |
| Target has FEWER columns than the event (source migrated first) | Replication errors, SQL thread stops (`errno 1677` etc.) — fix schema, `START REPLICA` |
| Common column type differs | Errors, SQL thread stops unless `replica_type_conversions = ALL_LOSSY,ALL_NON_LOSSY` allows it |

`binlog_row_image = MINIMAL` doesn't change the above — column-count/type validation
comes from TABLE_MAP metadata and lookup is positional either way.

## Monitoring / guardrails

- `SHOW REPLICA STATUS\G`; watch both `*_Running` and `Last_SQL_Error`.
- GTID resume is automatic: a stopped SQL thread resumes exactly at the failed
  transaction once the cause is fixed and `START REPLICA` is issued.
- With GTID + `slave_exec_mode=IDEMPOTENT`, a transient dup-key or row-not-found becomes
  a skip instead of a halt.

## Full rescan / resync when suspecting drift

MySQL replication has **no native "rescan"** — it only applies forward deltas from the
binlog. To re-converge, use one of:

1. **Percona Toolkit reconcile** (smallest effort; works on the live ring without
   stopping replication):
   ```bash
   sudo apt install percona-toolkit
   pt-table-checksum --host=node-a --databases=sezam    # detect which rows differ
   pt-table-sync --host=node-a --host=node-b \
     --replicate=percona.checksums --print             # preview
   pt-table-sync --host=node-a --host=node-b \
     --replicate=percona.checksums --execute           # repair (run from one side only)
   ```
   Options: point it one-directional (authoritative node -> other), or
   `--bidirectional` with `--conflict-strategy=last-write-wins`. Compatible with
   `binlog_row_image = MINIMAL` (the tool sets a session-level FULL image for its own
   checksum writes). Run it as a cron job as a periodic safety net.

2. **Full re-provision** ("nuclear rescan") if divergence is deep:
   - Choose the authoritative node.
   - On the other: `STOP REPLICA;`,
   - dump authoritative node as in "Initiating" (step 2), wipe and reload the target,
   - re-issue `CHANGE REPLICATION SOURCE … SOURCE_AUTO_POSITION=1; START REPLICA;`.

3. **Cheap drift probe**: `CHECKSUM TABLE <table>` on both nodes and diff the hashes;
   `CHECKSUM TABLE … EXTENDED` for stricter comparison.

## Open items before production

- Decide `binlog_row_image`: FULL (whole-row LWW, default) vs MINIMAL (column-merge).
- Move EF `ApplyMigrations` to a single bootstrapping node (code change in
  `Server.InitializeAsync()` path).
- Wire `pt-table-sync` as a nightly reconcile job.