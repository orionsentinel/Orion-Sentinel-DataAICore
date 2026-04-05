# Architecture: ha-energy-automation v3

## Overview

This system uses a **4-Layer Architecture** to separate raw hardware data from computed signals, decision logic, and actuators. This prevents tight coupling between hardware entities and automation logic.

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 4 — ACTUATORS                                            │
│  Hardware commands: Modbus writes, Alfen switch                 │
│  Files: 05_battery_state_machine.yaml (executor only)           │
│         07_alfen_ev_charging.yaml (switch only)                 │
└────────────────────────┬────────────────────────────────────────┘
                         │ reads from input_select / conditions
┌────────────────────────┴────────────────────────────────────────┐
│  LAYER 3 — DECISION ENGINE                                       │
│  Rules: when to charge, discharge, hold, schedule EV            │
│  Files: 05_battery_state_machine.yaml (executor trigger)        │
│         06_battery_automations.yaml                             │
│         07_alfen_ev_charging.yaml                               │
│         08_appliances.yaml                                      │
│         09_solar_forecast.yaml                                  │
│                                                                  │
│  State bus: input_select.battery_desired_mode                   │
│  (Single Writer Pattern — only one executor reads this)          │
└────────────────────────┬────────────────────────────────────────┘
                         │ reads from Layer 2 sensors
┌────────────────────────┴────────────────────────────────────────┐
│  LAYER 2 — DERIVED SIGNALS                                       │
│  Computed sensors: arbitrage_opportunity, battery_target_soc,   │
│  price_spread_today, system_health_status, alfen_change_allowed  │
│  File: 03_derived_signals.yaml                                  │
└────────────────────────┬────────────────────────────────────────┘
                         │ reads from raw integration entities
┌────────────────────────┴────────────────────────────────────────┐
│  LAYER 1 — RAW INGESTION                                         │
│  Pass-through sensors, availability guards, utility meters      │
│  File: 04_solaredge.yaml                                        │
│  Sources: SolarEdge Modbus Multi, HomeWizard P1, Alfen HACS,    │
│           Nord Pool integration, Forecast.Solar, Tesla          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Single Writer Pattern

All battery control uses the **Single Writer Pattern** to eliminate race conditions:

```
Rule automations → input_select.battery_desired_mode → [executor] → Modbus
     (many)               (one state bus)               (one writer)    (one target)
```

**Why this matters:** Without a single writer, two automations firing within milliseconds of each other could send conflicting Modbus writes. The SolarEdge inverter may execute them in an unexpected order, leaving the battery in a wrong state.

The executor (`05_battery_state_machine.yaml`) is the **only** automation that calls `select.select_option` on Modbus entities. All other automations only write to `input_select.battery_desired_mode`.

---

## Rate Limiting

Two actuators have rate limits to prevent hardware damage:

| Actuator | Rate limit | Tracker | Reason |
|---|---|---|---|
| Battery Modbus | 5 min | `input_datetime.battery_last_mode_change` | Excessive Modbus writes can confuse inverter |
| Alfen enable/disable | 10 min | `input_datetime.alfen_last_change` | EEPROM flash wear on register 2129_0 |

FORCE modes (FORCE_CHARGE, FORCE_DISCHARGE) bypass the battery rate limit for manual responsiveness.

Both trackers are reset to `1970-01-01` on HA startup so the first write after restart is never blocked.

---

## Kill Switch

`input_boolean.energy_automation_enabled` is checked by every automation in packages 05–09 before acting.

When turned off:
- Watchdog immediately puts battery in SELF_CONSUME
- Watchdog disables Alfen (stops automated charging)
- All package automations skip their actions
- Manual scripts still work (intentional — allows manual override during maintenance)

---

## Arbitrage Guard

Battery cycling (GRID_CHARGE + PEAK_DISCHARGE) only activates when it's financially worthwhile:

```
binary_sensor.arbitrage_opportunity = (sensor.price_spread_today >= input_number.arbitrage_min_spread)
```

Default minimum spread: **0.10 €/kWh**. Rationale: battery degradation costs ~0.05–0.08 €/kWh per cycle. A spread of 0.10 €/kWh ensures at least 2–5 ct/kWh profit after degradation.

**Exception:** Negative prices always trigger GRID_CHARGE regardless of spread.

---

## Dynamic Battery Target SOC

`sensor.battery_target_soc` adjusts the charging target based on conditions:

| Condition | Target | Reason |
|---|---|---|
| Negative price | 95% | Charge maximally — free/paid to consume |
| Cloudy forecast + high spread | 80% | No solar coming, arbitrage worthwhile |
| Sunny forecast | 30% | Solar will fill battery — no need for grid charge |
| Default | 50% | Balanced: cover night consumption without over-charging |

The GRID_CHARGE rule stops charging when `battery_target_soc` is reached (not a fixed 95%).

---

## Entity Dependency Map

```
sensor.nord_pool_nl_current_price (Nord Pool integration)
  └── sensor.price_freshness_ok
  └── sensor.energy_price_all_in
  └── sensor.today_price_min/max/avg
  └── sensor.price_spread_today
        └── binary_sensor.arbitrage_opportunity
              └── 06_battery_automations: GRID_CHARGE guard
              └── 06_battery_automations: PEAK_DISCHARGE guard
  └── binary_sensor.is_cheap_hour
  └── binary_sensor.is_expensive_hour
  └── binary_sensor.is_negative_price

sensor.solaredge_i1_ac_power (SolarEdge Modbus Multi)
  └── binary_sensor.modbus_available
  └── binary_sensor.solar_producing

sensor.solaredge_b1_state_of_energy (SolarEdge Modbus Multi)
  └── binary_sensor.battery_low
  └── sensor.battery_energy_available_kwh
  └── sensor.battery_target_soc
  └── binary_sensor.battery_hardware_available

sensor.homewizard_p1_active_power_w (HomeWizard P1)
  └── binary_sensor.p1_available
  └── binary_sensor.exporting_to_grid

sensor.solar_forecast_tomorrow_kwh (Forecast.Solar)
  └── sensor.solar_forecast_category
  └── binary_sensor.battery_will_fill_naturally
  └── sensor.battery_target_soc

input_boolean.energy_automation_enabled
  └── ALL automations in 05-09 (kill switch)
  └── Watchdog: safe-state on disable

input_select.battery_desired_mode (state bus)
  └── 05_battery_state_machine.yaml executor (ONLY Modbus writer)

input_datetime.battery_last_mode_change
  └── binary_sensor.battery_change_allowed
        └── 05_battery_state_machine.yaml executor (rate limit)

input_datetime.alfen_last_change
  └── binary_sensor.alfen_change_allowed
        └── 07_alfen_ev_charging.yaml automations (rate limit)
```

---

## Data Flow: Battery Charge Decision

```
13:30 → forecast_gate automation runs
  └── Forecast.Solar > 20 kWh? → disable allow_grid_battery_charge
  └── Forecast.Solar < 20 kWh? → enable allow_grid_battery_charge

Nord Pool price update → is_cheap_hour or is_negative_price turns on
  └── battery_grid_charge_cheap_price checks:
        1. energy_automation_enabled = on
        2. modbus_available = on
        3. price_freshness_ok = true
        4. allow_grid_battery_charge = on
        5. battery SOC < battery_target_soc
        6. (spot <= threshold OR is_negative) AND (arbitrage_opportunity OR is_negative)
  └── All pass → write GRID_CHARGE to input_select

input_select → battery_mode_executor triggers
  └── modbus_available AND battery_hardware_available?
  └── FORCE mode? → bypass rate limit
  └── rate limit OK? → write to Modbus
  └── Rate limited → log, skip write
```

---

## File Structure

| File | Layer | Responsibility |
|---|---|---|
| `packages/00_secrets_template.yaml` | — | Template for credentials |
| `packages/01_system_watchdogs.yaml` | 0 | Watchdogs, shared helpers, startup resets |
| `packages/02_energy_prices.yaml` | 2 | Price sensors, kill switch, AIO config |
| `packages/03_derived_signals.yaml` | 2 | All computed/derived sensors |
| `packages/04_solaredge.yaml` | 1 | Raw pass-through + availability + utility meters |
| `packages/05_battery_state_machine.yaml` | 3+4 | State machine + sole Modbus writer |
| `packages/06_battery_automations.yaml` | 3 | Battery rules → input_select only |
| `packages/07_alfen_ev_charging.yaml` | 3+4 | EV charging logic + Alfen switch control |
| `packages/08_appliances.yaml` | 3 | Appliance scheduling |
| `packages/09_solar_forecast.yaml` | 2+3 | Forecast sensors + grid charge gate |
| `scripts/battery_mode_override.yaml` | 4 | Manual battery scripts |
| `scripts/alfen_session_manager.yaml` | 4 | Alfen session management |
| `dashboards/energy_dashboard.yaml` | — | Lovelace dashboard |

---

## jonasbkarlsson/ev_smart_charging Integration

The `ev_smart_charging` HACS integration is the **primary** EV scheduler. It is configured entirely via UI (no YAML needed). This package provides:

1. **Tesla SOC sync** (`ev_sync_tesla_soc`) → `input_number.ev_soc_manual` — used as SOC input for jonasbkarlsson when Tesla cloud API is unavailable
2. **Safety rate limiting** — all Alfen enable/disable operations check `alfen_change_allowed` (10-min minimum)
3. **Solar excess absorption** — independent of jonasbkarlsson; enables charging when exporting >1kW for >5 minutes
4. **Emergency charge** — activates if SOC < minimum regardless of jonasbkarlsson schedule

Configure jonasbkarlsson to use `input_number.ev_soc_manual` as the SOC sensor and `input_datetime.ev_departure_time` as the departure time.
