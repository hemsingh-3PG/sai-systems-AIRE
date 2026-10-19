# PacEHR - Auth, Identity & Tenancy Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/01-auth-identity-tenancy-deep-dive.md`
**Status**: Draft (awaiting user confirmation)

---

## 1. Workflow 1: Login (password to opaque session token)

```mermaid
sequenceDiagram
  participant U as Browser (SPA)
  participant MW as JWTMiddleware
  participant C as UserController.verifyUser
  participant S as UserService
  participant P as PasswordHelper
  participant DB as SQL Server

  U->>MW: POST /verifyUser (AES body, no token header)
  Note over MW: AllowAnonymous so auth is skipped,<br/>but the body is still decrypted first
  MW->>C: forward
  C->>S: verifyUser(email, password)
  S->>DB: usp_verifyUser(@email)
  DB-->>S: user row incl. PasswordHash
  alt MustResetPassword OR legacy BCrypt hash
    S-->>C: MustResetPassword = true
    C-->>U: 200 flag MustReset, empty token
  else
    S->>P: Verify(password, hash, staticSalt)
    P-->>S: bool (FixedTimeEquals)
  end
  alt active, unlocked, DaysSinceLastLogin at most 14
    C->>C: token = Guid.NewGuid()
    C->>S: setDatabaseSession(userId, email, accountId, accountName, token)
    S->>DB: usp_InsertSession(...)
    C-->>U: 200 result + token + isIPActive + VideoCallURL
  else inactive 14 days or more
    C-->>U: 200 flag Expired, empty token
  end
```

## 2. Workflow 2: Every authenticated request

```mermaid
sequenceDiagram
  participant U as Browser
  participant FH as ForwardedHeaders
  participant EH as ErrorHandleMiddelware (only if ErrorLogMode 1)
  participant AU as AuditMiddleware (only if AuditMode 1)
  participant MW as JWTMiddleware
  participant DB as SQL Server
  participant CT as Controller

  U->>FH: POST /getPatientById<br/>headers token accountID userID accountName (all AES)
  FH->>EH: X-Forwarded-For honoured
  EH->>AU: pass
  AU->>MW: audit written first, then next
  Note over MW: 1. if path not in excludedPaths:<br/>buffer body, if no brace then AES-decrypt
  Note over MW: 2. AllowAnonymous then pass through
  MW->>MW: token = headers token<br/>CryptoHelper.Decrypt(token, SecretKey123)
  alt token contains Bearer
    MW->>DB: usp_getAPIAccessToken(token)
    Note over MW: only for /downloadxmlfile or fhir paths,<br/>otherwise 401
  else opaque GUID
    MW->>DB: usp_saveUserTokens(token, empty accountName)
    DB-->>MW: authorizationStatus userId accountId accountName email
    alt Unauthorized
      MW-->>U: 401 status F errorCode 401
    else
      MW->>MW: HttpContext.Items userId accountId accountName email
    end
  end
  MW->>CT: next()
  alt legacy majority (156 call sites)
    Note over CT: GetHeaders() reads identity from CLIENT headers
    CT->>DB: proc(accountId from header, ...)
  else newer endpoints (PAC-1388/1389/1392/1317)
    Note over CT: AuthenticatedUserId() reads Items userId,<br/>CallerIsMemberOf checks role in header account
    CT->>DB: proc(userId from session, accountId from header after membership check)
  end
```

## 3. Workflow 3: Session lifetime

```mermaid
stateDiagram-v2
  [*] --> NoSession
  NoSession --> Active: verifyUser succeeds, usp_InsertSession writes lastLogin
  Active --> Active: request arrives, usp_saveUserTokens checks DATEDIFF under 3000 min
  Active --> Expired: 3000 minutes (50h) after lastLogin
  Expired --> [*]: 401 Session expired
  Active --> Orphaned: user logs out
  note right of Orphaned
    No DELETE against Account.session exists
    anywhere in the SSDT project. logOutRedirect
    only logs and returns a body. Rows
    accumulate and the token stays valid
    until the 3000-minute window lapses.
  end note
  note right of Active
    The sliding-expiry UPDATE filters on
    token AND accountName, but the middleware
    passes accountName = empty string. The
    UPDATE matches 0 rows, so lastLogin is
    never refreshed: expiry is absolute,
    not sliding.
  end note
```

## 4. Workflow 4: FHIR / external client

```mermaid
sequenceDiagram
  participant X as External FHIR client
  participant MW as JWTMiddleware
  participant DB as SQL Server
  participant F as Fhir Controller

  X->>MW: GET /fhir/Patient with Authorization Bearer jwt
  Note over MW: excludedPaths is exact match on /fhir,<br/>so /fhir/Patient is not excluded.<br/>A GET has no body so decryption is a no-op
  MW->>MW: token = Authorization header<br/>CryptoHelper.Decrypt(token, SecretKey123)
  Note over MW: a real Bearer JWT is not AES ciphertext,<br/>so decrypt throws and the response is 401
  MW->>DB: usp_getAPIAccessToken(token) only if decrypt succeeded
  MW->>F: next()
  Note over F: FhirAuthenticationAttribute is NOT applied.<br/>No scope checking runs.
```

## 5. Data Models

```mermaid
erDiagram
  USERS ||--o{ SESSION : "userId, no FK"
  ACCOUNTS ||--o{ SESSION : "accountId, no FK"
  USERS }o--o{ ROLES : "via user role rows"
  SESSION {
    int sessionId PK
    int userId
    varchar email
    int accountId
    varchar accountName
    varchar token
    datetime lastLogin
  }
  ROLES {
    int roleID PK
    varchar roleName
    int isActive
    varchar reportIds
    nvarchar abbreviation
  }
```
