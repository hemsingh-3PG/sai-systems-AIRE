# PacEHR — Auth, Identity & Tenancy Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/01-auth-identity-tenancy-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Login — password to opaque session token

How a user signs in, how the password is checked, and where the session token comes from.

```mermaid
sequenceDiagram
  participant U as Browser (SPA)
  participant MW as JWTMiddleware
  participant C as UserController.verifyUser
  participant S as UserService
  participant P as PasswordHelper
  participant DB as SQL Server

  U->>MW: POST /verifyUser (AES body, no token header)
  Note over MW: [AllowAnonymous] → skip auth,<br/>but body still decrypted first
  MW->>C: forward
  C->>S: verifyUser(email, password)
  S->>DB: usp_verifyUser(@email)
  DB-->>S: user row incl. PasswordHash
  alt MustResetPassword OR legacy $2 BCrypt hash
    S-->>C: MustResetPassword = true
    C-->>U: 200 status MustReset
  else
    S->>P: Verify(password, hash, staticSalt)
    P-->>S: bool (FixedTimeEquals)
  end
  C->>C: token = Guid.NewGuid()
  C->>S: setDatabaseSession(userId, email, accountId, accountName, token)
  S->>DB: usp_InsertSession(...)
  C-->>U: 200 result + token + isIPActive + VideoCallURL
```

---

## 2. Every authenticated request

The middleware pipeline each call passes through — and the point where controllers stop using the identity the middleware derived.

```mermaid
sequenceDiagram
  participant U as Browser
  participant FH as ForwardedHeaders
  participant AU as AuditMiddleware
  participant MW as JWTMiddleware
  participant DB as SQL Server
  participant CT as Controller

  U->>FH: POST /getPatientById<br/>headers token accountID userID accountName (all AES)
  FH->>AU: X-Forwarded-For honoured
  AU->>MW: (if AuditMode==1)

  Note over MW: 1. if path not excluded:<br/>buffer body, if no brace then AES-decrypt
  Note over MW: 2. AllowAnonymous then pass through
  MW->>MW: token = headers token<br/>CryptoHelper.Decrypt(token, SecretKey123)
  alt token contains Bearer
    MW->>DB: usp_getAPIAccessToken(token)
    Note over MW: only for /downloadxmlfile or fhir<br/>otherwise 401
  else opaque GUID
    MW->>DB: usp_saveUserTokens(token, empty)
    DB-->>MW: authorizationStatus userId accountId accountName email
    alt Unauthorized
      MW-->>U: 401 status F errorCode 401
    else
      MW->>MW: HttpContext.Items userId accountId
    end
  end
  MW->>CT: next()
  Note over CT: controller calls GetHeaders(),<br/>reading identity from CLIENT headers,<br/>not from HttpContext.Items
  CT->>DB: proc(accountId from header, ...)
```

---

## 3. Session lifetime

Why sessions last 50 hours from login rather than sliding with activity, and why logout leaves the token usable.

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
    anywhere in the SSDT project. Rows
    accumulate and the token stays valid
    until the 3000-minute window lapses.
  end note
  note right of Active
    The sliding-expiry UPDATE filters on
    token AND accountName, but both callers
    pass accountName = empty string. The
    UPDATE matches 0 rows, so lastLogin is
    never refreshed: expiry is absolute,
    not sliding.
  end note
```

---

## 4. FHIR / external client

The path an external FHIR caller takes — and the scope-checking filter that is never invoked.

```mermaid
sequenceDiagram
  participant X as External FHIR client
  participant MW as JWTMiddleware
  participant DB as SQL Server
  participant F as Fhir Controller

  X->>MW: GET /fhir/Patient with Authorization Bearer jwt
  Note over MW: path /fhir is excluded,<br/>body decryption skipped
  MW->>MW: token = Authorization header<br/>CryptoHelper.Decrypt(token, SecretKey123)
  Note over MW: a real Bearer JWT is not AES ciphertext,<br/>so decrypt throws and returns 401
  MW->>DB: usp_getAPIAccessToken(token) if decrypt succeeded
  MW->>F: next()
  Note over F: FhirAuthenticationAttribute is NOT applied.<br/>No scope checking runs.
```

---

**Full analysis**: `docs/architecture/current/01-auth-identity-tenancy-deep-dive.md`
