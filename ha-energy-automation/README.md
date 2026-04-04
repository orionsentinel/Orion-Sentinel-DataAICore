# ha-energy-automation

Home Assistant energy automation package for a Dutch household with:
- **SolarEdge SE10000H** single-phase inverter (~4kWp)
- **SolarEdge Home Battery 9.7kWh** *(install in progress)*
- **Dynamic energy contract** (Nord Pool NL spot pricing)
- **Stedin three-phase grid** with HomeWizard P1 meter
- **EV charger** (Easee/go-E/Zaptec/Alfen placeholder)

---

## Repository Structure

| Path | Description |
|---|---|
| `packages/energy_prices.yaml` | Nord Pool sensors, all-in price templates, AIO schedules, price automations |
| `packages/solaredge.yaml` | SolarEdge Modbus template sensors, binary sensors, utility meters |
| `packages/battery_control.yaml` | Battery mode automations (7 automations, startup + scheduling + fallback) |
| `packages/ev_charging.yaml` | Smart EV charging — price, solar excess, departure deadline |
| `packages/appliances.yaml` | Washer/dishwasher/dryer scheduling based on cheapest overnight hours |
| `packages/solar_forecast.yaml` | Forecast.Solar integration, cloudy/sunny detection, grid charge decisions |
| `dashboards/energy_dashboard.yaml` | Full Lovelace dashboard (Mushroom + ApexCharts + Mini Graph Card) |
| `scripts/reset_battery_mode.yaml` | Three manual battery control scripts |
| `docs/SETUP.md` | Complete step-by-step setup guide |
| `docs/NOW_VS_LATER.md` | Pre/post battery install feature table, commissioning checklist |
| `docs/ENTITY_NAMES.md` | Entity mapping tables, discovery templates, bulk rename commands |

---

## Quick Start

### Step 1: Enable Packages in `configuration.yaml`

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Copy `packages/` to your HA config directory.

### Step 2: Install Required Integrations

| Integration | Type | Purpose |
|---|---|---|
| Nord Pool | Official HA | Spot prices (NL) |
| HomeWizard Energy | Official HA | P1 three-phase meter |
| Forecast.Solar | Official HA | Solar production forecast |
| SolarEdge Modbus Multi | HACS | Inverter + battery control |
| AIO Energy Management | HACS | Cheapest/expensive hour scheduling |
| Mushroom Cards | HACS Frontend | Dashboard cards |
| ApexCharts Card | HACS Frontend | Price chart |
| Mini Graph Card | HACS Frontend | Power history graphs |

### Step 3: Enable Modbus TCP on SE10000H

Long-press the LCD button → **Comm → Modbus TCP → Enabled**

Then in HA: **Settings → Integrations → SolarEdge Modbus Multi** (host = inverter IP, port 502).

---

## Frank Energie vs Tibber vs Nord Pool

| Provider | Recommendation | Notes |
|---|---|---|
| **Frank Energie** | ✅ Best for solar households | Offers salderingskorting + transparent pricing; HACS integration available |
| **Tibber** | Good for EV owners | Strong EV smart charging integration; slightly higher base price |
| **Nord Pool sensor** | ✅ Used in this package | Provider-agnostic; add energiebelasting + BTW in template (done in `energy_prices.yaml`) |

> This package uses the Nord Pool sensor for automations, making it compatible with any dynamic-pricing contract. If you're on Frank Energie, replace `sensor.nord_pool_nl_current_price` with `sensor.frank_energie_current_price` and remove the tax calculation (Frank prices are all-in).

---

## Entity Placeholders to Replace

Search for `# ← replace` in all YAML files to find all entities that need to be updated for your specific hardware:

```bash
grep -r "← replace" packages/ scripts/
```

Key replacements:
- `switch.ev_charger` → your EV charger switch
- `sensor.ev_state_of_charge` → your EV SoC sensor
- `binary_sensor.ev_plugged_in` → your EV connected sensor
- `switch.washing_machine_smart_plug` → your washing machine plug
- `switch.dishwasher_smart_plug` → your dishwasher plug
- `switch.dryer_smart_plug` → your dryer plug
- `notify.mobile_app` → your notification service

---

## License

MIT License — free to use, modify, and distribute. Attribution appreciated but not required.

---

## Documentation

- [Setup Guide](docs/SETUP.md)
- [Now vs Later (pre/post battery)](docs/NOW_VS_LATER.md)
- [Entity Names Reference](docs/ENTITY_NAMES.md)
