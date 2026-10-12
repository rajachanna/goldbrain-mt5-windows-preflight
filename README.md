# GoldBrain: Windows MT5 real-tick preflight

This public repository contains code only, not GoldBrain models or historical prices. The official MT5 terminal runs on GitHub-hosted Windows. The MQL5 read-only exporter requests a bounded ten-minute XAUUSD tick sample from MetaQuotes-Demo. No trades. No raw tick files published.

## One-time demo authorization

MT5 desktop needs a valid MetaQuotes-Demo account. Configure these TWO GitHub Actions repository secrets (do not place values in files or chat):

- MT5_DEMO_LOGIN — your MetaQuotes-Demo account number
- MT5_DEMO_INVESTOR_PASSWORD — investor (read-only) password; never the master trading password

Open Settings > Secrets and variables > Actions > New repository secret, create both secrets, then Actions > MetaQuotes Gold read-only tick preflight > Run workflow. Generate/change investor password in account management if necessary. Never use a live-funded account.

Workflow does not auto-run on pushes; without secrets it stops before terminal installation. The temporary terminal configuration file is deleted after probing; no secret values are logged. Login approval or interactive authentication may still be needed.

MT5 quotes are indicative broker-source historical data, not executable fill guarantees. Separate tick-use rights and OOS quality gates must pass before training.
