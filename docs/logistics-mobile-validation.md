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
