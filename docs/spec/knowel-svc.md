# Spec — knowel-svc

> Status: draft
> Version: 0.1.0
> Releases: 0.7.x (catalog + private knowels), 0.8.x (quizzes + graph + recommendations)

---

## Summary

Knowel catalog and verification service. Manages the knowels available in Trivium, their prerequisite relationships, private knowels per organization, quiz generation and evaluation.

Can optionally sync knowels from the external Knowel project's API.

**Runtime:** Dart on Cloud Run
**Repo path:** `code/backend/knowel-svc/`

---

## Responsibilities

- Knowel CRUD (public and tenant-private)
- Prerequisite and derivation graph management
- Quiz generation and answer evaluation
- Recommendations based on graph and user progress
- Optional integration with external Knowel project API

---

## API Endpoints

### GET /knowels

List knowels. Returns public knowels plus private knowels for the caller's tenant.

**Headers:** `Authorization: Bearer <jwt>`
**Query:** `?tenant_id={uuid}&domain={domain}&page={n}&limit={n}`

**Response:** `200 OK`
```json
{
  "knowels": [
    {
      "id": "uuid",
      "slug": "git-branching",
      "title": "Git Branching Strategies",
      "domain": "devops",
      "tenant_id": null,
      "prerequisites": ["git-basics"],
      "status": "published"
    },
    {
      "id": "uuid",
      "slug": "internal-ci-pipeline",
      "title": "Our CI Pipeline",
      "domain": "internal",
      "tenant_id": "uuid",
      "prerequisites": ["git-branching", "docker-basics"],
      "status": "published"
    }
  ],
  "total": 42,
  "page": 1,
  "limit": 20
}
```

### GET /knowels/:id

Get full knowel details.

**Response:** `200 OK`
```json
{
  "id": "uuid",
  "slug": "git-branching",
  "title": "Git Branching Strategies",
  "domain": "devops",
  "tenant_id": null,
  "content": {
    "description": "Understanding trunk-based, gitflow and feature branch strategies.",
    "objectives": [
      "Explain three branching strategies",
      "Choose the right strategy for a given project",
      "Create and manage feature branches"
    ],
    "resources": []
  },
  "prerequisites": [
    { "id": "uuid", "slug": "git-basics", "title": "Git Basics" }
  ],
  "derivations": [
    { "id": "uuid", "slug": "git-rebasing", "title": "Git Rebasing" }
  ]
}
```

### POST /knowels

Create a knowel. Public knowels require admin role. Tenant-private knowels require org admin/owner.

**Request:**
```json
{
  "slug": "git-branching",
  "title": "Git Branching Strategies",
  "domain": "devops",
  "tenant_id": null,
  "content": {
    "description": "...",
    "objectives": ["..."]
  }
}
```

### PUT /knowels/:id

Update a knowel.

### DELETE /knowels/:id

Soft-delete a knowel. Does not delete user progress.

### GET /knowels/:id/links

Get prerequisite and derivation relationships.

**Response:** `200 OK`
```json
{
  "prerequisites": [
    { "id": "uuid", "slug": "git-basics", "link_type": "prerequisite" }
  ],
  "derivations": [
    { "id": "uuid", "slug": "git-rebasing", "link_type": "prerequisite" }
  ]
}
```

### POST /knowels/:id/links

Create a relationship between two knowels.

**Request:**
```json
{
  "target_id": "uuid",
  "link_type": "prerequisite"
}
```

### GET /knowels/:id/quiz

Generate quiz questions for a knowel.

**Response:** `200 OK`
```json
{
  "knowel_id": "uuid",
  "questions": [
    {
      "id": "q1",
      "type": "multiple_choice",
      "question": "Which branching strategy uses a single long-lived branch?",
      "options": [
        { "key": "a", "text": "Gitflow" },
        { "key": "b", "text": "Trunk-based development" },
        { "key": "c", "text": "Feature branching" },
        { "key": "d", "text": "Release branching" }
      ]
    },
    {
      "id": "q2",
      "type": "short_answer",
      "question": "What is the main advantage of feature branches?"
    }
  ]
}
```

### POST /knowels/:id/quiz/evaluate

Evaluate quiz answers and update progress.

**Request:**
```json
{
  "tenant_id": "uuid",
  "answers": [
    { "question_id": "q1", "answer": "b" },
    { "question_id": "q2", "answer": "Isolation of work in progress from the main branch" }
  ]
}
```

**Response:** `200 OK`
```json
{
  "score": 85,
  "passed": true,
  "threshold": 70,
  "feedback": [
    { "question_id": "q1", "correct": true },
    { "question_id": "q2", "correct": true, "note": "Good explanation." }
  ]
}
```

**Side effects:**
- Calls progress-svc to update the user's knowel status.
- If passed: knowel marked as `completed`. Tree growth triggered.

### GET /knowels/recommendations

Suggest next knowels based on user progress and graph.

**Query:** `?tenant_id={uuid}&limit={n}`

**Response:** `200 OK`
```json
{
  "recommendations": [
    {
      "knowel_id": "uuid",
      "slug": "docker-compose",
      "title": "Docker Compose",
      "reason": "prerequisite_met",
      "prerequisites_completed": 2,
      "prerequisites_total": 2
    }
  ]
}
```

---

## Knowel Visibility

| `tenant_id` | Visibility |
|-------------|-----------|
| `NULL` | Public. Visible to all users. |
| `uuid` | Private. Visible only to members of that tenant. |

Org admins/owners can create private knowels for internal training. Public knowels are managed by Trivium platform admins.

---

## Quiz Evaluation

- **Multiple choice:** exact match.
- **Short answer:** evaluated via similarity scoring or LLM-based assessment (TBD).
- **Passing threshold:** 70% (configurable per knowel).
- **Retries:** unlimited. Only latest score is stored.

---

## External Knowel Integration (optional)

If configured, knowel-svc can sync knowels from the external Knowel project:

| Operation | Detail |
|-----------|--------|
| Import catalog | Periodic sync of knowel definitions from Knowel API. |
| Import graph | Prerequisite relationships from Knowel's knowledge graph. |
| One-way sync | Knowel project → knowel-svc. Changes in knowel-svc don't propagate back. |
| Toggle | Enabled via env var `KNOWEL_API_URL`. Disabled by default. |

---

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| PostgreSQL | Store knowels, knowel_links |
| auth-svc | Validate JWT, determine user's tenants |
| progress-svc | Update user progress after quiz evaluation |
| Knowel API (optional) | Sync knowels from external project |

---

## Security

- All endpoints require a valid JWT (validated via `modular-api` middleware).
- Private knowel access is restricted to members of the owning tenant (enforced by RLS).
- Knowel CRUD mutations require `owner` or `admin` role on the tenant.
- Quiz evaluation inputs are sanitized to prevent injection.

---

## Observability

Integrated via `modular-api` package: structured logging, request metrics, and distributed tracing.

---

## Open Questions

- Short answer evaluation method: keyword matching, embedding similarity, or LLM-based.
- Whether quizzes are pre-authored per knowel or generated dynamically.
- Whether to support quiz types beyond multiple choice and short answer (code challenges, demonstrations).
- Maximum number of private knowels per organization.
- Whether knowel content includes learning materials or only objectives and verification.
