# Now vs Later — What to Enable

What you can use **immediately** (before battery install) vs what requires **the SolarEdge Home Battery 9.7 and Home Hub** to be installed and commissioned.

---

## Enable Now (Pre-Battery)

| Feature | Package | Status |
|---|---|---|
| Nord Pool price sensors | `02_energy_prices.yaml` | ✅ Works now |
| All-in price template (`sensor.energy_price_all_in`) | `02_energy_prices.yaml` | ✅ Works now |
| Price freshness guard (`sensor.price_freshness_ok`) | `02_energy_prices.yaml` | ✅ Works now |
| AIO Energy Management schedules (cheapest 4h, 6h, most expensive 4h) | `02_energy_prices.yaml` | ✅ Works now |
| Price helpers (input_number, input_boolean) | `02_energy_prices.yaml` | ✅ Works now |
| Negative price alert | `02_energy_prices.yaml` | ✅ Works now |
| SolarEdge inverter production sensors | `03_solaredge.yaml` | ✅ Works now (Modbus required) |
| Grid power/import/export sensors | `03_solaredge.yaml` | ✅ Works now (P1 + Modbus) |
| House consumption sensors | `03_solaredge.yaml` | ✅ Works now |
| `binary_sensor.solar_producing` | `03_solaredge.yaml` | ✅ Works now |
| `binary_sensor.exporting_to_grid` | `03_solaredge.yaml` | ✅ Works now |
| `binary_sensor.modbus_available` | `03_solaredge.yaml` | ✅ Works now |
| Utility meters (daily/monthly solar, grid) | `03_solaredge.yaml` | ✅ Works now |
| System watchdogs (Modbus, Alfen, price) | `01_system_watchdogs.yaml` | ✅ Works now |
| Battery mode input_select (safe dummy) | `04_battery_state_machine.yaml` | ✅ Safe now (executor guards availability) |
| EV smart charging (Alfen) | `06_alfen_ev_charging.yaml` | ✅ Works now |
| Appliance scheduling | `07_appliances.yaml` | ✅ Works now |
| Solar forecast sensors | `08_solar_forecast.yaml` | ✅ Works now (Forecast.Solar required) |
| Daily grid charge permission (13:30) | `05_battery_automations.yaml` | ⚠️ Runs but has no effect without battery |
| Energy dashboard | `dashboards/energy_dashboard.yaml` | ✅ Battery cards show "unavailable" — OK |

---

## Requires Battery Install (Activate After Battery Commissioning)

| Feature | Package | Requires |
|---|---|---|
| Battery template sensors (`battery_soc_pct`, `battery_power_w`, etc.) | `03_solaredge.yaml` | `solaredge_b1_*` Modbus entities |
| `binary_sensor.battery_available` = true | `03_solaredge.yaml` | `solaredge_b1_state_of_energy` available |
| `binary_sensor.battery_low` | `03_solaredge.yaml` | `solaredge_b1_state_of_energy` |
| `binary_sensor.battery_charging/discharging` | `03_solaredge.yaml` | `solaredge_b1_dc_power` |
| Mode Executor actually writes to Modbus | `04_battery_state_machine.yaml` | `battery_available = on` |
| Battery rules write to Modbus (all rules) | `05_battery_automations.yaml` | Battery available |
| GRID_CHARGE, PEAK_DISCHARGE modes | `04_battery_state_machine.yaml` | Battery + storage controls |
| HOLD mode (EV hold) | `04_battery_state_machine.yaml` | Battery + storage controls |
| Manual force scripts | `scripts/battery_mode_override.yaml` | Battery available |
| `battery_energy_remaining_kwh` | `03_solaredge.yaml` | `solaredge_b1_state_of_energy` |
| `battery_grid_topup_needed_kwh` | `08_solar_forecast.yaml` | `battery_energy_remaining_kwh` |
| `binary_sensor.battery_will_fill_naturally` | `08_solar_forecast.yaml` | Battery entities |

---

## Entities That Show "Unavailable" Until Battery Install

These entities exist in the YAML files and are intentionally unavailable until hardware is installed. All automation conditions guard against this:

**SolarEdge Modbus Multi (battery entities):**
- `sensor.solaredge_b1_state_of_energy` — battery SOC
- `sensor.solaredge_b1_dc_power` — battery power flow
- `sensor.solaredge_b1_status` — battery status code
- `sensor.solaredge_b1_energy_charged` — total energy charged
- `sensor.solaredge_b1_energy_discharged` — total energy discharged
- `select.solaredge_i1_storage_control_mode` — battery control mode
- `select.solaredge_i1_storage_default_mode` — battery default mode

**Template sensors (derived from battery):**
- `sensor.battery_soc_pct`
- `sensor.battery_power_w`
- `sensor.battery_energy_remaining_kwh`
- `sensor.battery_status`
- `binary_sensor.battery_available` ← becomes `on` when battery entities appear
- `binary_sensor.battery_low`
- `binary_sensor.battery_charging`
- `binary_sensor.battery_discharging`

---

## Battery Install Commissioning Checklist

### Day of Installation

Before the installer arrives:
- [ ] Confirm SolarEdge Home Hub is part of the order (required for battery control)
- [ ] Ensure Ethernet is connected to the inverter (critical — see docs/MODBUS_PROXY.md)
- [ ] Note the current inverter firmware version (from monitoring.solaredge.com or LCD)

During installation:
- [ ] Ask installer to confirm Modbus TCP is still enabled after any firmware updates
- [ ] Ask installer to confirm Home Hub is commissioned and communicating with inverter
- [ ] Note any changes to inverter IP address (DHCP may assign a new one)

### After Installation (Day 1)

- [ ] Check that inverter IP hasn't changed (router DHCP table)
- [ ] Open HA: verify `sensor.solaredge_i1_ac_power` is still available (Modbus intact)
- [ ] Go to **Settings → Integrations → SolarEdge Modbus Multi → Configure**
- [ ] Enable **"Read battery data"** and **"Enable storage control"**
- [ ] Restart HA (Settings → System → Restart)
- [ ] Verify `sensor.solaredge_b1_state_of_energy` appears (battery SOC)
- [ ] Verify `binary_sensor.battery_available` shows `on`
- [ ] Verify `select.solaredge_i1_storage_control_mode` appears

### Battery Control Verification (Week 1)

- [ ] Call `script.reset_battery_to_self_consumption` via Developer Tools → Services
- [ ] Verify `select.solaredge_i1_storage_default_mode` changes to "Maximize Self Consumption"
- [ ] Restart HA and verify `automation.battery_startup_init` fires (check logbook)
- [ ] Verify `input_text.battery_last_action` gets updated on HA restart
- [ ] Manually test `script.force_battery_charge_from_grid` (set duration: 15 min)
- [ ] Verify `input_select.battery_desired_mode` shows `FORCE_CHARGE` during test
- [ ] Verify it automatically resets to `SELF_CONSUME` after 15 minutes
- [ ] Monitor logbook for battery automation triggers for 48 hours

### Settings to Adjust After Battery Install

| Setting | Default | Recommended adjustment |
|---|---|---|
| `battery_min_soc` | 20% | Adjust based on your backup power needs (10% if no backup needed, 30% if you want emergency reserve) |
| `battery_charge_price_threshold` | 0.02 €/kWh | Start conservative, increase if cheap hours aren't triggering |
| `solar_sunny_day_threshold` | 15 kWh | Adjust after observing actual peak production days |
| `solar_cloud_day_threshold` | 5 kWh | Adjust after observing actual cloudy day production |
