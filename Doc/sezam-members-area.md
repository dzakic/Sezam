# Sezam Members Area — Build Plan

## Architecture

`
Sezam.sln
├── Data/           (existing) EF models, migrations, Redis broadcaster
├── Telnet/         (existing) TCP sessions
├── Web/            (existing) public archive, untouched
├── WebApi/         (NEW) .NET 10 API + SignalR
└── Frontend/       (NEW) Next.js 15 + TailwindCSS

One .NET process serves: static files + REST + SignalR.
`

## Auth

- JWT issued on login, set as httpOnly cookie (sub + username + roles)
- Redis stores token blacklist (for logout) and refresh tokens
- No ASP.NET Identity. User model unchanged.

## Real-time

- SignalR Hubs subscribe to existing Redis channels (sezam:broadcast, sezam:sessions)
- Telnet sessions keep working unchanged — same Redis pub/sub
- Next.js uses @aspnet/signalr JS client

## Build pipeline

- Dev: 
pm run dev (Next.js on :3000) + dotnet run WebApi (API on :5000), Next.js proxies /api/* to 5000
- Prod: 
pm run build → copy output to WebApi/wwwroot/ → single dotnet WebApi.dll

## Phases

### Phase 1 — Data model + WebApi skeleton (parallel start)

#### 1a. Data model additions

`csharp
// Data/EF/MessageText.cs — add optional Like system columns later
// For now, just confirm MessageText has Id, ConferenceId, AuthorId, Text, Timestamp, ReplyToId
`

Verify existing entities have what we need:
- User — Username, FullName, Password, Roles ✓
- Conference — Id, Name, VolumeNo, Status ✓
- ConfTopic — Id, ConferenceId, AuthorId, Subject, Timestamp ✓
- ConfMessage — Id, TopicId, AuthorId, ReplyToId (parent), Timestamp ✓
- MessageText — Id (FK to ConfMessage.Id), Text ✓

No migrations needed for Phase 1.

#### 1b. WebApi project

Files to create:

`
WebApi/
├── Sezam.WebApi.csproj
├── Program.cs                    # host, JWT middleware, CORS, EF, SignalR, static files, migrations
├── appsettings.json
├── Auth/
│   ├── JwtTokenHandler.cs        # HMAC-SHA256 JWT create/validate
│   ├── AuthMiddleware.cs         # httpOnly cookie extraction + token validation
│   └── RedisSessionStore.cs      # token blacklist + refresh tokens
├── Dtos/
│   ├── AuthDtos.cs               # LoginRequest, LoginResponse, RegisterRequest
│   ├── UserDtos.cs               # UserView, UserProfile
│   ├── ForumDtos.cs              # ConfView, TopicView, ReplyView, TopicThread
│   └── ChatDtos.cs               # ChatMessage, ChatRoom
├── Controllers/
│   ├── AuthController.cs         # POST login/register/logout, GET me
│   ├── UserController.cs         # GET users/search, GET users/{id}
│   ├── ConfController.cs         # GET conferences/topics/messages
│   ├── ForumController.cs        # POST reply, GET topic/{id}/thread, GET conference/{id}
│   └── MessageController.cs      # GET DMs, POST DMs
├── Hubs/
│   ├── ChatHub.cs                # chat rooms + DMs via SignalR
│   └── ForumHub.cs               # new replies, read receipts
├── Services/
│   ├── AuthService.cs            # login/register logic
│   ├── ForumService.cs           # conference/topic/message CRUD
│   └── ChatService.cs            # room state, message persistence, Redis relay
└── wwwroot/                      ← Next.js output goes here
    └── _nextjs/
`

#### 1c. WebApi/Sezam.WebApi.csproj

`xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\Data\Sezam.Data.csproj" />
    <ProjectReference Include="..\Telnet\Sezam.Telnet.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="System.IdentityModel.Tokens.Jwt" Version="8.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.SignalR" Version="1.1.0" />
  </ItemGroup>
</Project>
`

#### 1d. WebApi/Program.cs — core structure

`csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddDbContext<SezamDbContext>(options =>
    Data.Store.GetOptionsBuilder(options));
builder.Services.AddSignalR();
builder.Services.AddCors(o => o.AddPolicy("default", p =>
    p.SetIsOriginAllowed(_ => true).AllowAnyMethod().AllowAnyHeader()
     .AllowCredentials().WithOrigins("http://localhost:3000")));
builder.Services.AddAuthentication("Bearer").AddJwtBearer("Bearer", cfg => { /* ... */ });
builder.Services.AddSingleton<MessageBroadcaster>(sp => {
    var b = new MessageBroadcaster();
    b.InitializeAsync(Data.Store.RedisConnectionString).GetAwaiter().GetResult();
    return b;
});
var app = builder.Build();
app.UseStaticFiles();
app.UseCors("default");
app.UseAuthentication();
app.MapControllers();
app.MapHub<ChatHub>("/hub/chat");
app.MapHub<ForumHub>("/hub/forum");
Data.Store.ApplyMigrations().Wait();
app.Run();
`

### Phase 2 — Frontend skeleton + routing (parallel start with Phase 1)

#### 2a. Frontend project structure

`
Frontend/
├── package.json
├── tsconfig.json
├── next.config.ts
├── tailwind.config.ts
├── postcss.config.js
├── src/
│   ├── app/
│   │   ├── layout.tsx           # root layout with Sidebar + TopBar + auth guard
│   │   ├── globals.css          # @tailwind base/components/utilities
│   │   ├── (auth)/
│   │   │   ├── login/page.tsx
│   │   │   └── register/page.tsx
│   │   ├── chat/
│   │   │   ├── layout.tsx       # chat shell with room list + message area
│   │   │   ├── rooms/page.tsx
│   │   │   └── [roomId]/page.tsx
│   │   ├── forums/
│   │   │   ├── layout.tsx       # forums shell with topic list + thread
│   │   │   ├── page.tsx         # list conferences
│   │   │   └── [confId]/        # conference topics + replies
│   │   └── profile/page.tsx
│   ├── components/
│   │   ├── ui/                  # shadcn/ui primitives (Button, Input, Card, ...)
│   │   ├── nav/
│   │   │   ├── Sidebar.tsx      # nav: Forums, Chat, Profile
│   │   │   ├── TopBar.tsx       # search bar + user menu + online count
│   │   │   └── UserMenu.tsx     # dropdown with logout
│   │   ├── chat/
│   │   │   ├── ChatRoom.tsx     # full room with list + input + online users
│   │   │   ├── MessageList.tsx
│   │   │   ├── MessageItem.tsx
│   │   │   ├── DirectMessage.tsx
│   │   │   └── OnlineUsers.tsx
│   │   ├── forum/
│   │   │   ├── TopicList.tsx    # list of topics in a conference
│   │   │   ├── TopicThread.tsx  # thread view with replies
│   │   │   ├── ReplyEditor.tsx
│   │   │   ├── ReplyItem.tsx    # colored username, reply-to, timestamp
│   │   │   └── JumpToOriginal.tsx
│   │   └── common/
│   │       ├── Avatar.tsx
│   │       ├── Badge.tsx
│   │       └── LoadingSpinner.tsx
│   ├── lib/
│   │   ├── api.ts               # fetch wrapper with auth cookie
│   │   ├── signalr.ts           # @aspnet/signalr client setup
│   │   ├── hooks/
│   │   │   ├── useAuth.ts       # login/logout/session state
│   │   │   ├── useChatRoom.ts   # room messages + online users via SignalR
│   │   │   └── useForum.ts      # topics, replies, conference list
│   │   └── types/               # TS interfaces matching C# DTOs
│   └── providers/
│       ├── AuthProvider.tsx
│       └── SignalRProvider.tsx
├── public/
└── README.md
`

#### 2b. Frontend dependencies

`json
{
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@microsoft/signalr": "^9.0.0",
    "clsx": "^2.1.0",
    "tailwindcss": "^3.4.0",
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-dropdown-menu": "^2.1.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "typescript": "^5.6.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0"
  }
}
`

### Phase 3 — WebApi endpoints + Hubs (after Phase 1 contracts)

#### 3a. Auth endpoints

`
POST /api/auth/login          {username, password} → sets httpOnly JWT cookie
POST /api/auth/register       {username, password, fullName} → creates User
POST /api/auth/logout         → blacklists token in Redis
GET  /api/auth/me             → returns current user (claims from token)
`

#### 3b. Forum endpoints

`
GET    /api/conferences                   list conferences (filter, page)
GET    /api/conferences/{id}              conference details
GET    /api/conferences/{id}/topics       topic list (filter by user)
GET    /api/conferences/{id}/topic/{tid}  topic details + replies page
GET    /api/topics/{tid}/thread           full thread (jump-to-original support)
POST   /api/topics/{tid}/reply            {text} → new reply
GET    /api/users/search?filter=          user search
`

#### 3c. SignalR Hubs

**ChatHub:**
- joinRoom(string roomId) — enter a chat room
- leaveRoom(string roomId)
- sendMessage(string roomId, string text) — persist to DB, broadcast via Redis
- sendDirect(string toUser, string text) — DM

**ForumHub:**
- subscribeToTopic(string topicId) — get new replies
- markRead(string topicId) — read receipt

Hub receives Redis messages via the same MessageBroadcaster instance.

#### 3d. ForumService — key logic

`csharp
public class ForumService {
    public Task<List<ConfView>> GetConferencesAsync();
    public Task<ConfView> GetConferenceAsync(int id);
    public Task<List<TopicView>> GetTopicsAsync(int confId, string? userFilter, int page, int pageSize);
    public Task<TopicThread> GetTopicThreadAsync(int topicId);
    public Task<ReplyView> AddReplyAsync(int topicId, string userId, string text);
}
`

### Phase 4 — Frontend components + SignalR (after Phase 2 contracts)

#### 4a. Key components to build

- **TopicThread.tsx** — renders replies with colored usernames, timestamps, reply-to references
- **JumpToOriginal.tsx** — "jump to original message" link on quoted/replied posts
- **ChatRoom.tsx** — real-time message list + input + online users sidebar
- **Sidebar.tsx** — nav: Forums, Chat, Profile with active state
- **OnlineUsers.tsx** — live list of online usernames (from SignalR)
- **ReplyItem.tsx** — avatar, colored username, timestamp, reply text, reply-to link

#### 4b. Color system for usernames

Tailwind: define a username color map based on username hash or role:
`	s
const USERNAME_COLORS = [
  'text-blue-400', 'text-purple-400', 'text-emerald-400',
  'text-pink-400', 'text-amber-400', 'text-cyan-400'
];
// Deterministic hash of username to pick color
`

### Phase 5 — Integration + deploy

#### 5a. Glue steps

1. Build Next.js: 
pm run build in Frontend/
2. Copy Frontend/out/ → WebApi/wwwroot/
3. Verify dotnet run WebApi serves:
   - / → Next.js HTML shell
   - /_next/static/... → JS/CSS
   - /api/* → REST controllers
   - /hub/chat → SignalR
4. Test cross-origin: Next.js dev server proxies /api/* to WebApi

#### 5b. Docker (replaces existing Dockerfile)

`dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS node-builder
WORKDIR /frontend
COPY Frontend/package*.json ./
RUN npm ci
COPY Frontend/ ./
RUN npm run build
RUN npm run build:copy

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=node-builder /frontend/out ./wwwroot
COPY WebApi/bin/Release/net10.0/publish/ ./
EXPOSE 80
CMD ["dotnet", "WebApi.dll"]
`

## Contracts (shared between subagents)

### DTOs (C# → TS interfaces)

`csharp
// AuthDtos
public record LoginRequest(string Username, string Password);
public record LoginResponse(int UserId, string Username, string FullName, string Token);
public record RegisterRequest(string Username, string Password, string FullName);

// ForumDtos
public record ConfView(int Id, string Name, int VolumeNo, string Status, DateTime? FromDate);
public record TopicView(int Id, int ConferenceId, string Subject, string Author, DateTime Created, int ReplyCount);
public record ReplyView(int Id, string Author, string Text, DateTime Created, int? ReplyToId, string? ReplyToAuthor);
public record TopicThread(int TopicId, string Subject, string Author, DateTime Created, List<ReplyView> Replies);

// ChatDtos
public record ChatMessage(string From, string Text, DateTime Created, string RoomId);
public record ChatRoom(string Id, string Name, int OnlineCount, List<string> OnlineUsers);

// UserDtos
public record UserView(int Id, string Username, string FullName, string? City, DateTime? LastCall);
`

### Hub Methods

`csharp
// ChatHub
[HubName("ChatHub")]
public interface IChatHub {
    Task OnJoinRoom(string roomId);
    Task OnMessage(string roomId, string text);
    Task OnDirectMessage(string toUser, string text);
    Task OnUserOnline(string username);
    Task OnUserOffline(string username);
}

// ForumHub
[HubName("ForumHub")]
public interface IForumHub {
    Task OnNewReply(int topicId, ReplyView reply);
    Task OnReadAck(int topicId, int userId);
}
`

### Frontend TS Interfaces (mirror C# DTOs)

`	s
// lib/types/auth.ts
interface LoginRequest { username: string; password: string; }
interface LoginResponse { userId: number; username: string; fullName: string; token: string; }
interface RegisterRequest { username: string; password: string; fullName: string; }

// lib/types/forum.ts
interface ConfView { id: number; name: string; volumeNo: number; status: string; fromDate?: string; }
interface TopicView { id: number; conferenceId: number; subject: string; author: string; created: string; replyCount: number; }
interface ReplyView { id: number; author: string; text: string; created: string; replyToId?: number; replyToAuthor?: string; }
interface TopicThread { topicId: number; subject: string; author: string; created: string; replies: ReplyView[]; }

// lib/types/chat.ts
interface ChatMessage { from: string; text: string; created: string; roomId: string; }
interface ChatRoom { id: string; name: string; onlineCount: number; onlineUsers: string[]; }
`

## Token management strategy (to avoid context exhaustion)

1. **Each subagent gets a focused prompt** — one phase, specific files, exact content
2. **Contracts are pre-written** — subagents reference DTOs/types without re-deriving them
3. **No speculative work** — each subagent only creates files it's explicitly told to create
4. **Review before next phase** — verify output before spawning dependent subagents
5. **Iterate per phase** — don't try to do auth + chat + forum in one shot

## Risk areas to flag

1. **Password hashing** — current User.Password is plain text. Need bcrypt migration. Phase 1 should add hashing to AuthService.
2. **Redis session vs JWT** — the existing SessionInfo model is for Telnet. Need a separate JWT session for WebApi. Don't conflict.
3. **SignalR + existing MessageBroadcaster** — need to ensure the hub doesn't publish messages it receives from Redis (loop). Add a IsFromHub flag on messages.
4. **Static file MIME types** — Next.js output includes .js, .css, .html. Ensure WebApi's UseStaticFiles() serves them correctly.
