# Spec — auth-svc

> Status: draft
> Version: 0.1.0
> Release: 0.3.x

---

## Summary

Authentication and identity service. Uses Firebase Auth as the identity provider and issues JWT tokens for authenticating against all other Trivium backend services.

Public registration requires payment (Premium plan). Free accounts are created exclusively via CLI admin tool.

**Runtime:** Dart on Cloud Run
**Repo path:** `code/backend/auth-svc/`

---

## Responsibilities

- User registration (Firebase Auth + PostgreSQL record)
- Login and JWT token issuance
- Token validation for other services
- Account linking (a user can belong to multiple tenants)
- CLI admin tool for creating free/dev accounts

---

## API Endpoints

### POST /auth/register

Register a new user. Creates Firebase Auth account and PostgreSQL record. In the public flow, this is called after Stripe Checkout succeeds (0.4.x).

**Request:**
```json
{
  "firebase_token": "eyJhbGciOi...",
  "luanti_username": "carlos_dev",
  "display_name": "Carlos"
}
```

**Response:** `201 Created`
```json
{
  "user": {
    "id": "uuid",
    "email": "carlos@example.com",
    "luanti_username": "carlos_dev",
    "display_name": "Carlos",
    "active_tenant_id": "uuid"
  },
  "token": "eyJhbGciOi..."
}
```

**Side effects:**
- Creates a `users` row.
- Creates an `individual` tenant for the user (with `premium` plan in production).
- Creates a `tenant_members` row (role: `owner`).

### POST /auth/login

Exchange a Firebase ID token for a Trivium JWT.

**Request:**
```json
{
  "firebase_token": "eyJhbGciOi...",
  "tenant_id": "uuid" // Optional context
}
```

**Response:** `200 OK`
```json
{
  "user": {
    "id": "uuid",
    "email": "carlos@example.com",
    "luanti_username": "carlos_dev",
    "display_name": "Carlos",
    "active_tenant_id": "uuid",
    "tenants": [
      { "id": "uuid", "name": "Personal", "type": "individual", "role": "owner", "plan": "premium" },
      { "id": "uuid", "name": "Acme Corp", "type": "organization", "role": "member", "plan": "organization" }
    ]
  },
  "token": "eyJhbGciOi..."
}
```

### GET /auth/me

Get the authenticated user's profile.

**Headers:** `Authorization: Bearer <jwt>`

**Response:** `200 OK`
```json
{
  "id": "uuid",
  "email": "carlos@example.com",
  "luanti_username": "carlos_dev",
  "display_name": "Carlos",
  "active_tenant_id": "uuid",
  "tenants": [...]
}
```

### PUT /auth/me

Update the authenticated user's profile.

**Headers:** `Authorization: Bearer <jwt>`

**Request:**
```json
{
  "display_name": "Carlos C."
}
```

**Response:** `200 OK`

### DELETE /auth/me

Eliminar cuenta (GDPR compliance). Realiza soft-delete en la base de datos y elimina de Firebase.

**Headers:** `Authorization: Bearer <jwt>`

**Response:** `200 OK`

### POST /auth/livekit-token

Genera un token firmado para conectarse a las salas de LiveKit. Autenticado con JWT.

**Headers:** `Authorization: Bearer <jwt>`

**Request:**
```json
{
  "room_name": "global",
  "participant_name": "carlos_dev"
}
```

**Response:** `200 OK`
```json
{
  "livekit_token": "eyJhbGciOi..."
}
```

### GET /auth/verify

Endpoint interno/seguro para el mod `server-side` que valida identidad e ingresos.
*(Nota de seguridad C1: Requiere un "Join Token" temporal u otro mecanismo moderno TBD, en vez de consultar solo por nombre para evitar suplantación).*

**Query:** `?join_token={token}` o Headers internos.

**Response:** `200 OK`
```json
{
  "luanti_username": "carlos_dev",
  "registered": true,
  "active_tenant_id": "uuid",
  "tenant_plan": "premium"
}
```

---

## JWT Token

| Field | Value |
|-------|-------|
| Issuer | `trivium-auth` |
| Subject | User UUID |
| Expiry | 24 hours |
| Claims | `luanti_username`, `email`, `active_tenant_id`, `tenant_plan`, `roles` |
| Algorithm | RS256 |

All other backend services validate JWTs using auth-svc's public key.

---

## Observability & Metrics

Integration out-of-the-box using custom `modular-api` package:
- Integrated Structured Logging
- Application Metrics
- Automatic Request Tracing

---

## CLI Admin Tool

```bash
# Create a free dev account
dart run bin/seed_user.dart --email dev@trivium.world --plan free --role admin

# Create a premium test account
dart run bin/seed_user.dart --email tester@example.com --plan premium

# List all dev accounts
dart run bin/seed_user.dart --list
```

The CLI:
1. Creates the user in Firebase Auth (Admin SDK)
2. Inserts the record in PostgreSQL with the specified plan
3. Creates an individual tenant for the user
4. Prints the user ID and credentials

---

## Security

- All endpoints except `/auth/register` and `/auth/login` require a valid JWT.
- Firebase ID tokens are verified using Firebase Admin SDK.
- Rate limiting on `/auth/register` and `/auth/login` to prevent abuse.
- Passwords are managed by Firebase Auth (never stored in PostgreSQL).
- JWTs are signed with RS256 (asymmetric) so any service can verify without the private key.

---

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| Firebase Admin SDK (Dart) | Verify Firebase ID tokens, create users via CLI |
| PostgreSQL | Store user records, tenant associations |
| tenant-svc | Notified to create individual tenant on registration |

---

## Open Questions

- Whether auth-svc should issue LiveKit room tokens or if that's a separate concern.
- Whether to support social login providers (Google, GitHub) via Firebase Auth in addition to email/password.
- Token refresh strategy (short-lived access + refresh token, or single long-lived JWT).
