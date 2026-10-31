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
