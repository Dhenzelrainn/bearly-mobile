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
