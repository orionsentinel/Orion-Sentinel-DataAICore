# Test Scenario: High Price Volatility Day

## Scenario Description

A day with extreme price differences: very cheap overnight (e.g. 1–3 ct/kWh spot) and expensive afternoon (e.g. 40–50 ct/kWh spot). Tests the full GRID_CHARGE → HOLD → PEAK_DISCHARGE cycle including arbitrage guard and dynamic target SOC.

## Prerequisites

- Battery hardware installed and available (`binary_sensor.battery_hardware_available = on`)
- SolarEdge Modbus available (`binary_sensor.modbus_available = on`)
- Nord Pool prices fresh (`sensor.price_freshness_ok = true`)
- Kill switch on (`input_boolean.energy_automation_enabled = on`)
- Grid charge allowed (`input_boolean.allow_grid_battery_charge = on`)
- Battery SOC at 30% before test begins
- Arbitrage min spread at default 0.10 €/kWh (`input_number.arbitrage_min_spread = 0.10`)

## Test Steps

### Step 1: Verify arbitrage guard activates

**Setup:** Set today's price spread to >0.10 €/kWh (simulate with template override or wait for real prices)

**Expected:**
- `sensor.price_spread_today` shows spread > 0.10
- `binary_sensor.arbitrage_opportunity = on`

**Verify:**
```
Developer Tools → States → binary_sensor.arbitrage_opportunity = on
Developer Tools → States → sensor.price_spread_today > 0.10
```

---

### Step 2: GRID_CHARGE activates during cheap hour

**Setup:** Simulate `binary_sensor.is_cheap_hour = on` (or wait for actual cheap hour)

**Expected:**
- `battery_grid_charge_cheap_price` automation triggers
- `input_select.battery_desired_mode` → GRID_CHARGE
- `sensor.battery_mode_reason` shows "Laden van net — spotprijs: X €/kWh"
- After executor runs: SolarEdge Modbus receives "Charge from Grid" command
- `input_datetime.battery_last_mode_change` updates

**Verify:**
```
Automation Traces → battery_grid_charge_cheap_price → Success
Developer Tools → States → input_select.battery_desired_mode = GRID_CHARGE
Logbook → "Charge from Grid" sent to select.solaredge_i1_storage_default_mode
```

---

### Step 3: HOLD when target SOC reached

**Setup:** Wait for SOC to reach `sensor.battery_target_soc` (default 50% for moderate day)

**Expected:**
- `battery_grid_charge_target_reached` automation triggers
- `input_select.battery_desired_mode` → HOLD
- Battery stops charging from grid but keeps charging from solar if available

**Verify:**
```
Automation Traces → battery_grid_charge_target_reached → Success
input_select.battery_desired_mode = HOLD
```

---

### Step 4: Rate limit respected during transitions

**Setup:** Force two rapid mode changes within 5 minutes

**Expected:**
- First change: executes, `input_datetime.battery_last_mode_change` updates
- Second change (within 5 min): `binary_sensor.battery_change_allowed = off`, executor logs "rate limited" and skips Modbus write
- No error — system is stable

**Verify:**
```
System Log → "Battery mode executor: rate limited — last change <5 min ago"
binary_sensor.battery_change_allowed = off (wait 5 min → turns back on)
```

---

### Step 5: PEAK_DISCHARGE during expensive hour

**Setup:** Simulate `binary_sensor.is_expensive_hour = on`, battery SOC > 25%

**Expected:**
- `battery_peak_discharge` automation triggers
- Checks arbitrage_opportunity = on (required)
- `input_select.battery_desired_mode` → PEAK_DISCHARGE
- SolarEdge receives "Maximize Self Consumption" (allows discharge)

**Verify:**
```
Automation Traces → battery_peak_discharge → Success
input_select.battery_desired_mode = PEAK_DISCHARGE
```

---

### Step 6: No PEAK_DISCHARGE when arbitrage guard off

**Setup:** Set `input_number.arbitrage_min_spread` to 0.30 €/kWh (higher than today's spread)

**Expected:**
- `binary_sensor.arbitrage_opportunity = off`
- `battery_peak_discharge` automation fails condition check — does NOT change mode
- Battery stays in current mode (SELF_CONSUME or HOLD)

**Verify:**
```
Automation Traces → battery_peak_discharge → Condition not met
binary_sensor.arbitrage_opportunity = off
input_select.battery_desired_mode ≠ PEAK_DISCHARGE
```

---

### Step 7: Hourly reset catches stale state

**Setup:** Wait until :05 of the next hour with mode in GRID_CHARGE but `is_cheap_hour = off`

**Expected:**
- `battery_hourly_fallback_reset` fires at :05
- Mode resets to SELF_CONSUME
- System stable

**Verify:**
```
Automation Traces → battery_hourly_fallback_reset → Success
input_select.battery_desired_mode = SELF_CONSUME
```

---

## Pass/Fail Criteria

| Check | Pass condition |
|---|---|
| arbitrage_opportunity gates GRID_CHARGE | No GRID_CHARGE when spread < min_spread |
| arbitrage_opportunity gates PEAK_DISCHARGE | No PEAK_DISCHARGE when spread < min_spread |
| Rate limiting | Second write within 5min is skipped |
| Target SOC stops GRID_CHARGE | Mode → HOLD when target reached |
| Minimum SOC stops PEAK_DISCHARGE | Mode → SELF_CONSUME when battery_low |
| Hourly reset | Stale non-FORCE modes reset at :05 |
