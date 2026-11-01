# Rider Phase 2A field validation

**Test date:** October 30, 2026<br>
**Environment:** Laravel `bearly-fresh` on `integration/sync-1-mobile-auth-api-20261025`; Flutter `bearly-mobile` on `feature/mobile-laravel-integration`; local test server `http://127.0.0.1:8011`; staging database `bearly_latest_dev_import_20261028`; test mail driver `array`; Samsung Android phone connected through Wireless ADB.

## Test reference

- Seller order: `SO-261030-YX8FZO23`
- Pickup request: `PU-ZJNV9WRSQ3I9PZISGSZO`
- Waybill: `BRLY-P37CPITUW58BFGPRYNU1`
- Seller: Dhenzel Gadgets
- Logistics provider: Bearly Logistics Victoria
- Rider: Rider P. Victoria (user 20, Rider profile 4)

## Verified flow

The operator reported that each step below completed successfully through the normal Web and Flutter workflows:

1. Buyer placed a COD order.
2. Seller confirmed and prepared the order.
3. Laravel generated the shipment, parcel, and printable waybill.
4. Seller acknowledged printing the waybill and marked the order ready.
5. Seller submitted the pickup request.
6. Logistics verified the request and assigned Rider profile 4.
7. Flutter Rider displayed the assigned Seller, parcel, and waybill.
8. Rider accepted the pickup through the Mobile API.
9. Rider manually entered the printed waybill and confirmed collection.
10. Flutter displayed `Picked Up` and the refreshed active pickup list was empty.
11. Logistics displayed the parcel as `Picked Up` and showed acceptance and collection events.
12. Seller displayed `Rider Collected`.

The pickup request may remain `scheduled` after collection; this is the observed workflow behavior and does not by itself mean collection failed. Exact shipment and Seller Order database status values were not independently verified for this record and are intentionally not stated here.

## Follow-up UI polish

These observations are separate from the successful Phase 2A workflow and do not change pickup eligibility or fulfillment behavior:

- Success messages can appear duplicated.
- Some separators render with a text-encoding artifact (`Ã‚Â·`).
- A displayed timestamp may be inconsistent and needs comparison with its source event before correction.
- Seller product thumbnails were broken during the reported test.

## Phase 2B physical camera validation

**Test date:** October 30, 2026<br>
**Device:** Physical Samsung Android device.

The operator reported that the Rider camera successfully decoded the printed Code 128 waybill on a new, legitimate Seller → Logistics Victoria → Rider Victoria pickup. The Rider submitted collection through the existing Mobile API. Flutter displayed the assignment and parcel as `Picked Up` and showed the server-confirmed collection result.

A read-only query explicitly targeted `bearly_latest_dev_import_20261028`. It verified that this was a separate record from the Phase 2A manual pickup:

- Phase 2B pickup request #10: `PU-LFIO22IUXPOA73P3UXXR`; assignment #9; shipment #11: `SHP-EGSUN0KUAYTKQEFIBFD6`; parcel #11; waybill `BRLY-0D2WODACCFYU3D08BG8C`.
- The pickup request and shipment reference Logistics profile #3 (user #19); assignment #9 references Rider profile #4 (user #20), whose profile references Logistics profile #3.
- At the time of the read-only query, the pickup request status was `scheduled`, assignment status was `picked_up`, and both shipment and parcel statuses were `picked_up`.
- The earlier Phase 2A record was assignment #8 / pickup request #9 / shipment #10. The Phase 2B test used the distinct assignment, pickup request, shipment, parcel, and waybill above; the earlier completed job was not reused for the camera test.

The camera decode and Flutter display are operator-reported physical-test results. The database check verifies only the record relationships and statuses listed above; it does not claim that either shipment has advanced through sorting or delivery.

## Phase 3A physical delivery-start validation

**Test date:** October 30, 2026<br>
**Rider:** Mark Carlo A. Andasan (user #18)<br>
**Logistics provider:** PB Sorting Center<br>
**Dispatch batch:** `DSP-20261030-E6PPNVA2`<br>
**Shipment:** #11<br>
**Waybill:** `BRLY-0D2WODACCFYU3D08BG8C`<br>
**Zone:** `PILA-02`

The operator reported that the Rider Mobile started the assigned delivery through the Mobile API. Flutter displayed `Out for Delivery`, and Logistics Web displayed the same stage. The available test evidence records the shipment as still active and **not delivered**. No delivery completion or COD collection is claimed by this validation record.

## Phase 3B physical delivery completion and post-delivery verification

**Test date:** October 30, 2026<br>
**Rider:** Mark Carlo A. Andasan (user #18, Rider profile #3)<br>
**Dispatch batch:** `DSP-20261030-E6PPNVA2`<br>
**Shipment:** `SHP-EGSUN0KUAYTKQEFIBFD6` (shipment #11)<br>
**Waybill:** `BRLY-0D2WODACCFYU3D08BG8C`

### Operator-reported UI results

The operator reported that Flutter confirmed the delivery and showed `Delivered`; Logistics Web independently showed `Delivered` with 100% completion. Assigned Deliveries displayed no active jobs, and Delivery History contained six records including this shipment. The Rider Dashboard still displayed one assigned delivery, and the new history row displayed `No ledger entry`. These are reported UI observations; they are distinguished below from database verification.

### Read-only database verification

A read-only query explicitly connected to `bearly_latest_dev_import_20261028` verified:

- Shipment #11 and parcel #11 are `delivered`; the parcel retains the listed waybill.
- The shipment is linked to dispatch batch `DSP-20261030-E6PPNVA2`, Rider profile #3 / user #18. The batch row remains `dispatched` in the database.
- Exactly one delivery attempt exists for the shipment: attempt #9, outcome `delivered`.
- Exactly one photo proof record exists for that attempt. Its recipient and capture metadata are present, and its file resolves inside Laravel's private `storage/app/private` disk. No proof path or recipient details are included here.
- Exactly one COD collection exists: ₱555.00 due, ₱555.00 collected, and zero discrepancy. Its single cash-collection event records cash collected from the Buyer by the Rider.
- The COD collection remains `collected`: amounts received by Logistics, remitted to Finance, and reconciled are unset, with no corresponding custody/remittance/reconciliation timestamps. No COD duplicate collection or event was found.
- The COD payment record and order payment status are `paid`, matching the collected amount. The shipment tracking events end with parcel and shipment delivery.
- Seller Order #14 remains `handed_to_logistics`, while the parent order remains `processing` with payment paid. This is the documented workflow: the Seller Order becomes `completed` only after Buyer receipt confirmation. Seller tracking derives `Delivered · Awaiting Buyer confirmation` from the delivered shipment, so these order-level states do not mean the Rider delivery failed.

### Dashboard count audit and earnings ledger

Laravel's fresh Rider dashboard metric and Assigned Deliveries endpoint both call the same active-delivery filter. Rider profile #3 has six dispatch records, all with delivered parcels, so a fresh dashboard/list response should report zero active delivery assignments. The stale count came from Flutter retaining the dashboard Future loaded when the page was first opened; navigation did not refresh it on return. The previous refresh callback also passed a Future-returning assignment expression to `setState`, which Flutter rejects. Flutter now refreshes after a pushed screen is popped and performs the state update synchronously. The new widget regression test verifies a count changing from one to zero; all 28 Rider tests passed, and scoped analysis reported no issues.

`No ledger entry` refers to the Rider earnings ledger displayed alongside delivery history, not the separate COD cash-collection record. Delivery attempts do not create Rider earnings by themselves. Shipping settlement materialization requires the Seller Order to be `completed` and to pass the settlement, payment, and COD checks. This order still awaits Buyer receipt confirmation, and the read-only check found no shipping settlement or Rider earning for shipment #11. The absence is therefore expected at this stage; no earning was created as part of this audit.

## Phase 3D live failed-delivery and retry validation

**Test date:** October 31, 2026 (operator-reported)<br>
**Shipment:** #10, `SHP-MG5M2VGNS9MEISXZWLL0`<br>
**Waybill:** `BRLY-P37CPITUW58BFGPRYNU1`<br>
**Dispatch batch:** `DSP-20261030-RSWYTYDH`<br>
**Rider:** Mark Carlo A. Andasan (user #18, Rider profile #3)

### Operator-reported UI results

On the Samsung phone, Flutter reported the controlled staging delivery failure and showed the server-confirmed `Delivery Failed` state. Logistics Monitoring independently displayed `Delivery Failed` with one exception. The Rider tapped Retry Delivery once. Flutter then confirmed `Out for Delivery`; Logistics Monitoring showed `Out For Delivery`, one active route, and zero exceptions. These are operator-reported UI observations.

### Read-only database verification

A read-only PDO transaction explicitly connected to `bearly_latest_dev_import_20261028` and verified:

- Shipment #10 is an outbound shipment with status `out_for_delivery`. Parcel #10 is also `out_for_delivery` and remains linked to waybill `BRLY-P37CPITUW58BFGPRYNU1`.
- Exactly one delivery attempt exists: attempt #10, attempt number 1, outcome `failed`, associated with dispatch batch #9 and Rider profile #3. Retry did not create another attempt.
- The single stored failure reason is exactly: `STAGING TEST ONLY: simulated unsuccessful delivery for testing. no handover or COD cash collected.`
- Exactly one parcel failure event (`out_for_delivery` -> `failed`) and one shipment failure event (`out_for_delivery` -> `delivery_failed`) exist. Exactly one parcel retry event (`failed` -> `out_for_delivery`) and one shipment retry event (`delivery_failed` -> `out_for_delivery`) exist. All four events identify Rider user #18 as actor and `rider` as source. No duplicate failure or retry transition was found.
- Dispatch batch #9 remains `dispatched`, assigned to Rider profile #3. That profile belongs to user #18, is approved, and is associated with Logistics profile #1.
- The shipment records COD due of 55,500 minor units (PHP 555.00), but has no COD collection, no COD collection event, and no `cod_collected_at` timestamp.
- Shipment #10 has no return shipment. Its Seller Order has no associated return request or refund, and no return-linked cash payout was found.
- The latest shipment/parcel tracking events record the retry transition to `out_for_delivery`, matching the current shipment and parcel states. The operator-reported Web and Flutter states agree with these database values.

Event timestamps as stored in MySQL were 2026-10-30 16:37:12 for the failure and 2026-10-30 16:39:04 for the retry; their timezone interpretation was not independently verified.

### Result

**PASS** for the controlled failure and single retry state transitions. Shipment #10 remains active and out for delivery; this test did not complete delivery, collect COD, create a return, or issue a refund. This section records the reported UI results separately from the database findings above.

## U2-C2 integrated candidate Samsung smoke test — November 1, 2026

The operator reported these results while signed in to the isolated integrated Laravel candidate at `http://127.0.0.1:8014` using rehearsal database `bearly_u2_rehearsal_20261101`:

- Buyer Mobile: **5/5 PASS**
- Rider Mobile: **5/5 PASS**
- Logistics Mobile: **5/5 PASS**

The operator described the checks as authenticated navigation and existing read-only screens. This is an operator report, not a fresh database inspection, full operational regression, financial validation, or complete API contract verification. No shipment or financial mutation was part of this smoke test.

### Rider navigation consistency cleanup

The code audit found two separately maintained hamburger menus. The Dashboard menu duplicated its five bottom-navigation destinations, while the shared page menu also exposed legacy registration/pending links and context-free shortcuts (`Requests`, `Pick up order`, `Deliver order`, and `Complete delivery`). The latter routes were adapters to current lists rather than selected-assignment actions. The Dashboard additionally linked to the unimplemented Rider Messages placeholder.

The Rider screens now share the five primary destinations: Home, Pickups, Deliveries, Earnings, and Account. Their shared secondary menu contains Delivery History and Sign Out. The obsolete menu shortcuts and Dashboard Messages link were removed from normal navigation; route names and the general registration-to-application-review flow remain available. Tab changes return to the Dashboard root before opening a different tab, and Back returns to the Dashboard when a secondary screen is the root. Delivery History highlights Deliveries. The Dashboard zone separator is now rendered as ` · ` without changing API location values.

This cleanup has automated validation only; it was not part of the operator's earlier November 1 smoke test. The focused Rider suite passed **45 tests**, the full Flutter suite passed **310 tests**, targeted Rider analysis found no issues, and the Android debug APK built. No Laravel code or staging/rehearsal records were changed.

### Courier compatibility observation

The integrated candidate's Mobile Rider dashboard/account responses do not expose `work_type`, and Flutter has no Courier-specific mobile navigation or line-haul screen. As a result, an approved Courier account would still see the ordinary Pickup and Delivery tabs. The inspected Web dispatch path excludes Courier profiles, and the existing pickup and delivery services reject Courier profiles for local assignment mutations; no Courier mobile fulfillment implementation was found. This does not block the local Rider flows, but Courier users should not be enabled for these mobile workflows until the API exposes the work type and server-side Mobile route eligibility is explicitly reviewed. Hiding these tabs alone would not be an authorization control.

### Remaining Samsung verification

The operator should verify the navigation cleanup on Samsung: Dashboard ↔ Account, selected tabs for Pickups and Deliveries, the Delivery History menu/back path, Sign Out, and the corrected zone separator. These checks are pending and do not change the earlier operator-reported 5/5 results.

## U2-C2D Courier eligibility and communications readiness — November 1, 2026

### Earlier operator-reported Samsung checks

The November 1 operator report recorded authenticated Buyer, Rider, and Logistics navigation/read-only smoke checks on the isolated integration candidate as **5/5 PASS per role**. These are operator-reported results; no new screenshots or database inspection were produced during this follow-up. The checks do not establish Courier Mobile support or validate any write workflow.

### Courier Mobile eligibility safeguard

The candidate now includes the approved Rider profile's `work_type` and explicit local-pickup/local-delivery capabilities in its Mobile dashboard and account responses. Approved Couriers retain the existing Rider sign-in path and can view the informational dashboard/account. The Mobile API rejects local Rider history, pickup, and delivery routes for non-local work types with a stable `403` response; the ordinary Rider dashboard does not expose local assignment counts to Couriers. Flutter hides local pickup/delivery navigation and presents an explanation that Courier line-haul workflows remain in the approved Logistics Web process. Legacy profiles with a null work type retain the existing local compatibility behavior. This safeguard was verified by automated isolated tests; no physical Courier login or live workflow is claimed.

### Communications readiness audit

The Laravel Web candidate has authenticated Rider and Logistics inbox/thread routes, participant-scoped message access, read receipts, message sending, and protected attachment downloads. These use the existing `Conversation`, `Message`, `MessageReceipt`, and `MessageAttachment` records and `ConversationService`; Logistics conversation creation and Rider/Logistics thread operations remain Web workflows. The Mobile API currently exposes chat endpoints for Buyers only. It has no Rider or Logistics Mobile inbox, thread, read-receipt, send, or attachment API, and this task adds none.

The shared Web Notification Center reads each authenticated user's own database notifications, supports role-aware categories/preferences, and provides mark-read/read-all operations. Rider categories cover pickup assignments, delivery assignments, refund cash, and announcements; Logistics categories include pickup, handoff, cash, Rider, message, and announcement events. There are no corresponding Rider or Logistics Mobile notification endpoints in the candidate. Existing private broadcast channels authorize the user channel to its owner and conversation/presence channels to conversation participants; their existence does not mean a Reverb server or a Mobile WebSocket client is configured for this validation.

### Validation and next step

The Courier API contract test verifies an approved Courier can sign in, sees `work_type=courier` and disabled local capabilities, and is denied by all local Rider history/pickup/delivery routes. Flutter tests verify Courier parsing and that local navigation is hidden while the explanation is shown. The focused Rider suite passed **47 tests**, the full Flutter suite passed **312 tests**, targeted Rider analysis reported no issues, and the Android debug APK built. Laravel Rider/auth/Buyer/Logistics API tests passed under isolated in-memory SQLite; the test runner emitted missing-candidate-`.env` warnings, but reported no failures. No staging database, database migrations, operational workflows, or messaging/notification functionality were changed or tested live.

The next communications work should add role-scoped Sanctum APIs that reuse existing conversation/notification services, enforce exact participant and user ownership, retain the current attachment privacy rules, and add focused authorization/read-receipt tests before exposing Mobile navigation. Do not add clickable Mobile destinations until those screens are implemented. Courier line-haul Mobile support remains separate future work.