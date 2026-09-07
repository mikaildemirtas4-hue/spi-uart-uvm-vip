# SystemVerilog UVM Verification IP Collection

![Simulator](https://img.shields.io/badge/Simulator-QuestaSim%202025.2-1f4e79)
![SPI](https://img.shields.io/badge/SPI%20real--DUT-20%2F20%20passing-c55a11)
![UART](https://img.shields.io/badge/UART%20real--DUT-40%2F40%20passing-1f4e79)
![License](https://img.shields.io/badge/License-Apache%202.0-c55a11)

Reusable SPI and UART UVM Verification IPs (UVCs). Both support master/slave
(or TX/RX) roles, active/passive configuration, functional coverage, and a
callback-based extension mechanism — and both have been run end-to-end in
Siemens QuestaSim against a real, synthesizable RTL DUT.

| VIP | What it covers | Verified against a real DUT |
|---|---|---|
| [`spi_vip/`](./spi_vip) | All 4 SPI modes (CPOL/CPHA), master + slave, multiple CS lines | **20/20 pass** |
| [`uart_vip/`](./uart_vip) | Configurable baud/parity/stop-bits, break-condition detection | **40/40 pass** |

Each folder has its own detailed `README.md` (architecture, integration
steps, sequence library). This file is just the overview and quick start.

## Why this repo exists

I got tired of rewriting the SPI/UART side of a testbench for every new
project, so I built something I could trust and reuse. While developing
both VIPs I ran them step by step in Questa and found (and fixed) real
bugs along the way — a SystemVerilog port-direction leak with `ref`
arguments, a couple of randomization constraint conflicts, and a genuine
timing bug in each of the two reference RTL DUTs. "It works" here means it
was actually compiled and simulated end-to-end in Questa, not just written
and assumed correct.

## Quick Start

```bash
git clone <this-repo>
cd <this-repo>

# To pull the SPI VIP into your own project:
cp -r spi_vip /path/to/your/project/

# To pull the UART VIP into your own project:
cp -r uart_vip /path/to/your/project/
```

See each folder's `README.md` for compile order and integration steps.
Both also contain:
- `example/` — a VIP-to-VIP loopback demo with a scoreboard (quick sanity
  check, no DUT needed)
- `example_real_dut/` — a synthesizable reference RTL DUT plus a full
  Questa `.do` script

## Tested Environment

- Siemens QuestaSim 2025.2 (UVM-1.2)
- SystemVerilog / IEEE 1800-2012 compliant syntax

## What's genuinely there vs. what isn't

Both VIPs cover the core protocol mechanics correctly and have been proven
against real RTL. What they don't include: SVA-based protocol-violation
checking, a broad negative-test/error-injection library, UVM RAL/register
model integration, or qualification on simulators other than Questa. If
you're evaluating this against a commercial VIP, that's the honest gap —
see the "Design Decisions & Limitations" section in each sub-README.

## Contributing

Found a bug or want to add a feature? Open an issue or send a pull
request. Both VIPs are actively used and maintained.

## License

Licensed under the [Apache License 2.0](./LICENSE) — free to use, modify,
and distribute in commercial and personal projects.

## Contact

**Mikail Demirtaş** — Digital Design & Verification Engineer
[linkedin.com/in/mikail-demirtaş-44engineer](https://www.linkedin.com/in/mikail-demirta%C5%9F-44engineer/)
