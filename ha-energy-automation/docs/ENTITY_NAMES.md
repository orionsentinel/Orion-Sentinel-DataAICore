# Entity Names Reference

## Discovery: Find Your Entities

Run this template in **Developer Tools → Template** to discover all relevant entities:

```jinja2
{# Energy system entity discovery — paste into Developer Tools → Template #}
{% set keywords = ['solaredge', 'p1_meter', 'homewizard', 'nord_pool', 'alfen', 'wallbox', 'tesla', 'forecast_solar', 'solcast', 'battery'] %}
{% for state in states | sort(attribute='entity_id') %}
  {% set found = namespace(v=false) %}
  {% for kw in keywords %}
    {% if kw in state.entity_id %}
      {% set found.v = true %}
    {% endif %}
  {% endfor %}
  {% if found.v %}
{{ state.entity_id }}: {{ state.state }} {{ state.attributes.unit_of_measurement | default('') }}
  {% endif %}
{% endfor %}
```

To find your notification services:
```jinja2
{% for s in states | sort(attribute='entity_id') %}
  {% if 'notify' in s.entity_id %}{{ s.entity_id }}
  {% endif %}
{% endfor %}
```

---

## SolarEdge Modbus Multi Entities

### Inverter (i1 = Inverter 1)

| Entity | Description | Unit | Used in |
|---|---|---|---|
| `sensor.solaredge_i1_ac_power` | AC output power | W | 03_solaredge |
| `sensor.solaredge_i1_dc_power` | DC input power (from panels) | W | 03_solaredge |
| `sensor.solaredge_i1_ac_energy_kwh` | Total AC energy | kWh | 03_solaredge (utility meter) |
| `sensor.solaredge_i1_status` | Inverter status | — | — |
| `sensor.solaredge_i1_temperature` | Inverter temperature | °C | — |
| `select.solaredge_i1_storage_control_mode` | Battery control mode | — | 04_battery_state_machine |
| `select.solaredge_i1_storage_default_mode` | Battery default mode | — | 04_battery_state_machine |

### Meter (m1 = Grid Meter)

| Entity | Description | Unit | Used in |
|---|---|---|---|
| `sensor.solaredge_m1_ac_power` | Grid power (+ import, − export) | W | 03_solaredge |
| `sensor.solaredge_m1_imported_kwh` | Total grid import | kWh | 03_solaredge (utility meter) |
| `sensor.solaredge_m1_exported_kwh` | Total grid export | kWh | 03_solaredge (utility meter) |

### Battery (b1 = Battery 1) — After Install Only

| Entity | Description | Unit | Used in |
|---|---|---|---|
| `sensor.solaredge_b1_state_of_energy` | Battery SOC | % | 03_solaredge |
| `sensor.solaredge_b1_dc_power` | Battery power (+ charge, − discharge) | W | 03_solaredge |
| `sensor.solaredge_b1_status` | Status code (1-7) | — | 03_solaredge |
| `sensor.solaredge_b1_energy_charged` | Total charged | kWh | 03_solaredge (utility meter) |
| `sensor.solaredge_b1_energy_discharged` | Total discharged | kWh | 03_solaredge (utility meter) |

**Battery status codes:** 1=Off, 2=Empty, 3=Discharging, 4=Charging, 5=Full, 6=Holding, 7=Testing

---

## HomeWizard P1 Meter Entities

Device name varies by what you named it in HA. Default assumes "P1 Meter":

| Entity | Description | Unit |
|---|---|---|
| `sensor.p1_meter_active_power_import_l1_w` | Phase L1 import | W |
| `sensor.p1_meter_active_power_import_l2_w` | Phase L2 import | W |
| `sensor.p1_meter_active_power_import_l3_w` | Phase L3 import | W |
| `sensor.p1_meter_active_power_export_l1_w` | Phase L1 export | W |
| `sensor.p1_meter_total_power_import_kwh` | Total import | kWh |
| `sensor.p1_meter_total_power_export_kwh` | Total export | kWh |
| `sensor.p1_meter_total_gas_m3` | Gas usage | m³ |
| `sensor.p1_meter_active_tariff` | Current tariff (T1/T2) | — |

> The SE10000H connects to phase L1. Total house consumption = L1 + L2 + L3 from P1 meter.

---

## Alfen Eve Wallbox Entities

| Entity | Description | Notes |
|---|---|---|
| `switch.alfen_wallbox_availability_manager` | Enable/disable charging | ✅ Safe for frequent writes |
| `sensor.alfen_wallbox_active_power_total` | Total charging power | W, primary EV signal |
| `sensor.alfen_wallbox_status` | IEC 61851 state | A=no car, B=connected, C=charging |
| `binary_sensor.alfen_wallbox_https_api_login_status` | API session active | Session watchdog |
| `sensor.alfen_wallbox_voltage_l1_n` | Phase L1 voltage | V |
| `sensor.alfen_wallbox_current_l1` | Phase L1 current | A |
| `number.alfen_wallbox_max_station_current` | Max charging current | ⚠️ FLASH WEAR — use carefully |
| `button.alfen_wallbox_login` | Re-login to API | Session recovery |
| `button.alfen_wallbox_logout` | Logout from API | Release session for app |

> Entity names may include the device's hostname. If your charger is named "Alfen Eve Pro", entities may be `sensor.alfen_eve_pro_status` etc. Run the discovery template above.

---

## Tesla Entities (Official Integration)

| Entity | Description | Reliable? |
|---|---|---|
| `sensor.tesla_battery_level` | State of Charge | ⚠️ Cloud, can be unavailable |
| `sensor.tesla_battery_range` | Estimated range | ⚠️ Cloud |
| `binary_sensor.tesla_charging` | Is charging | ⚠️ Use Alfen power instead |
| `binary_sensor.tesla_plugged_in` | Is plugged in | ⚠️ Use Alfen status instead |
| `switch.tesla_charger` | Enable/disable charging | ⚠️ Cloud control |
| `number.tesla_charging_amps` | Charging amperage | ⚠️ Cloud, don't use for control |
| `device_tracker.tesla` | Vehicle location | OK when available |

> Entity names include vehicle name. If your Tesla is named "Model Y", entities may be `sensor.model_y_battery_level`.

---

## Nord Pool Entities

| Integration | Current price entity | Today prices | Tomorrow prices |
|---|---|---|---|
| **Official HA Nord Pool** | `sensor.nord_pool_nl_current_price` | `today` attribute | `tomorrow` attribute |
| **HACS Nord Pool** (older) | `sensor.nordpool_kwh_nl_eur_3_10_025` | `raw_today` attribute | `raw_tomorrow` attribute |

This repo uses the **official HA Nord Pool** integration. If using HACS version, update:
- Entity names in `02_energy_prices.yaml`
- AIO `nordpool_entity` in `02_energy_prices.yaml`
- Template attribute names: `raw_today` instead of `today`

---

## Forecast.Solar Entities

| Entity | Description |
|---|---|
| `sensor.forecast_solar_energy_production_today` | Today's forecast (kWh) |
| `sensor.forecast_solar_energy_production_tomorrow` | Tomorrow's forecast (kWh) |
| `sensor.forecast_solar_energy_current_hour` | Current hour forecast (Wh) |

If using **Solcast** instead (more accurate, recommended):

| Entity | Replaces |
|---|---|
| `sensor.solcast_pv_forecast_today` | `forecast_solar_energy_production_today` |
| `sensor.solcast_pv_forecast_tomorrow` | `forecast_solar_energy_production_tomorrow` |
| `sensor.solcast_pv_power_now` | `forecast_solar_energy_current_hour` |

---

## Bulk Rename Commands

If your entities use different naming (e.g., different device suffix):

### Bash (Linux / macOS / Pi terminal)

```bash
# Preview: find all entity references in package files
grep -r "solaredge_i1\|solaredge_m1\|solaredge_b1" packages/

# Rename inverter entities (example: i1 → se10000h)
find packages/ -name "*.yaml" -exec sed -i \
  's/solaredge_i1_/solaredge_se10000h_/g' {} \;

# Rename Alfen entities (example: different device name)
find packages/ scripts/ -name "*.yaml" -exec sed -i \
  's/alfen_wallbox_/alfen_eve_pro_/g' {} \;
```

### PowerShell (Windows)

```powershell
# Preview: find all entity references
Get-ChildItem -Path packages,scripts -Filter *.yaml -Recurse |
  Select-String "solaredge_i1|solaredge_m1|alfen_wallbox"

# Bulk rename (example: alfen_wallbox → alfen_eve_pro)
Get-ChildItem -Path packages,scripts -Filter *.yaml -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace 'alfen_wallbox_', 'alfen_eve_pro_'
    Set-Content $_.FullName -Value $content
}
```

---

## Placeholder Entity Checklist

Find all placeholders that need to be replaced:

```bash
grep -r "← replace" packages/ scripts/ dashboards/
```

| Placeholder | Replace with |
|---|---|
| `switch.washing_machine_smart_plug` | Your washing machine smart plug switch |
| `switch.dishwasher_smart_plug` | Your dishwasher smart plug switch |
| `switch.dryer_smart_plug` | Your dryer smart plug switch |
| `solaredge_i1_ac_energy_kwh` | Your actual energy production entity |
| `solaredge_m1_imported_kwh` | Your actual grid import energy entity |
| `solaredge_m1_exported_kwh` | Your actual grid export energy entity |

Smart plug options: IKEA TRADFRI outlets, TP-Link Kasa, Shelly 1PM, Sonoff S26.
