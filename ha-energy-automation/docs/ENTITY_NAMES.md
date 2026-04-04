# Entity Names Reference

This document provides entity name mappings for all integrations used in this package.

---

## SolarEdge Modbus Multi Entity Names

The SolarEdge Modbus Multi integration uses a naming convention based on device ID:
- `i1` = Inverter 1
- `m1` = Meter 1 (production meter, wired to inverter)
- `b1` = Battery 1 (after battery install)

### Inverter Entities (i1)

| Entity | Description | Unit |
|---|---|---|
| `sensor.solaredge_i1_ac_power` | AC output power | W |
| `sensor.solaredge_i1_dc_power` | DC input power (from panels) | W |
| `sensor.solaredge_i1_ac_energy_kwh` | Total AC energy produced | kWh |
| `sensor.solaredge_i1_status` | Inverter status (0-7) | — |
| `sensor.solaredge_i1_temperature` | Inverter temperature | °C |
| `sensor.solaredge_i1_ac_voltage_ab` | AC voltage L1-L2 | V |
| `sensor.solaredge_i1_ac_frequency` | Grid frequency | Hz |
| `select.solaredge_i1_storage_control_mode` | Battery control mode | — |
| `select.solaredge_i1_storage_default_mode` | Battery default mode | — |

### Meter Entities (m1)

| Entity | Description | Unit |
|---|---|---|
| `sensor.solaredge_m1_ac_power` | Grid exchange power (+ import, − export) | W |
| `sensor.solaredge_m1_imported_kwh` | Total energy imported from grid | kWh |
| `sensor.solaredge_m1_exported_kwh` | Total energy exported to grid | kWh |
| `sensor.solaredge_m1_ac_voltage_ln` | Grid voltage L-N | V |

### Battery Entities (b1) — Available After Battery Install

| Entity | Description | Unit |
|---|---|---|
| `sensor.solaredge_b1_state_of_energy` | Battery state of charge | % |
| `sensor.solaredge_b1_dc_power` | Battery power (+ charge, − discharge) | W |
| `sensor.solaredge_b1_status` | Battery status (1-7) | — |
| `sensor.solaredge_b1_energy_charged` | Total energy charged | kWh |
| `sensor.solaredge_b1_energy_discharged` | Total energy discharged | kWh |
| `sensor.solaredge_b1_temperature` | Battery temperature | °C |

### Battery Status Values

| Value | Meaning |
|---|---|
| 1 | Off |
| 2 | Empty |
| 3 | Discharging |
| 4 | Charging |
| 5 | Full |
| 6 | Holding |
| 7 | Testing |

---

## Find Your Entities — Jinja2 Template

Run this in **Developer Tools → Template** to discover all your SolarEdge and energy entities:

```jinja2
{# Discover all SolarEdge and energy-related entities #}
{% set keywords = ['solaredge', 'p1', 'nord_pool', 'ev_charger', 'easee', 'go_e', 'zaptec', 'alfen', 'forecast_solar', 'solcast'] %}
{% for state in states | sort(attribute='entity_id') %}
  {% for kw in keywords %}
    {% if kw in state.entity_id and state.entity_id not in discovered %}
      {{ state.entity_id }} — {{ state.state }} {{ state.attributes.unit_of_measurement | default('') }}
    {% endif %}
  {% endfor %}
{% endfor %}
```

To find your notification services:

```jinja2
{% for state in states.notify | sort(attribute='entity_id') %}
  {{ state.entity_id }}
{% endfor %}
```

---

## Bulk Rename (if your entity names differ)

If your SolarEdge entities use a different naming convention (e.g., device name in the entity ID), use these commands to find and replace:

### Bash (Linux/Mac)

```bash
# Find all package files and show matching entity references
grep -r "solaredge_i1\|solaredge_m1\|solaredge_b1" packages/

# Bulk rename device suffix (example: replace 'i1' with 'se10000h')
find packages/ -name "*.yaml" -exec sed -i 's/solaredge_i1_/solaredge_se10000h_/g' {} \;
find packages/ -name "*.yaml" -exec sed -i 's/solaredge_m1_/solaredge_se10000h_meter_/g' {} \;
```

### PowerShell (Windows)

```powershell
# Find all package files and show matching entity references
Get-ChildItem -Path packages -Filter *.yaml -Recurse | Select-String "solaredge_i1|solaredge_m1|solaredge_b1"

# Bulk rename device suffix (example: replace 'i1' with 'se10000h')
Get-ChildItem -Path packages -Filter *.yaml -Recurse | ForEach-Object {
    (Get-Content $_.FullName) -replace 'solaredge_i1_', 'solaredge_se10000h_' |
    Set-Content $_.FullName
}
```

---

## HomeWizard P1 Meter Entities

Entity names depend on your device name in HA. Default with device named "P1 meter":

| Entity | Description | Unit |
|---|---|---|
| `sensor.p1_meter_power_import_t1` | Active import T1 power | kW |
| `sensor.p1_meter_power_import_t2` | Active import T2 power | kW |
| `sensor.p1_meter_power_export_t1` | Active export T1 power | kW |
| `sensor.p1_meter_power_export_t2` | Active export T2 power | kW |
| `sensor.p1_meter_energy_import_tariff_1` | Total import T1 | kWh |
| `sensor.p1_meter_energy_import_tariff_2` | Total import T2 | kWh |
| `sensor.p1_meter_energy_export_tariff_1` | Total export T1 | kWh |
| `sensor.p1_meter_energy_export_tariff_2` | Total export T2 | kWh |
| `sensor.p1_meter_active_power_l1_w` | Phase L1 power | W |
| `sensor.p1_meter_active_power_l2_w` | Phase L2 power | W |
| `sensor.p1_meter_active_power_l3_w` | Phase L3 power | W |
| `sensor.p1_meter_active_voltage_l1_v` | Phase L1 voltage | V |
| `sensor.p1_meter_active_current_l1_a` | Phase L1 current | A |
| `sensor.p1_meter_gas` | Gas usage | m³ |

> **Three-phase note:** The SolarEdge SE10000H is a single-phase inverter connected to L1. Grid total = L1 + L2 + L3 from the P1 meter.

---

## EV Charger Entity Mappings

### Easee (official HA integration)

| Entity | Description |
|---|---|
| `switch.easee_[name]_smart_charging` | Enable smart charging |
| `sensor.easee_[name]_status` | Charger status |
| `sensor.easee_[name]_power` | Current charging power (kW) |
| `sensor.easee_[name]_session_energy` | Energy delivered this session |
| `binary_sensor.easee_[name]_cable_locked` | Cable connected |

Replace `switch.ev_charger` with `switch.easee_[name]_smart_charging` or create a template switch.

### go-E Charger (HACS)

| Entity | Description |
|---|---|
| `switch.go_echarger_[serial]_allow_charging` | Allow charging on/off |
| `sensor.go_echarger_[serial]_power_active_power` | Power (W) |
| `sensor.go_echarger_[serial]_car` | Car status (1=no car, 2=charging, 3=waiting, 4=charged) |
| `binary_sensor.go_echarger_[serial]_car_connected` | Car connected |

### Zaptec (official HA integration)

| Entity | Description |
|---|---|
| `switch.zaptec_[name]_charging_available` | Enable/disable charging |
| `sensor.zaptec_[name]_charge_state` | State (Unknown/Disconnected/Waiting/Charging/Finished) |
| `sensor.zaptec_[name]_total_charge_power` | Power (kW) |
| `binary_sensor.zaptec_[name]_is_connected` | Car connected |

### Alfen (HACS)

| Entity | Description |
|---|---|
| `switch.alfen_[name]_enable_charging` | Enable/disable charging |
| `sensor.alfen_[name]_power_active_import` | Power (W) |
| `sensor.alfen_[name]_status_connector_1` | Status code |

---

## Nord Pool Entity Name Variants

Entity names differ between the official integration and HACS version:

| Integration | Current price entity | Today's prices attribute | Tomorrow's prices attribute |
|---|---|---|---|
| **Official HA Nord Pool** | `sensor.nord_pool_nl_current_price` | `today` | `tomorrow` |
| **HACS Nord Pool** (older) | `sensor.nordpool_kwh_nl_eur_3_10_025` | `raw_today` | `raw_tomorrow` |

If you use the HACS version, update `energy_prices.yaml`:
```yaml
# Change:
nordpool_entity: sensor.nordpool_kwh_nl_eur_3_10_025

# And in templates, use:
state_attr('sensor.nordpool_kwh_nl_eur_3_10_025', 'raw_today')
```

> **Recommendation:** Use the official Nord Pool integration (available since HA 2024.1).

---

## Forecast.Solar vs Solcast Entity Names

### Forecast.Solar (official integration)

| Entity | Description |
|---|---|
| `sensor.forecast_solar_energy_production_today` | Forecast for today (kWh) |
| `sensor.forecast_solar_energy_production_tomorrow` | Forecast for tomorrow (kWh) |
| `sensor.forecast_solar_energy_current_hour` | Forecast for current hour (Wh) |

### Solcast (HACS)

| Entity | Description |
|---|---|
| `sensor.solcast_pv_forecast_today` | Forecast for today (kWh) |
| `sensor.solcast_pv_forecast_tomorrow` | Forecast for tomorrow (kWh) |
| `sensor.solcast_pv_power_now` | Current forecast power (W) |

If using Solcast, update `packages/solar_forecast.yaml`:
```yaml
# Replace:
sensor.forecast_solar_energy_production_tomorrow
sensor.forecast_solar_energy_production_today
# With:
sensor.solcast_pv_forecast_tomorrow
sensor.solcast_pv_forecast_today
```
