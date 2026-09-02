# Thermal Receipt Template — Design

**Date:** 2026-08-24
**Target printer:** Xprinter XP-P323B (80 mm roll, 72 mm printable, 203 dpi, 70 mm/s, ESC/POS)
**Decision:** Template B — "Delivery Invoice" (فاتورة تسليم), applied to all three document types.
**Visual proof:** https://claude.ai/code/artifact/f369a2b5-d4df-47b8-8b3b-bb46a4227312
**Item table (decided 2026-09-02):** Column template A — "Boxed grid" (جدول مغلق), see §5.1.
**Column proof:** https://claude.ai/code/artifact/a48607af-0929-4501-a557-2c056b34f64d

---

## 1. Why

The receipt renders correctly on screen and degrades on paper. Four defects, all in
`lib/features/receipts/screens/receipt_screen.dart` and
`lib/features/printing/services/print_service.dart`:

### 1.1 Dividers print as blank paper (critical)

`_DashedDivider` is painted with `_dash = AppColorsLight.borderStrong` = `#D6D3D1`.
`_pngToEscPos` keeps a pixel only when its luminance is below 128:

```
0.299×214 + 0.587×211 + 0.114×209 = 211.7   →   211.7 > 128   →   discarded
```

Every separator on every receipt is dropped. On paper the document is one
undivided block of text.

### 1.2 The three-tone text hierarchy collapses (critical)

`_ink` (#1C1917 → 25.7), `_dim` (#57534E → 83.6) and `_faint` (#78716C → 114.5) all
fall below the threshold and print as identical solid black. The hierarchy the
design depends on exists only in the preview.

### 1.3 The bitmap is downscaled by point-sampling

The paper is constrained to `maxWidth: 300` and captured at `pixelRatio: 3.0`,
producing a 900-dot image that `_pngToEscPos` squeezes to 576 via nearest-neighbour
lookup (`(px / scale).toInt()`) with no area averaging. Thin strokes and Arabic
diacritics fall between sample points and disappear.

### 1.4 Stale width assumptions

Comments describe a "58mm thermal preview" (`receipt_screen.dart:31`, `:599`) while
`print_service.dart:138` correctly targets 576 dots (72 mm). The converter is right;
the comments are wrong, and the 300-px preview is narrower than the paper allows.

---

## 2. Printer facts these decisions rest on

| Property | Value |
|---|---|
| Paper width | 80 mm |
| Printable width | 72 mm = **576 dots** |
| Resolution | 203 dpi = **8 dots/mm** |
| Print speed | 70 mm/s |
| Colour depth | **1 bit** — a dot is burned or it is not |

Consequences: no greys, no anti-aliasing survives thresholding, and paper length
translates directly to time and cost (`mm = dots ÷ 8`, `seconds = mm ÷ 70`).

---

## 3. Design rules

1. **One ink.** Every mark on the paper is `#000000` on `#FFFFFF`. No intermediate
   value may appear, because the threshold will resolve it unpredictably.
2. **Hierarchy without colour.** Emphasis comes from weight (400/600/700), size,
   rules, boxes, and inversion.
3. **Rules are 3 dots thick.** A 1-dot line survives only if it lands cleanly on a
   sample row. 3 dots always survives.
4. **One inverted block per receipt, maximum.** Solid black bars read as
   authoritative but drain a battery printer and fade toward the end of a roll.
   Template B spends its single block on the total.
5. **Body text is 22 dots (2.75 mm).** Just above ESC/POS Font A. Below ~18 dots,
   Arabic diacritics close up on thermal paper.
6. **Numbers stay bidi-isolated and tabular.** The existing `_n()` helper
   (U+2066 … U+2069) is kept; without it the minus sign on a discount jumps ends.

---

## 4. Architecture

### 4.1 Exact-resolution capture

The printed bitmap must be 576 dots wide with no resampling.

- `ReceiptPaper` declares a **fixed intrinsic width of 288 logical px**.
- The `RepaintBoundary` wraps it and is captured at `pixelRatio: 2.0` → exactly
  **576 dots**, resample factor 1.0.
- `RenderRepaintBoundary.toImage` renders the boundary's own layer subtree, so
  ancestor transforms are excluded from the capture. The preview may therefore
  scale the widget freely without affecting what prints.
- 288 logical px fits every phone at ≥320 dp, so the preview renders it at natural
  size. `FittedBox(fit: BoxFit.fitWidth)` is the fallback for unusually narrow
  viewports only.
- The paper subtree is wrapped in
  `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling))`.
  Without this, a device with large-text accessibility settings prints a broken
  layout.

### 4.2 Print service

- Skip the resample loop entirely when source width is already 576.
- Replace the nearest-neighbour fallback with a **box-filter average** so an
  unexpected capture size degrades gracefully instead of shattering thin strokes.
- Keep the `GS v 0` raster path; it is correct.

### 4.3 Thermal primitives

New `lib/features/receipts/widgets/thermal.dart`:

- `ThermalInk` — `black` / `paper`. The only two colours permitted on the paper.
- `Dots` — dot-denominated sizing. `Dots.px(22) → 11.0`, since 1 logical px = 2 dots
  at the capture ratio. Layout code then reads directly against the 576-dot grid.
- Widgets: `ThermalRule` (solid 3-dot / hair 2-dot / dashed 9-on-7),
  `ThermalKv`, `ThermalGrid` (the boxed item table of §5.1, built on Flutter's
  `Table` with `TableBorder` so vertical rules are real cell borders, not painted
  overlays), `TotalBar` (inverted), `Stamp`, `SignatureLine`.
  No `TearLine` — template C is not being built (§8), so it would be dead code.

### 4.4 File split

`receipt_screen.dart` is 1003 lines, over the project's 500-line limit.

| File | Contents |
|---|---|
| `widgets/thermal.dart` | palette, `Dots`, primitives |
| `widgets/receipt_paper.dart` | `ReceiptPaper` + the three document bodies |
| `screens/receipt_screen.dart` | screen chrome, print/cancel/mark-paid actions |

### 4.5 Company header data

`stores.phone` is the **store's** number, not the business's. The header and footer
lines read from the existing `app_config` key/value table (scoped by `businessId`):

- `receipt.phone` — shown under the company name and in the footer
- `receipt.footer` — replaces the hardcoded `شكراً لثقتكم` when set

Both lines are omitted when unset. No schema migration.

---

## 5. Template B — layout

Order receipt, top to bottom:

1. Company name (34 dots, bold, centred) + `receipt.phone` line
2. 3-dot rule
3. Document type `فاتورة تسليم` (24 dots) and order number (40 dots, `#1847`)
4. 2-dot rule
5. Metadata block: date, store name (23 dots bold), address, driver
6. **Boxed 4-column item table** — `الصنف` / `الكمية` / `السعر` / `الإجمالي`,
   fully ruled (§5.1)
7. Subtotal, tax, discount (each conditional, as today) — rendered as footer rows
   *inside* the boxed table frame, label spanning the first three columns
8. **Inverted total bar** — white on black, the single solid block
9. Payment-status stamp (4-dot box): `مدفوع` / `مدفوع جزئياً` / `غير مدفوع`
10. Paid and, when partial, a boxed `المتبقي`
11. Package balance (`العبوات المتبقية لدى المتجر`)
12. Two signature lines — recipient and driver
13. 3-dot rule, footer

Cancelled orders keep the existing prominent `ملغى` treatment above the table.

### 5.1 Item table — column template A, "Boxed grid"

Chosen over B (open columns), C (split rows) and D (five-column piece ledger) on
2026-09-02. Every cell is ruled, like a carbon-copy invoice book.

**Geometry** (table spans the full 536-dot content width; 20-dot paper margins each side):

| Column | Header | Width | Align |
|---|---|---|---|
| Name | `الصنف` | 236 dots | start (right) |
| Quantity | `الكمية` | 84 dots | centre |
| Price | `السعر` | 96 dots | centre |
| Total | `الإجمالي` | 120 dots | end (left) |

- Outer frame 3 dots; header bottom rule 3 dots; all inner rules 2 dots.
- Cell padding 6 dots vertical, 5 dots horizontal.
- Header text 19 dots bold. Body 21 dots. Name 23 dots semibold, line-height 1.25.
  Sub-lines 17 dots regular.

**Cell contents per order line** (`quantity` = packages, `pieces_quantity` = loose
pieces, `unit_price` = package price, `products.units_per_package` = pieces per package):

| Cell | Packages only | Packages + pieces | Pieces only |
|---|---|---|---|
| Name | name, sub-line `12 ق/ع` | same | same |
| Quantity | `6 ع` | `4 ع`, second line `+6 ق` | `10 ق` |
| Price | `240` | `480`, second line `20/ق` | `15`, second line `للقطعة` |
| Total | `1 440` | `2 040` | `150` |

- Piece price = `unit_price ÷ units_per_package`, rounded to whole dinars with
  `Money.format` (no decimals; figure-space grouping). Shown only when pieces > 0.
- The `ق/ع` sub-line is omitted when `units_per_package` is null.
- Unit letters `ع` / `ق` are rendered at 17 dots, medium weight, after the number.
- Every number is wrapped by `_n()` (U+2066 … U+2069) so it stays LTR inside the
  RTL cell.
- Footer rows inside the frame: `المجموع الفرعي` always; `الضريبة` when tax > 0;
  `الخصم` with a leading `−` when the discount is shown (same conditions as today).
  Footer label cells span columns 1–3; the amount sits in the total column, bold.
- A name that does not fit 236 dots wraps to a second line; the row grows. Nothing
  is truncated or scaled.

Measured on the proof with the four-line sample order: 163 mm of paper, 2.3 s at
70 mm/s. Roughly 8 mm per additional single-line item.

**Load manifest and return documents** reuse `ThermalGrid` with the same rule
weights: 3 columns (`الصنف` 316 / `الكمية` 100 / `—` 120) for the manifest and
4 columns (`الصنف` 236 / `محمّل` 100 / `مباع` 100 / `مرتجع` 100) for the return.

**Load manifest** and **return / shift-close** reuse the same primitives: header,
metadata block, ruled table (3-column for the manifest, 4-column for the return
comparison), totals row. They inherit every fix in §1 by construction.

---

## 6. Error handling

Unchanged in shape, corrected in detail:

- Capture returning `null` and conversion returning an empty list already surface as
  a failed print with a retry action. Keep.
- Add a debug-mode assertion that the captured width is 576; a mismatch means the
  paper's fixed width or the pixel ratio was changed without updating the other.
- Print remains blocked while `discount_status == 'pending'`.

---

## 7. Testing

No golden tests exist in the repo today.

1. **`test/widget/receipts/receipt_palette_test.dart`** — the regression guard for
   §1.1 and §1.2. Walk the rendered element tree of `ReceiptPaper` for each document
   type and assert that every colour it *declares* — `TextStyle.color`,
   `BoxDecoration.color`, `Border` sides, `CustomPainter` paints — is either
   `ThermalInk.black` or `ThermalInk.paper`. Any grey reintroduced into the paper
   fails the suite.

   > Asserting on captured *pixels* instead would not work: Flutter anti-aliases
   > glyph edges, so a correct receipt legitimately contains intermediate
   > luminances. The defect is in the declared colours, so that is what the test
   > inspects.

2. **`test/widget/receipts/receipt_capture_test.dart`** — render each document type,
   capture through `PrintService.captureWidget` at `pixelRatio: 2.0`, assert the
   decoded width is exactly **576**, and assert that the horizontal band occupied by
   a `ThermalRule` contains black pixels after the 128 threshold — i.e. the rule
   actually prints.
3. **`test/unit/features/printing/esc_pos_test.dart`** — assert the `GS v 0` header
   (`0x1D 0x76 0x30 0x00`), that `xL/xH` encode 72 bytes per row, and that
   `yL/yH` match the image height.
4. Existing `line_item_test.dart` and `package_stock_test.dart` must stay green.

---

## 8. Rejected

- **Template A (Compact)** — shortest paper, but no item table, no package/unit
  breakdown and no signature. Wrong for credit accounts.
- **Template C (Invoice + driver stub)** — the tear-off stub is genuinely useful for
  end-of-shift reconciliation, but costs the most paper. Revisit if driver
  settlement disputes become a real problem; template B's primitives already
  contain everything the stub needs.
- **Code 128 barcode** — would need a rendering package. Dropped in favour of the
  large order numeral, which is what people read out over the phone.
- **ESC/POS text-mode printing** — faster and shorter than raster, but Arabic
  shaping and RTL are unreliable across code pages. Raster capture stays.
- **Tax/VAT and commercial-register lines** — not required for this business.
