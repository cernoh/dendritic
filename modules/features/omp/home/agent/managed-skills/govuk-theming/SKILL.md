---
name: govuk-theming
description: "Style web apps with the GOV.UK Design System (govuk-frontend): colour/type/spacing tokens, page template, component classes, patterns, and unofficial-service rules. Trawl of design-system.service.gov.uk, 2026-09."
---

# GOV.UK theming with govuk-frontend

Grounds in the GOV.UK Design System as trawled 2026-09-07 (components/, patterns/, styles/). Build with **govuk-frontend 6.x** CSS/JS; markup below matches v6. Verify against your installed version when values differ.

## Sources of truth
- Components: https://design-system.service.gov.uk/components/ (37 official components, incl. Tabs, Service navigation, Generic header, Feedback)
- Patterns: https://design-system.service.gov.uk/patterns/
- Styles: https://design-system.service.gov.uk/styles/ (colour, type-scale, headings, paragraphs, links, lists, layout, spacing, images incl. icons, page-template, section-break)
- Frontend package: https://www.npmjs.com/package/govuk-frontend (dist layout: CSS `dist/govuk/govuk-frontend.min.css`, JS `dist/govuk/govuk-frontend.min.js`, assets under `dist/govuk/assets/…`)

## Unofficial services (your own brand, not GOV.UK)
- Never use the Crown crest/crown copyright logos; no `GOV.UK` wordmark. govuk-frontend offers **Generic header** (`govuk-generic-header`, custom `logoHtml`, no crown) or a plain `govuk-header` containing only your logo/service name.
- Say so in a phase-banner-style strip: e.g. tag `Independent` + "Not affiliated with …". Do not claim to be a government service.
- Footer: skip `© Crown copyright`; keep OGL-style licence text only if it applies. `govuk-footer__licence-logo` SVG can be dropped for unofficial builds.
- Palette remains fine to use (colours themselves aren't Crown-restricted), but avoid exact GOV.UK masthead layout if confusing.

## Page skeleton (order + exact classes)
1. `<html lang="en" class="govuk-template">`; `<head>`: charset, viewport, `theme-color #1d70b8` meta, `govuk-frontend.min.css`, favicon.
2. `<body class="govuk-template__body">` + support script adding `js-enabled` and (if supported) `govuk-frontend-supported` to body class.
3. `<a href="#main-content" class="govuk-skip-link" data-module="govuk-skip-link">Skip to main content</a>` (first thing in body; never inside a nav/header landmark).
4. `<header class="govuk-header">` → `.govuk-header__container.govuk-width-container` → `.govuk-header__logo` → link. Then Service navigation and/or Phase banner (below header, inside `govuk-width-container`).
5. `<div class="govuk-width-container">` → optional `govuk-back-link` / `govuk-breadcrumbs` / `govuk-phase-banner` → `<main class="govuk-main-wrapper" id="main-content">`. If no pre-main element: `govuk-main-wrapper--auto-spacing` (fallback `--l`).
6. `<footer class="govuk-footer">` → `.govuk-width-container` → meta/licence rows.
7. End of body: `govuk-frontend.min.js` + `GOVUKFrontend.initAll()` (v5+ has NO auto-init; without initAll, accordion/tabs/error-summary/header toggles/buttons don't behave).
No-JS fallback: every JS component degrades to fully readable stacked content by default — keep that property.

## Styles
### Functional palette (govuk-frontend 6, from /styles/colour)
Text `#0b0c0c`; secondary text `#484949`; inverse text `#ffffff`; link `#1a65a6`; link-hover `#0f385c`; link-visited `#54319f`; link-active `#0b0c0c`; border `#cecece`; input border `#0b0c0c`; background `#ffffff`; page template background `#f4f8fb`; focus `#ffdd00` (focus only); error `#ca3535`; success `#0f7a52`; hover `#cecece`; brand `#1d70b8`.
Legacy v5 tokens you will meet in older code: text `#0b0c0c`, secondary `#505a5f`, link `#1d70b8`, visited `#4c2c92`, border `#b1b4b6`, error `#d4351c`, success `#00703c`, focus `#ffdd00`.
Extended groups (primary, tint-25/50/80/95, shade-25/50): blue `#1d70b8`…; green `#0f7a52`; teal `#158187`; purple `#54319f`; magenta `#ca357c`; red `#ca3535`; orange `#f47738`; yellow `#ffdd00`; black `#0b0c0c`; white `#ffffff`. Sass: `govuk-colour("blue")`, `govuk-functional-colour("link")` — never hard-code hex in Sass builds.
Contrast: text/interactive must meet WCAG 2.2 AA; don't invent colour meanings or restyle buttons/inputs; focus state must stay `#ffdd00` outline-style.

### Type scale (v6; 16/19 fixed across screens)
| Point | Classes | Large (>640px) | Small (≤640px) |
|---|---|---|---|
| 80 | exceptional | 80/lh80 | 53/lh55 |
| 48 | `govuk-heading-xl` | 48/50 | 32/35 |
| 36 | `govuk-heading-l` | 36/40 | 27/30 |
| 24 | `govuk-heading-m`, `govuk-body-l` | 24/30 | 21/25 |
| 19 | `govuk-heading-s`, `govuk-body` | 19/25 | 19/25 |
| 16 | `govuk-body-s` | 16/20 | 16/20 |
Headings bold, body regular (frontend compiles 700/400). Sentence case headings; default hierarchy h1→`--l`, h2→`--m`, h3→`--s`; long-form content h1→`--xl`. Captions `govuk-caption-xl|l|m` sit above/nested in the heading. Overrides: `govuk-!-font-size-80|48|36|27|24|19|16`, `govuk-!-font-weight-regular|bold`, `govuk-!-font-tabular-numbers`, `govuk-!-text-break-word`, `govuk-!-text-align-left|right|centre`.

### Links
Base `govuk-link`; variants `govuk-link--no-visited-state` (dashboards), `govuk-link--inverse` (on dark, keep ≥4.5:1), `govuk-link--no-underline` only where context already signals a link. Always underline links by default; linked text excludes the trailing full stop. No external-link icons; avoid new tabs — if used, say "opens in new tab" in text and add `rel="noreferrer noopener"`; don't announce "external".

### Spacing & layout
Spacing units (px): 0→0, 1→5, 2→10, 3→15, 4→15/20, 5→15/25, 6→20/30, 7→25/40, 8→30/50, 9→40/60 (small/large screens; units 4+ scale). Classes: `govuk-!-margin-<n>` / `govuk-!-padding-<n>` + `-top|-right|-bottom|-left`; static `govuk-!-static-margin-…`. Sass: `govuk-responsive-margin(6, "bottom")`, static `govuk-spacing(6)`.
Layout: default max page width **1020px** (`govuk-width-container`); grid `govuk-grid-row` + `govuk-grid-column-full|one-half|one-third|two-thirds|one-quarter|three-quarters` (+ `-from-desktop` variants; keep main content in two-thirds even alone). Widths: `govuk-!-width-full|three-quarters|two-thirds|one-half|one-third|one-quarter`. Display: `govuk-!-display-block|inline|inline-block|none`; screen-reader-only `govuk-visually-hidden`, `govuk-visually-hidden-focusable`. Breakpoint: large-screen styles apply >640px (styles pages name 640; verify desktop-specific in your build).

## Components cheat-sheet (exact classes)
**Chrome:** skip link `govuk-skip-link`; back link `govuk-back-link` (+`--inverse`, no data-module, above main); breadcrumbs `govuk-breadcrumbs` (`aria-label="Breadcrumb"`, `ol.govuk-breadcrumbs__list` > `li.govuk-breadcrumbs__list-item` > `a.govuk-breadcrumbs__link`, final item no href; `--collapse-on-mobile`, `--inverse`); phase banner `govuk-phase-banner` > `p.govuk-phase-banner__content` > `strong.govuk-tag.govuk-phase-banner__content__tag` (Alpha/Beta) + `span.govuk-phase-banner__text`; header `govuk-header__container`/`__logo`/`__logotype`; **service navigation** `govuk-service-navigation` (`data-module`, `ul.govuk-service-navigation__list`, current `li--active` + link `aria-current="true"`); footer `govuk-footer__meta`, `__meta-item--grow`, `__inline-list`, `__licence-description`, `__copyright-logo`; notification banner `govuk-notification-banner` (`role="region"`, `aria-labelledby` title id, `--success` → `role="alert"`; place above h1, max one).

**Buttons (action component):** `govuk-button` default (green) is the one primary CTA per page; variants `govuk-button--secondary`, `--warning`, `--inverse` (dark backgrounds), `--start` (start-page only, anchor + arrow SVG `govuk-button__start-icon aria-hidden focusable=false`). Link-styled-as-button requires `role="button" draggable="false" data-module="govuk-button"`. Buttons (not anchors) need `type="submit|button"`. `disabled` sets `disabled` + `aria-disabled`. Group with `div.govuk-button-group` (secondary links inside groups are plain `govuk-link`, not button-styled). `data-prevent-double-click="true"` for submits. Sentence-case action text, e.g. "Save and continue", never "Next".
Tabs-as-buttons pattern (used in the WFInfo dashboard): row of link-buttons with exactly one primary — current page `class="govuk-button" aria-current="page"`, others `govuk-button govuk-button--secondary`; wrap in `div.wf-tabs` flex CSS. (Official alternative: **Tabs** component, below.)

**Tabs (official component):** `div.govuk-tabs[data-module=govuk-tabs]` > `h2.govuk-tabs__title` ("Contents") + `ul.govuk-tabs__list` > `li.govuk-tabs__list-item[--selected]` > `a.govuk-tabs__tab[href=#panel]`, panels `div.govuk-tabs__panel[id]`, hidden panels `govuk-tabs__panel--hidden`. Without JS/on small screens all panels stack; current tab goes in the URL fragment. Use for repeat users switching between few clear sections; not for linear reading, comparison across sections, or as page navigation. vs Accordion (many sections, vertical, `data-module="govuk-accordion"`, unique wrapper id, headings get wrapped in runtime `<button>` so keep phrasing content only) vs Details (`<details class="govuk-details">`, one short block, no JS).

**Tables:** `table.govuk-table` — **`caption.govuk-table__caption[--s|--m|--l|--xl]` MUST be the first child of the table**; `thead.govuk-table__head` + `th.govuk-table__header scope="col"`; row heads `th.govuk-table__header scope="row"`; numeric cells add `--numeric` to th/td (right-aligned, tabular). Don't use tables for layout.

**Content blocks:** inset `govuk-inset-text` (don't use for vital info); warning `govuk-warning-text` (`span.govuk-warning-text__icon aria-hidden` "!" + `strong.govuk-warning-text__text` with `span.govuk-visually-hidden` fallback); panel `govuk-panel--confirmation|--interruption` (h1 `govuk-panel__title`, `__body`; interruption actions are `govuk-button--inverse`); summary list `dl.govuk-summary-list` (`__row`,`__key`,`__value`,`__actions` w/ Change links + `govuk-visually-hidden` qualifier; card variant `govuk-summary-card`); details (above); tag `strong.govuk-tag[--grey|--green|--teal|--blue|--red|--yellow|--pink|--orange|--purple]` (status adjectives only, never interactive, never colour alone); task list `ul.govuk-task-list` (`li.govuk-task-list__item[--with-link]`, `__name-and-hint`, `__link[aria-describedby=status(+hint)]`, `__hint`, `__status` — plain text "Completed"/`strong.govuk-tag--blue` "Incomplete"); pagination `nav.govuk-pagination[aria-label]` (`li.govuk-pagination__item[--current][aria-current=page]`, `--ellipsis`, prev/next `a rel="prev|next"` with `span.govuk-pagination__link-title` + `span.govuk-visually-hidden` " page"); character count `govuk-form-group.govuk-character-count[data-module][data-maxlength|data-maxwords]` + `textarea.govuk-textarea.govuk-js-character-count` + `div.govuk-hint.govuk-character-count__message` (message id first in `aria-describedby`); exit this page `govuk-exit-this-page[data-module]` (+ `govuk-js-exit-this-page-button`, `rel="nofollow noreferrer"`, hidden "Emergency" prefix).

**Forms (pattern):** wrapper `div.govuk-form-group` (+`--error`); label `label.govuk-label` (+`govuk-label--s|--m|--l`; label-as-page-heading: `h1.govuk-label-wrapper` > label `govuk-label--l`); hint `div.govuk-hint` (single sentence, no full stop, no links); input `govuk-input` (widths `govuk-input--width-2…20` fixed; prefix/suffix `govuk-input__wrapper` + `__prefix|__suffix aria-hidden`; `spellcheck=false`, `inputmode`, `autocomplete` as needed); textarea `govuk-textarea` rows=5; select `govuk-select` (last resort); checkboxes `govuk-checkboxes` (`__item`,`__input`,`__label`,`__hint`,`__divider` "or", `__conditional--hidden` w/ `data-aria-controls`, exclusive `data-behaviour="exclusive"`, `data-module="govuk-checkboxes"`); radios `govuk-radios` (`--inline` only for 2 short options, `--small`, same structure; `data-module="govuk-radios"` needed for conditionals); date input `govuk-date-input` in `fieldset[role=group]` (`__item`,`__label`,`__input govuk-input--width-2|4`, `inputmode="numeric"`); password `govuk-password-input[data-module]` wrapper + toggle button `govuk-button--secondary.govuk-js-password-input-toggle` (`aria-controls`, `aria-label="Show password"`, `hidden`); error message `p.govuk-error-message` with `span.govuk-visually-hidden` "Error:" + input `govuk-input--error` + group `--error` + id appended to `aria-describedby`. Every input needs matching label `for`↔`id`; `aria-describedby` lists hint then error ids.
Error summary: top of `main`: `div.govuk-error-summary[data-module]` > inner `div[role=alert]` > `h2.govuk-error-summary__title` ("There is a problem") + `ul.govuk-error-summary__list` links `href="#field-id"`. Form `novalidate` (no HTML5 validation, no `required`).

**Cookie banner / misc:** `govuk-cookie-banner[data-nosnippet][role=region][aria-label]`; skip-link/support; fieldset legends `govuk-fieldset__legend--s|--m|--l` (+ `h1.govuk-fieldset__heading` when page heading); file upload `govuk-file-upload`; accordion as above.

## Patterns digest
- **One H1 per page**; never repeat H1 text across pages. Single-question pages: label/legend IS the H1 (`isPageHeading`). Page `<title>` mirrors content: error pages exactly `Page not found – <service> – GOV.UK` / `Sorry, there is a problem with the service – <service> – GOV.UK` / `Sorry, the service is unavailable – <service> – GOV.UK`; validation adds `Error: ` prefix and focuses the error summary.
- Question pages: back link + H1 + optional short hint + Continue button (left aligned). Progress: `govuk-caption-l` "Question 3 of 9"; never horizontal step bars.
- Error pages (404/500/503): no breadcrumbs, no red, no jargon (no "404"/"oops"/"maintenance"); say what happened to saved answers; include contact route.
- Confirmation pages: green `govuk-panel--confirmation` only here + "What happens next"; no links inside the green panel.
- Check answers: grouped `govuk-summary-list` + "Accept and send"-style submit.
- Cookies page: category tables + radios (default No) + success notification banner; footer link.
- There is **no official Filters pattern/component** (MOJ/community owns filtering).
- Feedback component (Trial): `govuk-feedback` before footer.
- Statuses: `Completed` plain black text; `In progress`/`Incomplete` tags; red tag only for real errors.

## Accessibility quick rules
- Everything interactive: visible text is the accessible name (no separate sr-only labels duplicating a visible H1).
- Focus: `#ffdd00` 3px style from frontend; don't remove.
- Don't rely on colour alone (error red + icon/border, tag + text, warning icon + text).
- Caption-first-child rule on tables; `scope` on all `th`; numeric columns `--numeric`.
- Tables/task lists/summary lists: choose by data shape (tabular data → table; key/value → summary list; plain lists → ul/ol).
- Alt text: always present; decorative → `alt=""`; ≤2 sentences, no "Image of…".

## Serving/verification notes
- Plain HTML pages can drop in `govuk-frontend.min.css` + `govuk-frontend.min.js` + `initAll()` and use only classes above (no Sass needed).
- Sass: `@include govuk-font($size: 19)`, `govuk-responsive-margin(6, "bottom")`, `govuk-colour("blue")`.
- Deno + Nix offline gates: see the `deno-govuk-frontend-assets` skill (asset mirroring from unpkg, cache env overrides, offline `nix flake check` unit-test rule).
- Bespoke CSS: prefix classes with a repo/app id (e.g. `wf-`, `fpl-`) so they never collide with `govuk-*`.
