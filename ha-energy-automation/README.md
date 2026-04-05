# ha-energy-automation

Production-grade Home Assistant energy automation for a Dutch household:

| Hardware | Status |
|---|---|
| SolarEdge SE10000H inverter (~4kWp, south-facing) | ✅ Supported |
| SolarEdge Home Hub + Home Battery 9.7kWh | ⏳ Coming soon — automations ready |
| Stedin three-phase grid + HomeWizard P1 HWE-P1 | ✅ Supported |
| Alfen Eve wallbox (50five, leeyuentuen HACS) | ✅ Supported |
| Tesla (alandtse HACS or official Fleet API) | ✅ Informational SOC only |
| Nord Pool NL dynamic contract | ✅ Supported |

---

## ⚠️ Critical Warnings — Read These First

### 1. Run an Ethernet Cable ASAP

SolarEdge is actively removing WiFi Modbus in firmware updates. Your inverter is currently WiFi-only. **The Modbus connection will break** on the next firmware push.

→ **[See docs/MODBUS_PROXY.md](docs/MODBUS_PROXY.md)** — interim proxy workaround + permanent Ethernet fix.

### 2. Alfen Flash Wear

Writing to the Alfen current-limit register in a loop **physically destroys the charger**. This repo uses only the enable/disable switch — never current limits.

→ **[See docs/ALFEN_WARNING.md](docs/ALFEN_WARNING.md)** — full explanation + safe usage rules.

### 3. Tesla SOC is Unreliable

All EV charging decisions use the Alfen power sensor as the primary signal. Tesla SOC is a soft hint in notifications only.

→ **[See docs/TESLA_SETUP.md](docs/TESLA_SETUP.md)**

---

## Repository Structure

| File | Description |
|---|---|
| `packages/00_secrets_template.yaml` | Template for secrets.yaml |
| `packages/01_system_watchdogs.yaml` | Modbus/Alfen/price freshness watchdogs |
| `packages/02_energy_prices.yaml` | Nord Pool sensors, all-in price, AIO schedules |
| `packages/03_solaredge.yaml` | Modbus template sensors with availability guards |
| `packages/04_battery_state_machine.yaml` | **Single writer** state machine — sole Modbus writer |
| `packages/05_battery_automations.yaml` | Rules → input_select only (never direct Modbus) |
| `packages/06_alfen_ev_charging.yaml` | Flash-safe EV control, SOC-optional |
| `packages/07_appliances.yaml` | Washer/dishwasher/dryer overnight scheduling |
| `packages/08_solar_forecast.yaml` | Forecast.Solar integration, grid-charge decisions |
| `dashboards/energy_dashboard.yaml` | Full Lovelace dashboard |
| `scripts/battery_mode_override.yaml` | Manual battery force scripts |
| `scripts/alfen_session_manager.yaml` | Alfen Login/Logout session scripts |
| `docs/SETUP.md` | Complete 14-step setup guide |
| `docs/MODBUS_PROXY.md` | WiFi Modbus deprecation + solutions |
| `docs/ALFEN_WARNING.md` | Flash wear danger + session lock |
| `docs/TESLA_SETUP.md` | Tesla integration options |
| `docs/BATTERY_STATE_MACHINE.md` | State machine architecture + debugging |
| `docs/NOW_VS_LATER.md` | Pre/post battery install feature table |
| `docs/ENTITY_NAMES.md` | Entity discovery + rename guide |
| `tests/` | Manual test procedures for all automations |

---

## Quick Start (3 Steps)

### Step 1: Run an Ethernet Cable

See [docs/MODBUS_PROXY.md](docs/MODBUS_PROXY.md). Do this before anything else.

### Step 2: Enable packages in `configuration.yaml`

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Copy the `packages/` directory to `/config/packages/`.

### Step 3: Create `secrets.yaml`

```bash
cp packages/00_secrets_template.yaml /config/secrets.yaml
# Edit /config/secrets.yaml with your actual values
```

Then follow the full [docs/SETUP.md](docs/SETUP.md) guide.

---

## Key Architecture Decision: Battery State Machine

This repo uses a **Single Writer Pattern** for battery control. Seven rule automations evaluate conditions and write to `input_select.battery_desired_mode`. One executor automation translates that to Modbus writes. This eliminates race conditions.

```
Rule automations → input_select.battery_desired_mode → Mode Executor → Modbus
```

**Priority:** `FORCE_DISCHARGE > FORCE_CHARGE > GRID_CHARGE > PEAK_DISCHARGE > HOLD > SELF_CONSUME`

→ [docs/BATTERY_STATE_MACHINE.md](docs/BATTERY_STATE_MACHINE.md)

---

## Frank Energie vs Tibber vs Nord Pool

| Provider | This repo | Notes |
|---|---|---|
| **Frank Energie** (HACS) | Replace `sensor.nord_pool_nl_current_price` with Frank entity | Frank prices are all-in — remove tax formula |
| **Tibber** (official) | Replace with Tibber price entity | Use `sensor.tibber_price_current` |
| **Nord Pool** (official HA) | ✅ Used by default | Must add taxes via template (done in `02_energy_prices.yaml`) |

---

## Required HACS Integrations

| Integration | Purpose |
|---|---|
| SolarEdge Modbus Multi | Inverter + battery Modbus control |
| AIO Energy Management | Cheapest/most expensive hour scheduling |
| alfen_wallbox (leeyuentuen) | Alfen Eve control |
| Mushroom Cards (frontend) | Dashboard cards |
| ApexCharts Card (frontend) | Price chart |
| Mini Graph Card (frontend) | Power history |

---

## First Things To Do Checklist

- [ ] Run an Ethernet cable to the inverter (most important — see docs/MODBUS_PROXY.md)
- [ ] Copy `secrets.yaml.template` → `/config/secrets.yaml` and fill in values
- [ ] Enable packages in `configuration.yaml`
- [ ] Install Nord Pool integration (NL, EUR)
- [ ] Install HomeWizard Energy integration
- [ ] Install and configure SolarEdge Modbus Multi (HACS)
- [ ] Install and configure Alfen EV Wallbox (HACS)
- [ ] Install HACS frontend cards (Mushroom, ApexCharts, Mini Graph Card)
- [ ] Install AIO Energy Management (HACS)
- [ ] Replace appliance placeholder entities (`grep -r "← replace" packages/`)
- [ ] Add dashboard from `dashboards/energy_dashboard.yaml`
- [ ] Verify no YAML errors: Settings → System → Logs

---

## License

MIT License — free to use, modify, and distribute.
