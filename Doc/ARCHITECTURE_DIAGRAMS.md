# Localization System - Architecture Diagrams

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     User Login Flow                          │
└─────────────────────────────────────────────────────────────┘

    Telnet Connection
           │
           ▼
    ┌─────────────────┐
    │  Session.Run()  │
    └────────┬────────┘
             │
             ▼
    ┌──────────────────────┐
    │  WelcomeAndLogin()   │
    └────────┬─────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │   User = Login()         │ ◄─── Load from DB
    │   (from database)        │
    └────────┬─────────────────┘
             │
             ▼
    ┌────────────────────────────────┐
    │  SetSessionCulture(            │
    │    User.Language               │ ◄─── "en" or "sr"
    │  )                             │
    └────────┬───────────────────────┘
             │
             ▼
    ┌────────────────────────────────┐
    │  SessionCulture =              │
    │  new CultureInfo("sr")         │
    └────────┬───────────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  Session Ready           │
    │  • Terminal I/O          │
    │  • Commands Execution    │
    │  • String Localization   │ ◄─── session.GetStr()
    └──────────────────────────┘
```

## String Retrieval Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 session.GetStr("Root_Time")                 │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
    ┌─────────────────────────────────┐
    │  Check SessionCulture           │
    │  (en-US, sr, etc.)              │
    └────────┬────────────────────────┘
             │
             ▼
    ┌──────────────────────────────────┐
    │  Get ResourceManager             │
    │  (Sezam.Commands.Strings)        │
    └────────┬─────────────────────────┘
             │
             ▼
    ┌──────────────────────────────────┐
    │  ResourceManager.GetString(      │
    │    "Root_Time",                  │
    │    SessionCulture                │
    │  )                               │
    └────────┬─────────────────────────┘
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
   ┌──────────┐  ┌──────────┐
   │ strings. │  │ strings. │
   │ resx     │  │ sr.resx  │
   │(English) │  │(Serbian) │
   └──────────┘  └──────────┘
      │             │
      ▼             ▼
   ┌──────────────────────────────────┐
   │  Return appropriate string       │
   │  based on SessionCulture         │
   └────────┬─────────────────────────┘
            │
            ▼
   ┌──────────────────────────────────┐
   │  "Current time is: ..."    (en)  │
   │   -or-                           │
   │  "Тачно време је: ..."    (sr)   │
   └──────────────────────────────────┘
```

## Session Isolation

```
┌────────────────────────────────────────────────────────────────┐
│                    Telnet Server                               │
│  (Multiple Concurrent Sessions)                                │
└────────────────────────────────────────────────────────────────┘

  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
  │  Session 1       │    │  Session 2       │    │  Session 3       │
  │  (Alice)         │    │  (Bob)           │    │  (Charlie)       │
  ├──────────────────┤    ├──────────────────┤    ├──────────────────┤
  │ User: Alice      │    │ User: Bob        │    │ User: Charlie    │
  │ Language: en     │    │ Language: sr     │    │ Language: en     │
  │ Thread: #42      │    │ Thread: #43      │    │ Thread: #44      │
  │ Culture: en-US   │    │ Culture: sr      │    │ Culture: en-US   │
  └────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
           │                       │                       │
           ▼                       ▼                       ▼
       English              Serbian               English
       Strings              Strings               Strings
        │                    │                    │
        └────────┬───────────┴───────────┬────────┘
                 │                       │
           ┌─────┴───────┬───────────────┴──────┐
           │             │                      │
        Alice         Bob                   Charlie
    sees English   sees Serbian         sees English
    "Current       "Тачно време      "Current
     time is..."    је..."            time is..."
```

## Language Switching Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    LANGUAGE Command Flow                    │
└─────────────────────────────────────────────────────────────┘

  User@BBS> SET LANGUAGE sr
        │
        ▼
  ┌──────────────────────────┐
  │  Set.Language()          │
  │  Get "sr" argument       │
  └────────┬─────────────────┘
           │
           ▼
  ┌──────────────────────┐
  │  Validate            │
  │  ✓ "sr" is valid     │
  └────────┬─────────────┘
           │
           ▼
  ┌──────────────────────────────────┐
  │  session.User.Language = "sr"    │
  │  session.Db.SaveChanges()        │ ◄─── Save to database
  └────────┬─────────────────────────┘
           │
           ▼
  ┌──────────────────────────────────┐
  │  SetSessionCulture("sr")         │
  │  • Create new CultureInfo("sr")  │
  │  • Set SessionCulture = ...      │
  │  • Set Thread.CurrentCulture     │
  └────────┬─────────────────────────┘
           │
           ▼
  ┌──────────────────────────────────┐
  │  Output confirmation:            │
  │  "Language preference updated"   │
  │  (in Serbian now!)               │
  └────────┬─────────────────────────┘
           │
           ▼
  All subsequent session.GetStr() calls
  return Serbian strings ✓
```

## Resource File Organization

```
┌─────────────────────────────────────────────────────────────┐
│                  Project Structure                          │
└─────────────────────────────────────────────────────────────┘

Sezam/
│
├── Commands/
│   ├── strings.resx              ◄─── English (default)
│   │   └── [Auto-gen]
│   │       └── strings.Designer.cs
│   ├── strings.sr.resx           ◄─── Serbian (satellite)
│   ├── LocalizationHelper.cs     ◄─── Extension methods
│   └── Root.cs                   ◄─── Lang command
│
├── Console/
│   ├── strings.resx              ◄─── English (default)
│   │   └── [Auto-gen]
│   │       └── strings.Designer.cs
│   ├── strings.sr.resx           ◄─── Serbian (satellite)
│   ├── Session.cs                ◄─── GetStr() methods
│   └── SessionAsync.cs           ◄─── Inherits GetStr()
│
└── Data/EF/
    └── User.cs                   ◄─── Language property


┌─────────────────────────────────────────────────────────────┐
│                  Build Output Structure                     │
└─────────────────────────────────────────────────────────────┘

bin/net10.0/
│
├── Sezam.Commands.dll            ◄─── Main assembly
├── Sezam.Console.dll             ◄─── Main assembly
│
└── sr/                            ◄─── Satellite assemblies
    ├── Sezam.Commands.resources.dll
    └── Sezam.Console.resources.dll

.NET automatically loads from sr/ folder when
SessionCulture.Name == "sr"
```

## Async-Safe Implementation

```
┌─────────────────────────────────────────────────────────────┐
│              Sync vs Async Localization                     │
└─────────────────────────────────────────────────────────────┘

SYNCHRONOUS (Session)
┌───────────────────────────────┐
│  Session runs on:             │
│  - Single dedicated thread    │
│  - Thread #42 (entire life)   │
│                               │
│  Culture set:                 │
│  ✓ Thread.CurrentCulture      │
│  ✓ SessionCulture (backup)    │
└───────────────────────────────┘


ASYNCHRONOUS (SessionAsync)
┌──────────────────────────────────────┐
│  Task runs on:                       │
│  - Thread pool (different threads)   │
│  - #42 then #43 then #44 (random)    │
│                                      │
│  Culture issue:                      │
│  ✗ Thread.CurrentCulture (unreliable)
│    (changes at each await point)     │
│                                      │
│  Solution:                           │
│  ✓ SessionCulture (property, safe)   │
│    (travels with the async chain)    │
└──────────────────────────────────────┘

SOLUTION:
session.SessionCulture works for BOTH ✓
```

## Performance Characteristics

```
┌─────────────────────────────────────────────────────────────┐
│                     Performance                             │
└─────────────────────────────────────────────────────────────┘

First session.GetStr() call:
┌──────────────────────────────────┐
│ 1. Reflection lookup (cached)    │ ◄─── ~0.1ms
│ 2. ResourceManager creation      │ ◄─── ~0.2ms
│ 3. String lookup                 │ ◄─── ~0.5ms
└──────────────────────────────────┘
        Total: ~0.8ms


Subsequent calls:
┌──────────────────────────────────┐
│ 1. ResourceManager cache hit   │ ◄─── ~0.01ms
│ 2. String lookup               │ ◄─── ~0.1ms
└──────────────────────────────────┘
        Total: ~0.11ms


Memory impact per session:
┌──────────────────────────────────┐
│ CultureInfo object:              │ ◄─── ~2KB
│ ResourceManager reference:       │ ◄─── pointer
│ Minimal overhead                 │
└──────────────────────────────────┘
```

## Error Handling

```
┌─────────────────────────────────────────────────────────────┐
│                  Fallback Strategy                          │
└─────────────────────────────────────────────────────────────┘

GetStr("UnknownKey")
        │
        ▼
  Try Serbian (.sr.resx)
        │
        ├─ Found ✓ → Return Serbian
        │
        └─ Not Found → Fall back to English
                │
                ▼
           Try English (.resx)
                │
                ├─ Found ✓ → Return English
                │
                └─ Not Found → Fall back to Key Name
                        │
                        ▼
                   Return "UnknownKey"
                   Log debug message
```

## Language Selection Flow

```
Database User Record
        │
        ├─ Language: "en"
        │         ▼
        │    Load English Strings
        │         │
        │         ▼
        │    strings.resx
        │
        ├─ Language: "sr"
        │         ▼
        │    Load Serbian Strings
        │         │
        │         ▼
        │    strings.sr.resx
        │
        └─ Language: [unset]
                  ▼
             Default to "en"
                  │
                  ▼
             strings.resx
```

---

These diagrams should help visualize:
- How users get their language preferences
- How strings are retrieved based on culture
- Session isolation
- How language switching works
- File organization
- Async-safe implementation
- Performance characteristics
- Error handling and fallback
