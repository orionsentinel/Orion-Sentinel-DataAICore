# Now vs Later — What to Enable

This document describes what you can configure and use **right now** (before battery install) versus what needs to wait until the **battery is installed and commissioned**.

---

## Enable Now (Pre-Battery)

| Feature | Package | Status |
|---|---|---|
| Nord Pool price sensors | `energy_prices.yaml` | ✅ Enable now |
| All-in price template sensor | `energy_prices.yaml` | ✅ Enable now |
| AIO Energy Management schedules | `energy_prices.yaml` | ✅ Enable now |
| Price helpers (input_number, input_boolean) | `energy_prices.yaml` | ✅ Enable now |
| Negative price alert automation | `energy_prices.yaml` | ✅ Enable now |
| SolarEdge inverter template sensors | `solaredge.yaml` | ✅ Enable now (inverter only) |
| Solar production/grid sensors | `solaredge.yaml` | ✅ Enable now |
| Utility meters (daily/monthly) | `solaredge.yaml` | ✅ Enable now |
| `binary_sensor.solar_producing` | `solaredge.yaml` | ✅ Enable now |
| `binary_sensor.exporting_to_grid` | `solaredge.yaml` | ✅ Enable now |
| HomeWizard P1 three-phase meter | `solaredge.yaml` | ✅ Enable now |
| EV smart charging | `ev_charging.yaml` | ✅ Enable now |
| Appliance scheduling | `appliances.yaml` | ✅ Enable now |
| Solar forecast sensors | `solar_forecast.yaml` | ✅ Enable now (Forecast.Solar) |
| Daily forecast → grid charge decision | `solar_forecast.yaml` | ⚠️ Enable, but `allow_grid_battery_charge` has no effect until battery is installed |
| Energy dashboard | `dashboards/energy_dashboard.yaml` | ✅ Enable now (battery cards will show unavailable) |

---

## Enable After Battery Install

| Feature | Package | Requires |
|---|---|---|
| Battery template sensors (`battery_soc_pct`, `battery_power_w`, etc.) | `solaredge.yaml` | `solaredge_b1_*` Modbus entities |
| `binary_sensor.battery_low` | `solaredge.yaml` | `solaredge_b1_state_of_energy` |
| `binary_sensor.battery_charging/discharging` | `solaredge.yaml` | `solaredge_b1_dc_power` |
| All battery_control.yaml automations | `battery_control.yaml` | Battery + Home Hub + storage controls enabled |
| `script.reset_battery_to_self_consumption` | `scripts/reset_battery_mode.yaml` | `select.solaredge_i1_storage_*` |
| `script.force_battery_charge_from_grid` | `scripts/reset_battery_mode.yaml` | Battery + storage controls |
| `script.force_battery_discharge` | `scripts/reset_battery_mode.yaml` | Battery + storage controls |
| EV charging interaction with battery | `battery_control.yaml` | `automation.battery_hold_during_ev_charging` |
| `battery_will_fill_from_solar_tomorrow` | `solar_forecast.yaml` | `sensor.battery_energy_remaining_kwh` |
| `battery_grid_top_up_needed_kwh` | `solar_forecast.yaml` | `sensor.battery_energy_remaining_kwh` |

---

## Entities That Will Show "Unavailable" Until Battery Install

These entities exist in the package files but will show `unavailable` until the battery hardware is installed:

**Modbus entities (populated by SolarEdge Modbus Multi):**
- `sensor.solaredge_b1_state_of_energy`
- `sensor.solaredge_b1_dc_power`
- `sensor.solaredge_b1_status`
- `sensor.solaredge_b1_energy_charged`
- `sensor.solaredge_b1_energy_discharged`
- `select.solaredge_i1_storage_control_mode`
- `select.solaredge_i1_storage_default_mode`

**Template sensors derived from battery:**
- `sensor.battery_soc_pct`
- `sensor.battery_power_w`
- `sensor.battery_energy_remaining_kwh`
- `sensor.battery_status`
- `binary_sensor.battery_low`
- `binary_sensor.battery_charging`
- `binary_sensor.battery_discharging`

**Calculated sensors:**
- `sensor.battery_grid_top_up_needed_kwh`
- `binary_sensor.battery_will_fill_from_solar_tomorrow`

> All battery automations include availability guards (`condition: template` checking `not in ['unavailable', 'unknown']`) to prevent errors before battery install.

---

## Battery Commissioning Day Checklist

On the day the battery is installed and commissioned:

### During Install
- [ ] Ensure SolarEdge Modbus TCP is still enabled after inverter firmware update
- [ ] Confirm Ethernet connection to inverter (preferred over WiFi)
- [ ] Note any changes to inverter IP address

### After Commissioning
- [ ] Open HA → **Settings → Integrations → SolarEdge Modbus Multi → Configure**
- [ ] Enable **"Read battery data"** and **"Enable storage control"**
- [ ] Restart HA (or reload the integration)
- [ ] Verify `sensor.solaredge_b1_state_of_energy` shows battery percentage
- [ ] Verify `select.solaredge_i1_storage_control_mode` appears
- [ ] Verify `select.solaredge_i1_storage_default_mode` appears

### Test Battery Automations
- [ ] **Developer Tools → Services** → Call `script.reset_battery_to_self_consumption`
- [ ] Check `select.solaredge_i1_storage_default_mode` changes to "Maximize Self Consumption"
- [ ] Restart HA → verify `automation.battery_enable_remote_control_startup` fires
- [ ] Manually test `script.force_battery_charge_from_grid` (duration: 15 min)
- [ ] Verify `input_select.battery_mode_override` auto-resets to `auto` after timer

### First Week Monitoring
- [ ] Monitor logbook for battery automation triggers
- [ ] Adjust `battery_charge_threshold` (default €0.05/kWh) based on your contract
- [ ] Adjust `battery_min_soc` based on backup power needs
- [ ] Verify `battery_will_fill_from_solar_tomorrow` accuracy vs actual production

---

## Frank Energie vs Tibber vs Nord Pool Sensor

| Provider | Best for | Notes |
|---|---|---|
| **Frank Energie** *(HACS)* | Frank Energie customers | Use `sensor.frank_energie_current_price` for all-in price (already includes taxes) |
| **Tibber** *(official)* | Tibber customers | Use `sensor.tibber_price_current` |
| **Nord Pool** *(official/HACS)* | Any contract using spot pricing | Use for calculations; must add energiebelasting + BTW yourself (done in `energy_prices.yaml`) |

> If you're a Frank Energie customer, replace `sensor.nord_pool_nl_current_price` with `sensor.frank_energie_current_price` and remove the all-in price calculation (Frank already returns all-in prices).
