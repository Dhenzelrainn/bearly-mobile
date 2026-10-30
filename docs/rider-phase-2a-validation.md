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
