# Spec — tenant-svc

> Status: draft
> Version: 0.1.0
> Releases: 0.3.x (individual tenants), 0.5.x (organizations + seats), 0.6.x (server provisioning trigger)

---

## Summary

Tenant management service. Handles organizations, member management, roles, per-seat billing and server provisioning triggers.

Every user has an individual tenant created on registration. Premium users can create organizational tenants, invite members and purchase seats.

**Runtime:** Dart on Cloud Run
**Repo path:** `code/backend/tenant-svc/`

---

## Responsibilities

- Individual tenant creation on user registration (0.3.x)
- Organization CRUD (0.5.x)
- Member invitations and role management (0.5.x)
- Per-seat billing via Stripe (0.5.x)
- Server provisioning trigger to server-svc (0.6.x)

---

## Tenant Model

| Type | Created by | Purpose |
|------|-----------|---------|
| `individual` | Auto on registration | Personal context. Holds the user's progress and tree. |
| `organization` | Premium user manually | Team context. Private knowels, shared server, team dashboard. |

A user can belong to multiple tenants (their individual + one or more organizations).

---

## API Endpoints

### POST /tenants

Create an organization. Caller must be a Premium user.

**Headers:** `Authorization: Bearer <jwt>`

**Request:**
```json
{
  "name": "Acme Corp",
  "billing_email": "billing@acme.com"
}
```

**Response:** `201 Created`
```json
{
  "id": "uuid",
  "name": "Acme Corp",
  "type": "organization",
  "owner_user_id": "uuid",
  "plan": "organization",
  "max_seats": 0,
  "members": [
    { "user_id": "uuid", "role": "owner", "display_name": "Carlos" }
  ]
}
```

**Side effects:**
- Creates `tenants` row with type `organization`.
- Creates `tenant_members` row for the creator with role `owner`.

### GET /tenants/:id

Get tenant details. Caller must be a member.

**Response:** `200 OK`
```json
{
  "id": "uuid",
  "name": "Acme Corp",
  "type": "organization",
  "plan": "organization",
  "max_seats": 10,
  "used_seats": 4,
  "server": {
    "id": "uuid",
    "host": "34.56.78.90",
    "port": 30000,
    "status": "online"
  },
  "subscription": {
    "stripe_subscription_id": "sub_...",
    "status": "active",
    "current_period_end": "2026-07-01T00:00:00Z"
  }
}
```

### PUT /tenants/:id

Update tenant. Caller must be owner or admin.

**Request:**
```json
{
  "name": "Acme Corporation",
  "billing_email": "new-billing@acme.com"
}
```

### GET /tenants/:id/members

List tenant members. Caller must be a member.

**Response:** `200 OK`
```json
{
  "members": [
    { "id": "uuid", "user_id": "uuid", "display_name": "Carlos", "role": "owner", "joined_at": "..." },
    { "id": "uuid", "user_id": "uuid", "display_name": "Alice", "role": "admin", "joined_at": "..." },
    { "id": "uuid", "user_id": "uuid", "display_name": "Bob", "role": "member", "joined_at": "..." }
  ]
}
```

### POST /tenants/:id/members

Invite a member by email. Caller must be owner or admin. Invitation consumes a seat.

**Request:**
```json
{
  "email": "alice@example.com",
  "role": "member"
}
```

**Response:** `201 Created`

**Side effects:**
- If user exists: creates `tenant_members` row.
- If user doesn't exist: sends invitation email. Record created on acceptance.
- Validates `used_seats < max_seats`.

### PUT /tenants/:id/members/:memberId

Update member role. Caller must be owner or admin.

**Request:**
```json
{
  "role": "admin"
}
```

### DELETE /tenants/:id/members/:memberId

Remove a member. Caller must be owner or admin. Sets `removed_at` (soft delete). Frees a seat.

### POST /tenants/:id/subscription

Create or update subscription. Redirects to Stripe Checkout for seat purchase.

**Request:**
```json
{
  "seats": 10
}
```

**Response:** `200 OK`
```json
{
  "checkout_url": "https://checkout.stripe.com/c/pay/..."
}
```

**Webhook flow:**
1. Stripe sends `checkout.session.completed` webhook.
2. tenant-svc updates `max_seats`, `stripe_subscription_id`.
3. If first subscription for this org and 0.6.x+ is deployed: triggers server-svc provisioning.

---

## Roles

| Role | Permissions |
|------|------------|
| `owner` | Full control. Only one per org. Can transfer ownership. |
| `admin` | Invite/remove members, manage roles, view billing. Cannot delete org. |
| `member` | Access org server, private knowels, view team dashboard. |

---

## Stripe Integration (0.5.x)

| Event | Action |
|-------|--------|
| `checkout.session.completed` | Activate subscription, update seats |
| `customer.subscription.updated` | Update plan/seats |
| `customer.subscription.deleted` | Deactivate org, revoke server access |
| `invoice.payment_failed` | Notify owner, grace period |

---

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| PostgreSQL | Store tenants, members |
| auth-svc | Validate JWT, resolve user identity |
| server-svc | Trigger server provisioning on org activation (0.6.x) |
| Stripe API | Subscription management, checkout, webhooks |

---

## Security

- All endpoints require a valid JWT (validated via `modular-api` middleware).
- Org mutations (create, invite, remove member) require `owner` or `admin` role.
- Stripe webhook endpoint validates Stripe signature (`Stripe-Signature` header).
- Rate limiting on invitation endpoints to prevent abuse.

---

## Observability

Integrated via `modular-api` package: structured logging, request metrics, and distributed tracing.

---

## Open Questions

- Whether org members must also have their own Premium subscription or if the org seat covers them.
- Invitation flow: email link vs invitation code vs direct add.
- Grace period duration after payment failure before revoking access.
- Whether to support transferring ownership of an organization.
- Minimum and maximum seat counts per organization.
