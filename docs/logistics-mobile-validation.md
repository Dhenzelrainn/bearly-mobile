# Logistics Mobile Validation

## Phase L1 and L2 — Operator-reported device validation

The operator reports that Logistics role login, the dashboard, Code 128 camera scanning, and manual waybill lookup were exercised successfully on a Samsung Android phone before Phase L3-A. The reported L2 screen showed:

- `BRLY-0D2WODACCFYU3D08BG8C` as Delivered.
- `BRLY-P37CPITUW58BFGPRYNU1` as Out for Delivery.
- Historical Sorting Center intake was distinguished from current parcel status.

These are recorded as device/UI observations supplied in the Phase L3-A implementation brief. This note does not claim an independent database verification of those shipment states.

## Phase L3-A — Incoming parcel receipt

The implementation adds an authenticated mobile adapter to the existing Web `ParcelIntakeService`. Lookup eligibility is advisory; receipt is only submitted after an explicit confirmation and is revalidated by Laravel inside the existing transaction. City handoffs remain a separate workflow and are not accepted through ordinary receipt.

No live receipt mutation was performed as part of implementation. Shipments #10 and #11 were excluded. The first device test must use a parcel whose current state is verified as `created` or `picked_up`, belongs to the signed-in Logistics provider, and has physically arrived at that provider's active Sorting Center. Confirm the receipt once, then verify the server-returned state and Web incoming-parcel view before proceeding.

## Phase L3-B — City handoff acceptance

### Read-only verification of the L3-A parcel

The staging check explicitly selected `bearly_latest_dev_import_20261028` and verified the waybill `BRLY-ULD904RGCHZK1SIDLUND`:

- Shipment #12 (`SHP-Y1UO5AHT0PL4XMRVFPYV`) is `at_sorting_center`; its parcel #12 (`PCL-6WLXGU2SQ0TDWEIA1MZH`) is `received` at Victoria Logistics profile #3, center SC-3.
- Six shipment events exist, including exactly one `received_at_center`; no handoff transfer exists yet.
- There are no COD collections or shipping settlements for this shipment, and `cod_collected_at` is null. Its order has one `pending` payment record timestamped before the receipt event; this was not changed by parcel intake. No return request is linked to the order or seller order.
- Destination provider profile #1 (PB Sorting Center) and its owner are active Logistics accounts. It has exactly one active center (SC-1), and its active zone covers the parcel destination `Pinagbayanan, Pila, Laguna`.

These are read-only database findings. The source parcel is eligible for the normal Victoria Web handoff-send workflow, but the inspection did not create a transfer or accept a handoff. Physical custody/arrival remains an operator confirmation, not an inference from database state.

### Implementation and automated validation

The Mobile API adapter reuses Laravel's transactional `ShipmentHandoffService::accept()` implementation. The authenticated destination Logistics account supplies its provider identity; Laravel derives its single active Sorting Center and the shared service rechecks transfer ownership, shipment/parcel states, active account eligibility, and destination zone coverage inside its transaction. Client-supplied provider or center identifiers do not determine custody. Unknown and foreign waybills share the same not-found response, while duplicate acceptance follows the service's conflict response.

The existing Mobile lookup now returns read-only handoff eligibility. The Flutter Logistics dashboard opens a separate **Incoming City Handoff** flow with the existing camera scanner and manual lookup. It displays source and destination providers, intended Sorting Center, shipment/parcel states, and server eligibility; it requires explicit confirmation, posts once, then reloads server state. An uncertain result disables acceptance until the operator performs a fresh lookup. L2 lookup remains read-only, and L3-A ordinary parcel receipt remains separate.

Automated isolated-database results: Laravel Mobile handoff and L2/L3-A lookup tests passed (18 tests, 269 assertions); the existing Web cross-city handoff integration regression passed (1 test, 217 assertions). Flutter Logistics tests passed (27 tests), including manual and camera acceptance, eligibility gating, explicit confirmation, duplicate-tap prevention, post-success refresh, and uncertain-response reconciliation. These test results do not represent a live handoff operation.

### Pending operator-controlled live test

No L3-B handoff-send or acceptance request has been made against staging. To test this parcel, first send it through the Victoria Logistics Web City Handoffs workflow. Then, while signed in as the destination Logistics operator for PB Sorting Center, open **Incoming City Handoff** in Flutter, scan or enter the waybill, verify the source/destination and SC-1 details and eligible state, and explicitly confirm once. After success, verify `shipment_transfers.status = accepted`, the shipment is `at_sorting_center` under the destination provider, the parcel is `received` at SC-1, and exactly one `logistics_handoff_accepted` event exists. If the response is uncertain, refresh the lookup before considering another submission. No Mobile sorting or dispatch actions are included in this phase.

## Phase L4 — Sorting and destination-zone assignment

### Shipment #12 read-only staging verification

On October 31, 2026, a read-only query explicitly connected to `bearly_latest_dev_import_20261028` verified the parcel's state after the operator-controlled L3-B handoff:

This current check supersedes the earlier pre-acceptance snapshot and pending-test note in the Phase L3-B section above.

- Shipment #12 (`SHP-Y1UO5AHT0PL4XMRVFPYV`) remains `at_sorting_center` under destination Logistics profile #1; its origin profile is #3.
- Parcel #12 (`PCL-6WLXGU2SQ0TDWEIA1MZH`) is `received` at active center SC-1, owned by provider profile #1, with no current sorting zone.
- Exactly one transfer is `accepted`, from profile #3 to profile #1, and exactly one `logistics_handoff_accepted` event is recorded. No `parcel_sorted` or `parcel_resorted` event exists.
- The order destination is Pinagbayanan, Pila, Laguna (`0403422000`). Active SC-1 zone `PILA-02` (zone #2) covers that barangay and municipality. The parcel is eligible to appear in the Mobile sorting queue, subject to the server's live eligibility response and operator confirmation.

This is a read-only database verification. It confirms recorded custody and destination coverage, not physical parcel presence. No sorting or zone assignment has been performed. Shipment #10 and delivered shipment #11 were not queried or changed for this phase.

### Implementation and automated validation

Mobile adds an authenticated sorting queue for received parcels at the authenticated Logistics provider's single active Sorting Center. The server derives provider and center identity, returns only active zones whose coverage matches the parcel destination, and revalidates status, custody, owner, zone activity, and coverage under the existing `ParcelSortingService` transaction. The Mobile adapter allows one `received` to `sorted` transition and rejects duplicate/terminal sorting; Web's established `parcel_resorted` behavior remains unchanged. Successful responses include server-confirmed parcel, zone, and shipment state. Sorting does not create COD or other financial entries.

The Flutter dashboard now links to **Sorting Queue**. Operators can review a parcel, select a server-provided matching zone, confirm sorting explicitly, and refresh state. Timeouts, transport failures, malformed responses, and server errors block another submission until a fresh queue read succeeds. No Mobile dispatching, Rider assignment, City Handoff sending, return, COD, or live-map action is included.

Automated isolated-database validation for L4: Laravel Mobile sorting, existing Web sorting/intake, cross-city workflow, and Mobile handoff acceptance tests passed (48 tests, 1,216 assertions). Flutter sorting-queue tests passed (5 tests) for dashboard navigation, matching-zone selection, confirmation, post-success refresh, uncertain-response reconciliation, and read-error retry. These automated results do not represent a live sort.

### Pending operator-controlled Samsung test

No sort request has been submitted against staging. For the expected smoke test, sign in to the Pila Logistics Mobile account, open **Sorting Queue**, refresh, open waybill `BRLY-ULD904RGCHZK1SIDLUND`, and verify the server still shows shipment #12 at SC-1, parcel #12 as `received`, and `PILA-02` as a selectable active matching zone. After confirming the parcel's physical presence and the destination, select `PILA-02` and tap **Mark parcel sorted**. Review the confirmation dialog and confirm once only. Then verify Flutter's server-confirmed `sorted` parcel/zone state and `/logistics/sorting` in Laravel Web. If a request times out or returns a server error, refresh the queue before any further action; do not replay automatically.
## Phase L5 — Delivery dispatch

### Reused Web workflow and Mobile contract

The existing Web entry point is `GET /logistics/dispatch` and `POST /logistics/dispatch/{zone}`. The POST delegates to `DispatchService::dispatchZone()`, which locks and revalidates the provider-owned zone, Rider eligibility and zone assignment, available capacity, and every ready parcel in that zone. It creates one dispatch batch for the entire coverage-matched ready zone set, updates parcel/shipment states as appropriate, writes the existing tracking events, and notifies the assigned Rider after commit. Mobile delegates to this same service; it does not implement another dispatch engine.

The authenticated Mobile API adds `GET /api/mobile/logistics/dispatch-board` and `POST /api/mobile/logistics/dispatch/zones/{zone}/dispatch`. Provider and active Sorting Center come from the authenticated Logistics account. The board shares its read model with the Web dispatch page and shows zone parcel membership, waybills, eligible Riders, and remaining capacity. The POST accepts only `rider_profile_id` in its body; the server scopes the zone to the account's active center and transactionally recomputes the complete parcel set and capacity. The response contains the created batch, server-confirmed parcel states, and a refreshed board. Dispatch itself does not create delivery attempts, COD collections, delivery completions, or payouts.

Flutter adds **Delivery Dispatch** to the Logistics dashboard. The operator reviews all waybills in a zone, selects a server-eligible Rider, and confirms explicitly. A timeout, transport error, malformed response, or server error blocks another submission until a fresh board read reconciles state; the POST is never automatically replayed.

### Isolated validation results

Laravel's new Mobile dispatch API suite and the existing Web dispatch and Mobile sorting regression suites passed: 40 tests, 254 assertions. Coverage includes provider isolation, whole-zone multi-parcel batches, active-load capacity, stale board data, duplicate dispatch rejection, status/event transitions, no COD or delivery-attempt side effects, and visibility in the assigned Rider's existing delivery API. Flutter's new dispatch widget tests passed (6); the complete Logistics widget suite passed (38). Targeted Logistics analysis reported no issues, and the Android debug APK built successfully. All dispatch mutations in these automated tests used Laravel's isolated test database. No staging dispatch was performed.

### Candidate and controlled Samsung procedure

The Phase L5 brief names Shipment #12 (`SHP-Y1UO5AHT0PL4XMRVFPYV`), waybill `BRLY-ULD904RGCHZK1SIDLUND`, Pila Sorting Center SC-1, and zone `PILA-02` as a possible candidate, with Mark Carlo A. Andasan as a potential Rider. These are earlier operator-observed references, not a current eligibility check or authorization to dispatch. No staging records were changed during L5 implementation. Before a live test, refresh the Mobile board and verify the provider, active center, zone, every listed waybill, the candidate Rider's current eligibility/capacity, and the parcel's physical presence. The Web workflow dispatches every eligible parcel in the zone, so review the full set before confirmation.

For a later operator-controlled test on the Samsung device:

1. Confirm the local SafeTest server and current staging database are the intended ones; keep Cloudflare stopped and do not use an unverified server.
2. Sign in to the Logistics account that owns the displayed active Sorting Center, then open **Delivery Dispatch** from the dashboard.
3. Refresh the board. Confirm each parcel in the target zone is physically present and ready, then review the full waybill list and the selected Rider's remaining capacity.
4. Select an eligible Rider and tap **Review dispatch**. Check that the zone, all parcels, and Rider are correct in the confirmation dialog. Cancel if anything differs.
5. Only after explicit operator approval, confirm once. Wait for the batch reference and server-confirmed `dispatched` parcel state. If the response is uncertain, refresh the board and inspect state before any retry.
6. Verify the generated batch and parcel states in Laravel Web `/logistics/dispatch` and `/logistics/monitoring`, then confirm the batch is visible in that Rider's Flutter **Assigned Deliveries**. Do not start delivery as part of this dispatch test.

## Phase L6 — Delivery monitoring

### Automated validation

The L6 provider-scoped monitoring API and existing Web monitoring regressions passed their focused Laravel tests (3 Mobile API tests, 32 assertions; 2 Web regression tests, 12 assertions). The Flutter Logistics widget suite passed (50 tests); targeted analysis reported no issues, and the Android debug APK built successfully. These are automated results and do not establish a physical-device or fresh database result.

### Physical Samsung smoke test — operator-reported PASS

On October 31, 2026, the operator reported successfully opening Logistics Mobile → **Delivery Monitoring** on a Samsung device and inspecting the following existing batches. This record is based on the operator-reported screenshots and observations. It is separate from the automated results above and earlier read-only database checks; no fresh database inspection was performed for this smoke test record.

| Dispatch batch | Displayed stage | Progress | Result |
| --- | --- | ---: | --- |
| `DSP-20261031-ZS0TJXHV` | Assigned to Rider | 0% | PASS |
| `DSP-20261030-RSWYTYDH` | Out for Delivery | 0% | PASS |
| `DSP-20261030-E6PPNVA2` | Delivered | 100% | PASS |

The Logistics account was scoped to PB Sorting Center, Sorting Center SC-1. All three batches displayed Rider Mark Carlo A. Andasan and delivery zone PILA-02 — Pila / Pinagbayanan. The Assigned batch showed its parcel and shipment as `Dispatched`, with assignment and release events in the timeline. The Out for Delivery batch showed its parcel and shipment as `Out For Delivery`; its timeline included the previously recorded failed delivery attempt and staging-test reason. The Delivered batch showed its parcel and shipment as `Delivered`, 100% completion, and the delivery event in its timeline. The displayed stages and progress were consistent with earlier Laravel Web Delivery Monitoring observations. Manual refresh and list-to-detail navigation worked. No delivery mutation was performed as part of this monitoring verification.

Low-priority display note: the Delivered timeline currently uses the generic description “Latest recorded parcel status.”

## Phase L7 — Integration review, UI cleanup, and regression testing

### Audit scope and evidence

Reviewed Flutter role login and session lifecycle, role-based routes, Buyer and Rider regression paths, Logistics navigation, mutation feedback/reconciliation, and the L1–L6 Mobile API contracts in Laravel. This section separates code inspection and automated tests from the operator-reported L1–L6 device checks above. No Laravel runtime or staging database was queried, and no staging mutation was performed for L7.

### Findings

- **Confirmed bug — stale Logistics dashboard metrics:** the dashboard loaded its counts at entry and did not refresh after returning from Incoming Parcel Receipt, Incoming City Handoff, Sorting Queue, or Delivery Dispatch. Returning could leave operation counts stale until the operator manually refreshed. Fixed by refreshing the dashboard after those operation pages close.
- **Confirmed UI consistency issue — delivery status casing:** monitoring detail converted `out_for_delivery` to “Out For Delivery”, while the server-provided stage and Laravel Web use “Out for Delivery”. Added explicit display labels for known shipment/parcel states, retaining the generic formatter for unknown states.
- **Confirmed stale test fixture:** the root auth smoke test expected a previous static Rider screen and assumed a server role could override the selected role. It now selects Rider explicitly and mocks the current Rider dashboard response; this changes the test fixture only.
- **No issue found in inspected mutation safeguards:** receipt, handoff acceptance, sorting, and dispatch retain explicit confirmation, pending-request guards, server-confirmed success, and uncertain-response reconciliation. No automatic mutation retries were found in these paths.
- **No issue found in role/session handling by code inspection:** login submits the selected role; the returned active role is validated; saved sessions are verified with `/api/mobile/me`; explicit 401/403 responses clear local credentials; transient failures retain the session; logout clears local credentials even if the server cannot be reached. Logistics API routes use Sanctum, eligible-account and Logistics-role middleware, and derive provider/center scope from the authenticated account. This is code/test evidence, not a fresh live authentication test.
- **Incomplete features intentionally deferred:** Buyer Buy Now and seller Chat still show a later-phase placeholder; Rider messaging is not connected to the Mobile API. These were not implemented in L7.
- **Low-priority UI note:** the Delivered monitoring timeline still uses the generic “Latest recorded parcel status” detail. No backend timeline behavior was changed.

### Fixes and validation

The Logistics dashboard now reloads after returning from receipt, handoff, sorting, or dispatch. A regression test verifies the dashboard makes a fresh request and displays the refreshed count. Monitoring detail uses “Out for Delivery” consistently with Laravel’s displayed stage; the widget regression test checks both parcel and shipment labels.

Automated validation: the full Flutter suite passed (**291 tests**), including the Logistics suite (**51 tests**). Targeted analysis of all L7-modified Dart files reported no issues. The Android debug APK built successfully. A broader scoped analysis of `lib/core` and the auth, Buyer, Rider, and Logistics features reported six existing info-level lints in unrelated logo/auth/registration files; it found no issues in the modified files. No Laravel tests were run because Laravel source was not changed; relevant routes and shared services were inspected only.

These test results are automated evidence. No new Samsung device test was performed for L7.

### Remaining physical-device check

On Samsung, during a separately approved ordinary receipt, handoff acceptance, sort, or dispatch operation, confirm the dashboard counts refresh when returning from that workflow. Do not create or perform a staging operation solely for L7 validation. Open an existing monitoring batch detail and confirm an `out_for_delivery` parcel/shipment reads “Out for Delivery”; this status-label check is read-only. Previously recorded L1–L6 operator validations remain unchanged.

## U2-C2 integrated candidate Samsung smoke test — November 1, 2026

The operator reported **Logistics Mobile 5/5 PASS** while using the isolated candidate API at `http://127.0.0.1:8014` and rehearsal database `bearly_u2_rehearsal_20261101`. The reported checks covered authenticated navigation and existing read-only screens. No fresh database inspection or Logistics mutation is claimed here. The integrated Buyer, Rider, and Logistics results are recorded in [Rider Mobile validation](rider-phase-2a-validation.md).

This operator-reported smoke test predates the separate Rider navigation cleanup documented there; it does not constitute physical verification of that change.
