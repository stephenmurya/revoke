# Documentation Terminology Scan

Review date: 2026-09-04

## Search performed

A case-insensitive recursive search was run across `project_meta_v2/` for the requested legacy financial, prize, and user-facing penalty vocabulary, including the specified balance-field names. A second pass used word boundaries and phrase boundaries to distinguish real terms from ordinary words that merely contain a short search fragment.

## Classification of remaining raw-search matches

| Location | Classification | Reason |
|---|---|---|
| `archive/prd-v1.3.md:15` | Historical quote/reference | Preserved v1.3 product intent; archive is explicitly non-canonical. |
| `archive/prd-v1.3.md:307` | Historical quote/reference | Preserved legacy field example for migration context; it is not a v2 field. |
| `archive/status-pre-v2.md:24` | Historical quote/reference | Preserved pre-v2 status material; archive is not current product guidance. |
| `archive/curbox-assessment.md:13` | Not a terminology match | The raw fragment occurs inside an ordinary English word; no prohibited domain term is present. |
| `audits/2026-09-04-revival-audit.md:317` | Not a terminology match | The raw fragment occurs inside an ordinary English word; the dated audit is unchanged implementation evidence. |

There were no policy-discussion matches that needed to retain prohibited vocabulary, and no accidental canonical usages after the correction pass. The remaining actual matches are historical archive references only. No equivalent legacy balance identifier appears in current canonical or review text.

## Replacements recorded

The correction pass replaced legacy financial/prize vocabulary and legacy balance/event examples with:

- Commitment Credits, available Credits, locked Credits, Credit lock, Credit release, and Credit forfeiture;
- `available_credits`, `locked_credits`, and `credit_holds`; and
- `CREDIT_PURCHASE`, `CREDIT_LOCK`, `CREDIT_RELEASE`, `CREDIT_FORFEITURE`, `PREMIUM_REDEMPTION`, and `PURCHASE_REVERSAL`.

The offline behavior is defined in `architecture/commitment-verification.md` and `decisions/004-credit-forfeiture-fail-safe.md`. The accepted wipe/reinstall-before-sync risk is defined in both of those documents. The 24-hour resolution policy is defined in `architecture/commitment-verification.md` and decision 004. The mandatory every-purchase disclosure is defined in `product/monetization.md`, `architecture/credit-ledger-and-billing.md`, and decision 011.

Previous documentation still contains legacy vocabulary only in the intentionally preserved v1.3 and pre-v2 archive files listed above. The current canonical corpus and review packet do not contain accidental occurrences.
