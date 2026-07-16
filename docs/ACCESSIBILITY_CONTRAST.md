# FoldLight — Blueprint palette contrast audit

WCAG 2.1 contrast ratios for the blueprint theme tokens, computed against the two
grounds each is actually drawn on: the page ground `graph` and the card fill
`card`. Ratios use the WCAG relative-luminance formula; the semi-transparent
`ink60` token is **alpha-composited over each ground first** (it is `ink` at
0.66 alpha, so its effective color — and its ratio — differs per ground).

Thresholds: normal text **4.5:1** (AA); large/semibold text and non-text UI
(icons, control states, focus indicators) **3:1**. Regenerate with
`scratchpad/contrast.swift` (kept out of the repo) or the values in
`FoldKit/Theme/BlueprintColors.swift`.

## Dark

| Token | Over | Role | Ratio | Result |
|---|---|---|---|---|
| ink (primary text) | graph | body text | 13.90:1 | PASS |
| ink (primary text) | card | body text | 13.09:1 | PASS |
| ink60 (secondary text) | graph | 12–13pt captions | 6.75:1 | PASS |
| ink60 (secondary text) | card | 12–13pt captions | 6.49:1 | PASS |
| crease (accent/link) | graph | semibold ≥14pt | 6.72:1 | PASS |
| crease (accent/link) | card | semibold ≥14pt | 6.33:1 | PASS |
| crane (error accent) | graph | icon/large only | 5.25:1 | PASS |
| crane (error accent) | card | icon/large only | 4.95:1 | PASS |
| sax (gold accent) | graph | icon/large only | 7.38:1 | PASS |
| sax (gold accent) | card | icon/large only | 6.95:1 | PASS |
| up (green accent) | graph | icon/large only | 6.83:1 | PASS |
| up (green accent) | card | icon/large only | 6.43:1 | PASS |

## Light

| Token | Over | Role | Ratio | Result |
|---|---|---|---|---|
| ink (primary text) | graph | body text | 12.84:1 | PASS |
| ink (primary text) | card | body text | 14.73:1 | PASS |
| ink60 (secondary text) | graph | 12–13pt captions | 4.61:1 | PASS |
| ink60 (secondary text) | card | 12–13pt captions | 4.89:1 | PASS |
| crease (accent/link) | graph | semibold ≥14pt | 5.91:1 | PASS |
| crease (accent/link) | card | semibold ≥14pt | 6.78:1 | PASS |
| crane (error accent) | graph | icon/large only | 3.37:1 | PASS |
| crane (error accent) | card | icon/large only | 3.86:1 | PASS |
| sax (gold accent) | graph | icon/large only | 3.38:1 | PASS |
| sax (gold accent) | card | icon/large only | 3.88:1 | PASS |
| up (green accent) | graph | icon/large only | 3.50:1 | PASS |
| up (green accent) | card | icon/large only | 4.01:1 | PASS |

## Notes / fixes

- **`ink60` alpha stays 0.66.** This is the intentional WCAG-AA fix (spec called
  for 0.62); at 0.66, 12–13pt secondary text clears 4.5:1 on both grounds in both
  themes. Not reverted.
- **Light `sax` darkened `#B8860B` → `#A67A0A`.** The original gold measured
  2.84:1 on the light graph ground — below the 3:1 non-text threshold for the
  accent's use as an icon/control-state color (toggles, the on-bulb tint, the
  MAIN badge). The minimal darkening lands at 3.38:1 (graph) / 3.88:1 (card) and
  stays recognizably gold. Dark `sax` is unchanged.
- **`crane` as text.** `crane` is only ever used as an icon/large-accent color or
  paired with `ink` body text for error rows (see `BlueprintActionRow`), never as
  small body text, so its ~3.4:1 light-theme ratio is within policy.
- **Increase Contrast.** Under the system setting,
  `BlueprintColors.resolve(_:contrast:)` raises `ink60` to 0.82 alpha and
  strengthens `creaseLine`, pushing every row further above threshold; the
  standard-contrast 0.66 floor is never lowered.
