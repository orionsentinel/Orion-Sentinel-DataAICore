# Alfen Eve Wallbox — Critical Warnings

## ⚠️ Warning 1: Flash Memory Wear (Hardware Killer)

### The Problem

The Alfen Eve wallbox stores certain configuration parameters — including the **current limit setting (register 2129_0)** — in **EEPROM/flash memory**. Flash memory has a finite number of write cycles, typically around **100,000 writes** per cell.

If you implement dynamic current adjustment (changing the charging current based on solar production, price, or other real-time signals) and update this register continuously, you **will physically destroy the charger** within months. This is not a hypothetical risk — it has happened to users who implemented aggressive current control loops.

At 1-minute update intervals: 100,000 cycles / 1,440 writes per day ≈ **70 days to failure**.  
At 5-minute intervals: ≈ **347 days**.  
At 15-minute intervals, only on change: ≈ **years** (acceptable).

### What This Repo Does (Safe)

This repository uses **only** `switch.alfen_wallbox_availability_manager` for price-based charging control. This is an on/off enable/disable signal that does **not** write to the current-limit register. It is safe to switch this frequently.

### What NOT to Do

- Do NOT write `number.alfen_wallbox_max_station_current` in a loop
- Do NOT write `number.alfen_wallbox_max_station_current` on a timer
- Do NOT implement a "solar following" feature that adjusts current every minute or faster

### If You Ever Add Current Limiting

If you implement dynamic current adjustment in the future, follow these rules:

1. **Minimum 15-minute debounce** between any two writes to the current limit register
2. **Only write on actual value change** — if the calculated current is the same as last time, skip the write
3. **Minimum change threshold of 1A** — only write if the new value differs by more than 1A from the last written value
4. **Log every write** with timestamp — to monitor write frequency and catch bugs

The safe approach is to set the fixed current once in the Alfen app (SetApp or Eve Connect) and let HA only control enable/disable. Configure the fixed current to the maximum you want to charge at (e.g., 16A single-phase, 32A three-phase).

---

## ⚠️ Warning 2: Single API Session Lock

### The Problem

The Alfen Eve allows only **one active HTTPS API session** at a time. Home Assistant (via the leeyuentuen/alfen_wallbox integration) holds a persistent authenticated session. 

If you open the **Eve Connect app** or the **50five app** while HA has the active session:
- HA loses its session
- The app may also fail to connect (or briefly succeed, then lose control)
- HA automations stop controlling the charger until the session is re-established

The watchdog automation in `01_system_watchdogs.yaml` detects session loss (via `binary_sensor.alfen_wallbox_https_api_login_status`) and notifies you to press the Login button in HA.

### How to Switch Between HA and the App

**Option A: Use the scripts in `scripts/alfen_session_manager.yaml`**

Before opening the app:
1. Call script `alfen_release_session` — this logs out from the HA integration
2. Open Eve Connect or 50five app — it will now be able to connect
3. When done with the app, call script `alfen_reclaim_session`

**Option B: Manual through the HA integration**

1. Go to **Settings → Integrations → Alfen EV Wallbox**
2. Click on your device
3. Press the **Logout** button to release the session
4. Use the app
5. Press the **Login** button when done

**Option C: Just wait for the watchdog**

If you accidentally open the app and lose the HA session, the watchdog will notify you. Follow the instructions in the notification to press Login in the integration.

### Signs of a Lost Session

- `binary_sensor.alfen_wallbox_https_api_login_status` is `off`
- All Alfen entities show `unavailable`
- EV charging automations appear to not work
- Watchdog notification received

### Why Only One Session?

This is a firmware limitation of the Alfen Eve. The embedded HTTPS server in the charger can only maintain one authenticated client at a time. This is common in embedded devices with limited memory.

---

## Safe Usage Checklist

Before making any changes to EV charging automation:

- [ ] Only use `switch.alfen_wallbox_availability_manager` for on/off control
- [ ] Any current limit changes: minimum 15-minute debounce, only on actual change
- [ ] Release HA session before using Eve Connect / 50five app
- [ ] Reclaim HA session after using the app
- [ ] Watchdog automation `watchdog_alfen_session_lost` is enabled

---

## Entity Reference

| Entity | Safe to use frequently? | Notes |
|---|---|---|
| `switch.alfen_wallbox_availability_manager` | ✅ Yes | On/off control, no flash wear |
| `sensor.alfen_wallbox_active_power_total` | ✅ Yes | Read-only, no flash |
| `sensor.alfen_wallbox_status` | ✅ Yes | Read-only, no flash |
| `binary_sensor.alfen_wallbox_https_api_login_status` | ✅ Yes | Read-only |
| `number.alfen_wallbox_max_station_current` | ⚠️ Very carefully | Flash write — max 1x/15min |
| `number.alfen_wallbox_max_socket_current` | ⚠️ Very carefully | Flash write — max 1x/15min |

---

## Resources

- [leeyuentuen/alfen_wallbox HACS integration](https://github.com/leeyuentuen/alfen_wallbox)
- [Alfen Eve Pro documentation](https://alfen.com/en/ev-charging/alfen-eve-pro)
- 50five support: contact your 50five installer for installer password and SetApp access
