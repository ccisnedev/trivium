# Proximity Chat Test Manual

> Purpose: acceptance test procedure for release `0.0.3`
> Scope: Trivium text proximity chat only

---

## Goal

Validate that the Trivium mod delivers text messages only to players inside the configured radius, using the three supported scopes:

- `talk` by default chat input
- `whisper` via `/w` or `/whisper`
- `shout` via `/s` or `/shout`

Release `0.0.3` passes only if the server stays stable and the chat behavior matches the configured radii.

---

## Expected Radii

| Scope | Trigger | Radius | Expected format |
|-------|---------|--------|-----------------|
| Talk | normal chat input | 32 nodes | `[talk] <player> says: <message>` |
| Whisper | `/w <message>` or `/whisper <message>` | 8 nodes | `[whisper] <player> whispers: <message>` |
| Shout | `/s <message>` or `/shout <message>` | 128 nodes | `[shout] <player> shouts: <message>` |

---

## Preconditions

- The office server is reachable at `office.cacsi.dev:30000`.
- The server process is running and the world loads normally.
- At least 2 players are available for the test.
- 3 players are preferred for faster validation: one sender, one receiver inside radius, one receiver outside radius.
- Players should test on mostly flat terrain and stay on similar altitude to avoid distance confusion.
- Use any reliable way to estimate distance. If debug coordinates are available, use them. Otherwise count approximate nodes on flat ground.

---

## Test Roles

- `Player A`: sender
- `Player B`: receiver inside radius
- `Player C`: receiver outside radius, if available

If only 2 players are available, move `Player B` between inside-range and outside-range positions for each case.

---

## Test Sequence

Run the cases in this order.

### Case 1: Talk inside radius

Setup:

- Place `Player B` within 32 nodes of `Player A`.
- Place `Player C` farther than 32 nodes, if available.

Action:

- `Player A` sends a normal chat message with no slash command.

Expected result:

- `Player A` sees the delivered message.
- `Player B` sees the delivered message.
- `Player C` does not see the message.
- The line format is `[talk] <player> says: <message>`.

Pass checklist:

- [ ] Sender sees talk message
- [ ] In-range player sees talk message
- [ ] Out-of-range player does not see talk message
- [ ] Format is correct

### Case 2: Talk outside radius

Setup:

- Place `Player B` farther than 32 nodes from `Player A`.

Action:

- `Player A` sends a normal chat message.

Expected result:

- `Player A` sees the delivered message.
- `Player B` does not see the message.
- No global broadcast appears.

Pass checklist:

- [ ] Sender still sees talk message
- [ ] Out-of-range player does not see talk message
- [ ] No unintended global broadcast

### Case 3: Whisper inside radius

Setup:

- Place `Player B` within 8 nodes of `Player A`.
- Place `Player C` farther than 8 nodes, if available.

Action:

- `Player A` sends `/w hello`.
- Repeat with `/whisper hello`.

Expected result:

- `Player A` sees the delivered message in both variants.
- `Player B` sees the delivered message in both variants.
- `Player C` does not see the message.
- The line format is `[whisper] <player> whispers: <message>`.

Pass checklist:

- [ ] `/w` works inside radius
- [ ] `/whisper` works inside radius
- [ ] Sender sees whisper message
- [ ] In-range player sees whisper message
- [ ] Out-of-range player does not see whisper message
- [ ] Format is correct

### Case 4: Whisper outside radius

Setup:

- Place `Player B` farther than 8 nodes from `Player A`.

Action:

- `Player A` sends `/w hello`.
- Repeat with `/whisper hello`.

Expected result:

- `Player A` sees the delivered message.
- `Player B` does not see the message.

Pass checklist:

- [ ] Sender still sees whisper message
- [ ] Out-of-range player does not see whisper message

### Case 5: Shout inside radius

Setup:

- Place `Player B` within 128 nodes of `Player A`.
- Place `Player C` farther than 128 nodes, if available.

Action:

- `Player A` sends `/s hello`.
- Repeat with `/shout hello`.

Expected result:

- `Player A` sees the delivered message in both variants.
- `Player B` sees the delivered message in both variants.
- `Player C` does not see the message.
- The line format is `[shout] <player> shouts: <message>`.

Pass checklist:

- [ ] `/s` works inside radius
- [ ] `/shout` works inside radius
- [ ] Sender sees shout message
- [ ] In-range player sees shout message
- [ ] Out-of-range player does not see shout message
- [ ] Format is correct

### Case 6: Shout outside radius

Setup:

- Place `Player B` farther than 128 nodes from `Player A`.

Action:

- `Player A` sends `/s hello`.
- Repeat with `/shout hello`.

Expected result:

- `Player A` sees the delivered message.
- `Player B` does not see the message.

Pass checklist:

- [ ] Sender still sees shout message
- [ ] Out-of-range player does not see shout message

### Case 7: Empty message handling

Action:

- `Player A` sends a normal chat message containing only spaces.
- `Player A` sends `/w` with no message.
- `Player A` sends `/whisper` with no message.
- `Player A` sends `/s` with no message.
- `Player A` sends `/shout` with no message.

Expected result:

- Empty default talk returns `Message cannot be empty.` only to the sender.
- `/w` with no payload returns `Usage: /w <message>`.
- `/whisper` with no payload returns `Usage: /whisper <message>`.
- `/s` with no payload returns `Usage: /s <message>`.
- `/shout` with no payload returns `Usage: /shout <message>`.
- No other player sees anything from these invalid attempts.

Pass checklist:

- [ ] Empty talk is rejected
- [ ] Empty `/w` shows usage
- [ ] Empty `/whisper` shows usage
- [ ] Empty `/s` shows usage
- [ ] Empty `/shout` shows usage
- [ ] Invalid attempts are not broadcast

### Case 8: Stability after chat activity

Action:

- Exchange several messages using all three scopes.
- Keep playing for a short period.
- Optionally reconnect one player.

Expected result:

- The server remains reachable.
- Players can continue moving and interacting normally.
- No crash or disconnect loop appears because of chat handling.

Pass checklist:

- [ ] Server remains reachable
- [ ] Players continue normally after chat activity
- [ ] No visible chat-related crash or loop

---

## Minimal Distance Plan for Two Players

If you only have 2 players, test these approximate distances in order:

1. `5` nodes: should pass `talk`, `whisper`, and `shout`
2. `20` nodes: should pass `talk` and `shout`, but fail `whisper`
3. `40` nodes: should pass `shout`, but fail `talk` and `whisper`
4. `100` nodes: should still pass `shout`
5. `140` nodes: should fail `shout`

---

## Release Gate

Release `0.0.3` can be marked complete only when all these statements are true:

- [ ] Talk is limited to 32 nodes
- [ ] Whisper is limited to 8 nodes
- [ ] Shout is limited to 128 nodes
- [ ] Sender always sees the delivered message
- [ ] Out-of-range players see nothing
- [ ] Empty inputs are rejected correctly
- [ ] The server remains stable during and after the test

---

## Notes

- This manual validates gameplay behavior, not just server startup.
- Passing `systemctl is-active trivium-office` is necessary but not sufficient.
- If any case fails, record which scope failed, at what approximate distance, and whether the failure was over-delivery, under-delivery, bad formatting, or stability-related.