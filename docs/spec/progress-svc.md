# Spec — progress-svc

> Status: draft
> Version: 0.1.0
> Release: 0.7.x

---

## Summary

Knowel progress and Tree of Noesis persistence service. Tracks which knowels each user has completed, their quiz scores, skill tree state and personal tree growth.

Receives updates from both the mod (server-side) and the companion app.

**Runtime:** Dart on Cloud Run
**Repo path:** `code/backend/progress-svc/`

---

## Responsibilities

- Record knowel completion status and quiz scores
- Persist Tree of Noesis state per user per tenant
- Track skill tree: unlocked branches, specializations, masteries
- Sync progress from mod and companion app
- Provide progress data for team dashboards (org context)

---

## API Endpoints

### GET /progress

Get all knowel progress for the authenticated user in a given tenant context.

**Headers:** `Authorization: Bearer <jwt>`
**Query:** `?tenant_id={uuid}`

**Response:** `200 OK`
```json
{
  "user_id": "uuid",
  "tenant_id": "uuid",
  "knowels": [
    {
      "knowel_id": "uuid",
      "slug": "git-branching",
      "status": "completed",
      "quiz_score": 85,
      "completed_at": "2026-06-15T10:30:00Z"
    },
    {
      "knowel_id": "uuid",
      "slug": "docker-basics",
      "status": "in-progress",
      "quiz_score": null,
      "completed_at": null
    },
    {
      "knowel_id": "uuid",
      "slug": "kubernetes-pods",
      "status": "available",
      "quiz_score": null,
      "completed_at": null
    }
  ],
  "stats": {
    "total_available": 42,
    "in_progress": 3,
    "completed": 12
  }
}
```

### GET /progress/:knowelId

Get progress for a specific knowel.

**Response:** `200 OK`
```json
{
  "knowel_id": "uuid",
  "status": "completed",
  "quiz_score": 85,
  "attempts": 2,
  "completed_at": "2026-06-15T10:30:00Z"
}
```

### PUT /progress/:knowelId

Update progress for a specific knowel. Called by the mod after a quiz or by knowel-svc after evaluation.

**Request:**
```json
{
  "tenant_id": "uuid",
  "status": "completed",
  "quiz_score": 85
}
```

**Response:** `200 OK`

**Side effects:**
- Updates `user_progress` row.
- If status changed to `completed`: updates tree state (adds branch/growth).
- Checks for newly unlockable knowels (prerequisites met).

### GET /tree

Get the user's personal Tree of Noesis state.

**Headers:** `Authorization: Bearer <jwt>`
**Query:** `?tenant_id={uuid}`

**Response:** `200 OK`
```json
{
  "user_id": "uuid",
  "tenant_id": "uuid",
  "tree_state": {
    "planted_at": "2026-06-01T00:00:00Z",
    "growth_level": 3,
    "branches": [
      {
        "domain": "devops",
        "knowels_completed": 5,
        "knowels_total": 12,
        "mastery": "intermediate"
      },
      {
        "domain": "frontend",
        "knowels_completed": 7,
        "knowels_total": 15,
        "mastery": "advanced"
      }
    ],
    "total_petals": 42,
    "integrated_petals": 12
  },
  "updated_at": "2026-06-15T10:30:00Z"
}
```

### PUT /tree

Update tree state. Called after knowel completion triggers tree growth.

**Request:**
```json
{
  "tenant_id": "uuid",
  "tree_state": { ... }
}
```

### GET /progress/team

Get team progress for an organization. Caller must be owner or admin of the tenant.

**Query:** `?tenant_id={uuid}`

**Response:** `200 OK`
```json
{
  "tenant_id": "uuid",
  "members": [
    {
      "user_id": "uuid",
      "display_name": "Alice",
      "completed": 12,
      "in_progress": 3,
      "last_activity": "2026-06-15T10:30:00Z"
    },
    {
      "user_id": "uuid",
      "display_name": "Bob",
      "completed": 8,
      "in_progress": 1,
      "last_activity": "2026-06-14T16:00:00Z"
    }
  ]
}
```

---

## Progress States

```
available → in-progress → completed
                ↓
            failed (can retry → in-progress)
```

| Status | Meaning |
|--------|---------|
| `available` | Knowel exists and prerequisites are met. User hasn't started. |
| `in-progress` | User has begun but not yet verified. |
| `completed` | Quiz passed. Knowel is a verified capability. |
| `locked` | Prerequisites not yet met. Not directly set — computed from graph. |

---

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| PostgreSQL | Store user_progress, user_tree_branches, user_tree_unlocks |
| auth-svc | Validate JWT, resolve user identity |
| knowel-svc | Read knowel graph to determine unlocks |
| tenant-svc | Verify tenant membership for team queries |

---

## Security

- All endpoints require a valid JWT (validated via `modular-api` middleware).
- Progress writes are scoped to the authenticated user — a user cannot modify another user's progress.
- Team dashboard endpoint requires `owner` or `admin` role on the tenant.

---

## Observability

Integrated via `modular-api` package: structured logging, request metrics, and distributed tracing.

---

## Open Questions

- Whether progress should decay over time (knowels not reviewed lose "freshness").
- How to handle progress when a user belongs to multiple tenants (separate per tenant or merged view).
- Whether to store quiz attempt history or only latest score.
- How tree growth maps exactly to knowel completion (linear, exponential, domain-based).
