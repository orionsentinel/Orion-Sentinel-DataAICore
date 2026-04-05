# Battery State Machine Tests

Manual test procedures for `04_battery_state_machine.yaml` and `05_battery_automations.yaml`.

**Prerequisites:**
- SolarEdge Home Battery 9.7 installed and commissioned
- `binary_sensor.battery_available` = `on`
- `binary_sensor.modbus_available` = `on`

---

## Test 1: SELF_CONSUME (Default Mode)

**Purpose:** Verify the default mode is set correctly on HA startup.

**Steps:**
1. Restart HA: **Settings → System → Restart HA**
2. Wait 60 seconds for all integrations to initialize
3. Go to **Developer Tools → States**

**Expected results:**
- `input_select.battery_desired_mode` = `SELF_CONSUME`
- `select.solaredge_i1_storage_default_mode` = `Maximize Self Consumption`
- `select.solaredge_i1_storage_control_mode` = `Remote Control`
- `input_text.battery_last_action` contains "HA opgestart — batterij ingesteld op SELF_CONSUME"

**Reset:** Already in SELF_CONSUME — no reset needed.

---

## Test 2: GRID_CHARGE (Cheap Price Trigger)

**Purpose:** Verify battery switches to grid charging when price is below threshold.

**Steps:**
1. Note the current value of `input_number.battery_charge_price_threshold`
2. Go to **Developer Tools → States**
3. Set `input_number.battery_charge_price_threshold` to `1.0` (forces threshold above any real price)
4. Ensure `input_boolean.allow_grid_battery_charge` = `on`
5. Ensure `sensor.battery_soc_pct` < 95% (if not, set `battery_charge_price_threshold` to 0.02 after battery charges a bit)
6. Wait for `automation.battery_rule_grid_charge_cheap_price` to fire (triggers at :02 every hour)
   - OR: Go to **Developer Tools → Automations** → find `battery_rule_grid_charge_cheap_price` → click Run button

**Expected results:**
- `input_select.battery_desired_mode` = `GRID_CHARGE`
- `select.solaredge_i1_storage_default_mode` = `Charge from PV and AC`
- `input_text.battery_last_action` contains "→ GRID_CHARGE:"
- Actual battery starts charging (check `sensor.battery_power_w` > 0)

**Verify Mode Executor ran:**
- `select.solaredge_i1_storage_control_mode` = `Remote Control`
- `select.solaredge_i1_storage_default_mode` = `Charge from PV and AC`

**Reset:**
1. Set `input_number.battery_charge_price_threshold` back to original value (e.g., `0.02`)
2. Call `script.reset_battery_to_self_consumption` via Developer Tools → Services
3. Verify `input_select.battery_desired_mode` returns to `SELF_CONSUME`

---

## Test 3: PEAK_DISCHARGE (Expensive Hour)

**Purpose:** Verify battery discharges during expensive price hours.

**Steps:**
1. Ensure `sensor.battery_soc_pct` is above `input_number.battery_min_soc` (e.g., SOC > 20%)
2. Ensure `binary_sensor.solar_producing` = `off` (test at night or block solar)
3. Temporarily set `binary_sensor.is_expensive_hour` by manipulating price data:
   - Note the current 75th percentile threshold: check `sensor.price_rank_today`
   - Alternative: manually trigger the automation from Developer Tools
4. Trigger `automation.battery_rule_peak_discharge` manually via Developer Tools → Automations

**Expected results:**
- `input_select.battery_desired_mode` = `PEAK_DISCHARGE`
- `select.solaredge_i1_storage_default_mode` = `Maximize Export`
- `sensor.battery_power_w` < 0 (discharging)
- `sensor.grid_export_w` > 0 (exporting to grid)
- `input_text.battery_last_action` contains "→ PEAK_DISCHARGE:"

**Reset:**
1. Call `script.reset_battery_to_self_consumption` via Developer Tools → Services
2. Verify `select.solaredge_i1_storage_default_mode` returns to `Maximize Self Consumption`

---

## Test 4: HOLD (EV Charging Active)

**Purpose:** Verify battery holds when EV charger activates.

**Prerequisites:** Alfen wallbox connected and `binary_sensor.battery_available` = `on`.

**Steps:**
1. Start EV charging: **Developer Tools → Services** → `switch.turn_on` → `switch.alfen_wallbox_availability_manager`
2. Wait 2 minutes (the `for: "00:02:00"` debounce on the trigger)
3. Check that `sensor.alfen_wallbox_active_power_total` > 500W

**Expected results:**
- `input_select.battery_desired_mode` = `HOLD`
- `select.solaredge_i1_storage_default_mode` = `Charge from PV`
- `input_text.battery_last_action` contains "→ HOLD: EV aan het laden"
- Battery NOT discharging (verify `sensor.battery_power_w` ≥ 0)

**Test HOLD release:**
1. Stop EV charging: `switch.turn_off` → `switch.alfen_wallbox_availability_manager`
2. Wait 5 minutes (the `for: "00:05:00"` debounce on the release trigger)

**Expected results after EV stops:**
- `input_select.battery_desired_mode` = `SELF_CONSUME`
- `select.solaredge_i1_storage_default_mode` = `Maximize Self Consumption`

---

## Test 5: FORCE_CHARGE (Manual Override)

**Purpose:** Verify manual force charge script works and auto-resets.

**Steps:**
1. Go to **Developer Tools → Services**
2. Service: `script.force_battery_charge_from_grid`
3. Data: `{"duration_minutes": 15}`
4. Call service

**Expected results (immediate):**
- `input_select.battery_desired_mode` = `FORCE_CHARGE`
- `select.solaredge_i1_storage_default_mode` = `Charge from PV and AC`
- `input_text.battery_last_action` contains "→ FORCE_CHARGE: handmatig gestart voor 15 min"
- Notification received on phone

**Expected results after 15 minutes:**
- `input_select.battery_desired_mode` = `SELF_CONSUME` (auto-reset)
- `select.solaredge_i1_storage_default_mode` = `Maximize Self Consumption`

---

## Test 6: FORCE_DISCHARGE (Manual Override)

**Purpose:** Verify manual force discharge script works and auto-resets.

**Prerequisites:** `sensor.battery_soc_pct` > `input_number.battery_min_soc`.

**Steps:**
1. Go to **Developer Tools → Services**
2. Service: `script.force_battery_discharge`
3. Data: `{"duration_minutes": 15}`
4. Call service

**Expected results:**
- `input_select.battery_desired_mode` = `FORCE_DISCHARGE`
- `select.solaredge_i1_storage_default_mode` = `Maximize Export`
- `sensor.battery_power_w` < 0 (discharging)
- `sensor.grid_export_w` > 0 (exporting)

**Expected after 15 minutes:** Auto-reset to SELF_CONSUME.

**Verify guard (low battery):**
1. Set `input_number.battery_min_soc` to 100 (above any real SOC)
2. Try calling `script.force_battery_discharge`
3. Expected: script should NOT activate (condition fails)
4. Reset `input_number.battery_min_soc` back to 20

---

## Test 7: Modbus Unavailable Guard

**Purpose:** Verify Mode Executor does NOT write to Modbus when unavailable.

**Steps (simulate unavailability):**
1. Temporarily disconnect the inverter from the network (unplug Ethernet) OR
2. Stop the Modbus Multi integration
3. Wait for `binary_sensor.modbus_available` → `off`
4. Try calling `script.force_battery_charge_from_grid` via Developer Tools

**Expected results:**
- Script may set `input_select.battery_desired_mode` = `FORCE_CHARGE`
- BUT `select.solaredge_i1_storage_default_mode` should NOT change
- `input_text.battery_last_action` should contain "⚠️ Modbus/batterij niet beschikbaar"
- Watchdog fires after 10 minutes: notification received

**Reset:** Reconnect Ethernet. Verify `binary_sensor.modbus_available` → `on`.
Verify `automation.battery_startup_init` triggers or manually call `script.reset_battery_to_self_consumption`.

---

## Test 8: Hourly Fallback Reset

**Purpose:** Verify safety reset fires at :05 every hour.

**Steps:**
1. Manually set `input_select.battery_desired_mode` to `PEAK_DISCHARGE`
2. Ensure `binary_sensor.cheapest_4h_overnight` = `off`
3. Ensure `binary_sensor.most_expensive_4h` = `off`
4. Wait until :05 of the next hour

**Expected:** `input_select.battery_desired_mode` resets to `SELF_CONSUME`

**Note:** FORCE modes are NOT reset by the hourly fallback (by design).
