# Battery State Machine

## Overview

The battery control system uses a **Single Writer Pattern** to prevent race conditions between multiple automations writing to the same Modbus entity.

### The Problem It Solves

Seven automations all writing directly to `select.solaredge_i1_storage_default_mode` creates **undefined behaviour** when multiple conditions are true simultaneously. For example:
- At 02:00, both "cheap hour → grid charge" and "solar producing → self consume" might fire
- Two automations might write different modes within milliseconds of each other
- The final state depends on timing, not logic

### The Solution

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Rule Automations (05_battery_automations.yaml)                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ RULE 1       │ │ RULE 2       │ │ RULE 3       │ │ RULE 4-7     │  │
│  │ Grid Charge  │ │ Self Consume │ │ Peak Discharge│ │ EV / Fallback│  │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘  │
│         │                │                │                │           │
│         └────────────────┴────────────────┴────────────────┘           │
│                                   │                                     │
│                                   ▼                                     │
│                   ┌─────────────────────────────────┐                  │
│                   │  input_select.battery_desired_mode│                  │
│                   │  (THE SINGLE STATE VARIABLE)     │                  │
│                   └─────────────────┬───────────────┘                  │
│                                     │                                   │
└─────────────────────────────────────┼───────────────────────────────────┘
                                      │
                    ┌─────────────────▼───────────────────┐
                    │  Mode Executor (04_battery_state_    │
                    │  machine.yaml — THE ONLY MODBUS      │
                    │  WRITER)                             │
                    │                                      │
                    │  IF modbus_available AND             │
                    │     battery_available:               │
                    │    1. Set storage_control → Remote   │
                    │    2. Wait 2s                        │
                    │    3. Set storage_default_mode       │
                    │  ELSE: log warning, do nothing       │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────▼───────────────────┐
                    │  Modbus Entities (SolarEdge)         │
                    │  select.solaredge_i1_storage_        │
                    │  control_mode                        │
                    │  select.solaredge_i1_storage_        │
                    │  default_mode                        │
                    └─────────────────────────────────────┘
```

---

## Mode Definitions

| Mode | SolarEdge Modbus Setting | When Used |
|---|---|---|
| `SELF_CONSUME` | Maximize Self Consumption | Normal operation — default |
| `GRID_CHARGE` | Charge from PV and AC | Cheap/negative price window |
| `PEAK_DISCHARGE` | Maximize Export | Expensive hour, sell stored energy |
| `HOLD` | Charge from PV | EV charging active, protect grid |
| `FORCE_CHARGE` | Charge from PV and AC | Manual override: force grid charge |
| `FORCE_DISCHARGE` | Maximize Export | Manual override: force export |

---

## Priority Order

When evaluating conditions, this is the effective priority (highest first):

```
FORCE_DISCHARGE   (manual script override)
FORCE_CHARGE      (manual script override)
GRID_CHARGE       (cheap/negative price, scheduled)
PEAK_DISCHARGE    (expensive hour, sell battery)
HOLD              (EV charging active)
SELF_CONSUME      (default, fallback)
```

In practice, rule automations check `not in ['FORCE_CHARGE', 'FORCE_DISCHARGE']` before overriding, which implements this priority in code.

---

## State Transition Diagram

```
                    HA Start
                        │
                        ▼
              ┌─────────────────┐
              │   SELF_CONSUME  │◄─────────────────────────────┐
              │   (default)     │                              │
              └────────┬────────┘                              │
                       │                                       │
          ┌────────────┴─────────────────────────┐            │
          │                                       │            │
          ▼                                       ▼            │
  Price < threshold               Price in top 25% today      │
  & allow_grid_charge=on           & battery > min_soc        │
  & battery < 95%                  & solar NOT producing       │
          │                                       │            │
          ▼                                       ▼            │
  ┌──────────────┐                        ┌──────────────┐    │
  │  GRID_CHARGE │                        │PEAK_DISCHARGE│    │
  └──────┬───────┘                        └──────┬───────┘    │
         │                                       │            │
         │ Price rises OR                        │ Price drops │
         │ solar producing                       │ OR min_soc  │
         │ OR battery full                       │ reached    │
         └───────────────────────────────────────┴────────────┘
                                                              │
          Alfen > 500W for 2min                               │
                    │                                         │
                    ▼                                         │
             ┌────────────┐                                   │
             │    HOLD    │                                   │
             └─────┬──────┘                                   │
                   │ Alfen < 100W for 5min                    │
                   └──────────────────────────────────────────┘

  Manual scripts override to FORCE_CHARGE / FORCE_DISCHARGE
  and auto-reset after configured duration.
```

---

## Audit Log: `input_text.battery_last_action`

Every mode change is logged to `input_text.battery_last_action` with timestamp, new mode, and reason. This is visible on the dashboard. Examples:

```
14:02 → GRID_CHARGE: GRID_CHARGE — Negatieve prijs -0.0123 €/kWh, SoC 34%, solar offline
08:35 → SELF_CONSUME: SELF_CONSUME — Zonne-energie: 2.45 kW
17:15 → PEAK_DISCHARGE: PEAK_DISCHARGE — Piekprijs 0.3821 €/kWh, SoC 87%
19:30 → HOLD: HOLD — EV aan het laden (6800 W), batterij vastgehouden
20:15 → SELF_CONSUME: SELF_CONSUME — Normaal bedrijf, prijs 0.2341 €/kWh
```

When Modbus is unavailable, the executor logs:
```
14:02 ⚠️ Modbus/batterij niet beschikbaar — GRID_CHARGE NIET uitgevoerd
```

---

## Manual Override: Force Scripts

To manually control the battery, use the scripts in `scripts/battery_mode_override.yaml`:

### Via Developer Tools (HA UI)

1. Go to **Developer Tools → Services**
2. Search for `script.force_battery_charge_from_grid`
3. Set `duration_minutes` (optional, default 60)
4. Click **Call Service**

### Via Dashboard

The energy dashboard includes buttons for:
- Reset to self-consumption
- Force charge (1h)
- Force discharge (2h)

### Available Scripts

| Script | Effect | Auto-reset? |
|---|---|---|
| `script.reset_battery_to_self_consumption` | SELF_CONSUME | No |
| `script.force_battery_charge_from_grid` | FORCE_CHARGE | Yes, after duration |
| `script.force_battery_discharge` | FORCE_DISCHARGE | Yes, after duration |
| `script.hold_battery` | HOLD | No |

---

## Debugging Battery Mode Issues

### "Mode keeps reverting to SELF_CONSUME"

Check: Is the hourly fallback rule (`battery_rule_hourly_fallback`) firing? It resets to SELF_CONSUME at :05 every hour if not in a scheduled window. This is correct behaviour.

If you set FORCE modes via the input_select directly but they reset, check that the rule automations have the `not in ['FORCE_CHARGE', 'FORCE_DISCHARGE']` condition.

### "Battery not charging during cheap hours"

Check:
1. `input_boolean.allow_grid_battery_charge` — is it `on`?
2. `sensor.price_freshness_ok` — is it `true`?
3. `binary_sensor.battery_available` — is it `on` (battery installed)?
4. `sensor.battery_soc_pct` — is it below 95%?
5. `sensor.nord_pool_nl_current_price` — is it below `input_number.battery_charge_price_threshold`?
6. Check `input_text.battery_last_action` for recent log entries

### "Mode Executor not writing to Modbus"

Check:
1. `binary_sensor.modbus_available` — must be `on`
2. `binary_sensor.battery_available` — must be `on`
3. `select.solaredge_i1_storage_control_mode` — must be available
4. Check `input_text.battery_last_action` — does it show the ⚠️ unavailable message?

### Checking via Developer Tools

1. Go to **Developer Tools → States**
2. Filter by `battery` to see all battery-related entities
3. Check `input_select.battery_desired_mode` — what mode is set?
4. Check `select.solaredge_i1_storage_default_mode` — does it match?
5. If they differ, the Mode Executor may have failed — check `battery_last_action`
