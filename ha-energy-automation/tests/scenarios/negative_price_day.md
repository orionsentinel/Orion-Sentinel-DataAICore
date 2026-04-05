# Test Scenario: Negative Price Day

## Scenario Description

Spot price drops below zero (common in NL on sunny, windy Sundays with low demand). Tests: negative price notification debouncing, GRID_CHARGE bypass of arbitrage guard, 95% target SOC, and notification deduplication.

## Prerequisites

- All integrations available
- Kill switch on
- Battery SOC at 40%
- `input_boolean.negative_price_notified = off`

## Test Steps

### Step 1: Negative price notification fires once

**Setup:** Simulate `sensor.nord_pool_nl_current_price` going negative (e.g. -0.05 €/kWh)

**Expected:**
- `binary_sensor.is_negative_price = on`
- `price_negative_alert_debounced` automation triggers
- Mobile notification sent: "Negatieve energieprijs!" with price details
- `input_boolean.negative_price_notified = on`

**Verify:**
```
Automation Traces → price_negative_alert_debounced → Success
input_boolean.negative_price_notified = on
Mobile: notification received
```

---

### Step 2: Negative price notification NOT re-sent while negative

**Setup:** Wait 30 minutes (price still negative)

**Expected:**
- `price_negative_alert_debounced` does NOT fire again
- Condition `input_boolean.negative_price_notified = off` blocks it

**Verify:**
```
Automation Traces → price_negative_alert_debounced → Condition not met (second trigger)
No duplicate notification on mobile
```

---

### Step 3: Notification resets at midnight for new day

**Setup:** Simulate midnight (or wait for 00:00)

**Expected:**
- `midnight_reset_negative_price_flag` fires
- `input_boolean.negative_price_notified = off`
- If price is still negative the next day, notification fires again

**Verify:**
```
input_boolean.negative_price_notified = off after 00:00:30
```

---

### Step 4: GRID_CHARGE activates bypassing arbitrage guard

**Setup:** Negative price active, `binary_sensor.arbitrage_opportunity = off` (spread < min_spread)

**Expected:**
- `battery_grid_charge_cheap_price` still activates despite arbitrage_opportunity = off
- Condition logic: `(spot <= threshold or is_negative) and (has_arbitrage or is_negative)`
- `is_negative = true` satisfies both sides → GRID_CHARGE activates

**Verify:**
```
Automation Traces → battery_grid_charge_cheap_price → Success
input_select.battery_desired_mode = GRID_CHARGE
sensor.battery_mode_reason shows negative price
```

---

### Step 5: Target SOC set to 95% on negative price

**Setup:** Negative price active

**Expected:**
- `sensor.battery_target_soc = 95`
- GRID_CHARGE continues until SOC reaches 95% (or price goes positive)

**Verify:**
```
sensor.battery_target_soc = 95
Charging continues past 50% and 80% SOC
Stops at 95% → battery_grid_charge_target_reached → HOLD
```

---

### Step 6: Price goes positive → GRID_CHARGE stops

**Setup:** Price rises above 0 (and above threshold)

**Expected:**
- `binary_sensor.is_negative_price = off`
- `binary_sensor.is_cheap_hour = off` (assuming not cheap)
- `battery_grid_charge_stop` fires
- `input_select.battery_desired_mode` → SELF_CONSUME

**Verify:**
```
Automation Traces → battery_grid_charge_stop → Success
input_select.battery_desired_mode = SELF_CONSUME
```

---

## Pass/Fail Criteria

| Check | Pass condition |
|---|---|
| Negative price notification | Fires exactly once per negative-price event |
| Notification deduplication | No duplicate while `negative_price_notified = on` |
| Midnight reset | `negative_price_notified` resets at 00:00:30 |
| Arbitrage bypass | GRID_CHARGE activates even when `arbitrage_opportunity = off` |
| Target SOC = 95% | Charges to 95%, not 50% or 80% |
| Stop on price recovery | GRID_CHARGE stops when price no longer negative/cheap |
