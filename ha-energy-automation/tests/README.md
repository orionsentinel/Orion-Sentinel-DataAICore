# Test Guide

These are **manual test procedures** for verifying the energy automation package.
Home Assistant does not have built-in unit testing for automations, so these are
step-by-step scripts to run in the HA Developer Tools.

## Prerequisites

Before running any tests:
1. All packages are loaded without YAML errors (**Settings → System → Logs**)
2. `sensor.price_freshness_ok` = `true`
3. `binary_sensor.modbus_available` = `on`
4. `binary_sensor.alfen_wallbox_https_api_login_status` = `on`

## How to Run Service Calls

**Developer Tools → Services** (or `Settings → Developer Tools → Services`)

## How to Check Entity States

**Developer Tools → States** — filter by entity name.

## How to Trigger Automations Manually

**Developer Tools → Automations → [automation name] → Run** (triangle button).
Note: manually triggered automations skip conditions.

## Test Files

- `test_battery_state_machine.md` — Battery mode transitions and state machine
- `test_ev_charging.md` — EV charging automation scenarios
- `test_price_automations.md` — Price-triggered automation tests

## Expected Log Location

After each test, check `input_text.battery_last_action` and `input_text.system_last_alert`
for log entries. Also check **Settings → System → Logbook** filtered by the automation name.
