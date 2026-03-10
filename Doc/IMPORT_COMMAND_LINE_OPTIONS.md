# ZBB.Import Command-Line Options

## Overview
The ZBB.Import tool now supports selective import operations via command-line arguments, making it easy to control what gets imported and whether to reset the database.

## Usage

```bash
ZBB.Import [options]
```

## Options

| Option | Description |
|--------|-------------|
| `/reset`, `--reset` | Delete and recreate the database before import (⚠️ destructive) |
| `/conf:*`, `--conf:*` | Import all conferences |
| `/conf:<name>` | Import specific conference by name (can be used multiple times) |
| `/help`, `--help`, `-h`, `/?` | Show help message |

## Examples

### Full Reset and Import Everything
```bash
ZBB.Import /reset /users /conf:*
```
Deletes database, recreates schema, imports users, then imports all conferences.

### Import Specific Conferences
```bash
ZBB.Import /conf:CET /conf:Sezam /conf:Pitanja
```
Imports only the specified conferences (CET, Sezam, and Pitanja).

### Import All Conferences (No Users)
```bash
ZBB.Import /conf:*
```
Imports all conferences found in the data directory. Useful when users are already imported.

### Fresh Start (Typical Development Workflow)
```bash
# First time or after schema changes
ZBB.Import /reset /users /conf:CET

# Add more conferences later
ZBB.Import /conf:Sezam /conf:Pitanja
```

### Show Help
```bash
ZBB.Import /help
ZBB.Import --help
ZBB.Import -h
ZBB.Import /?
```

## Behavior

### Database Migration
- Always runs `Migrate()` to ensure schema is up-to-date
- Creates database if it doesn't exist
- Applies any pending migrations

### Reset Flag
- **Destructive**: Deletes entire database
- Use only in development or when intentionally starting fresh
- Automatically runs migrations after deletion

### Import Order
1. Database reset (if `/reset` specified)
2. Apply migrations
3. Import users (if `/users` specified)
4. Import conferences (if `/conf:*` or `/conf:<name>` specified)

### Parallel Import
- Conferences are imported in parallel (4 concurrent threads by default)
- Users are imported serially
- Progress is logged to console

## Configuration

The tool reads configuration from:
1. `appsettings.json`
2. `appsettings-secrets.json` (optional)
3. Environment variables

Key settings:
- `Data:Folder` - Path to legacy ZBB data files
- `DB_HOST` / `DbHost` - Database server
- `DB_NAME` / `DbName` - Database name
- `DB_PASSWORD` / `DbPassword` - Database password

## Error Handling

- If import fails, error details are logged and printed
- Partial imports are possible (some conferences may succeed while others fail)
- Users are added as needed during conference import (for missing message authors)

## Development Tips

### Quick Iteration
```bash
# Reset and import single conference for testing
ZBB.Import /reset /users /conf:TestConf
```

### Add Data Incrementally
```bash
# First pass - users only
ZBB.Import /users

# Second pass - add conferences one by one
ZBB.Import /conf:Important
ZBB.Import /conf:AlsoImportant
```

### Verify Database State
```bash
# Just run migrations (no import)
ZBB.Import
# Will show help since no import flags specified
```

## Notes

- Running with **no arguments** shows the help message
- Options are case-insensitive (`/reset`, `/RESET`, `--Reset` all work)
- Both `/flag` and `--flag` syntax are supported
- Conference names are case-sensitive (match directory names exactly)
