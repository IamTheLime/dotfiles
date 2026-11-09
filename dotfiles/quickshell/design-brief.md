# Tray and dock refinement

The desktop owner wants a minimal Tokyo Night palette, consistent icon sizes,
transparent glass, and organic motion. Preserve existing click/hover actions,
Keep awake, the pinned/running ordering, and the appearance of Steam, Telegram
and Handy. Extend hover grace so reaching menus does not require rushing.

Approved direction: custom SVGs for the small known app set, with an editable
app-to-file map and original-icon fallback. Replace colours in SVG source from
the shared theme rather than filtering custom assets. Simplify Discord.

Dock reference: a small lower droplet feeds a larger upper bubble; this grows
wide enough for the icons, then pinches into pinned and running pills. Reverse
on hide. One continuous outline, no layered opacity seams. User rejected the
first expanding-bar motion and inconsistent optical icon sizes. The revision
holds a whole bubble before separating, balances icon bounds, and uses a smooth
contour interpolation with matching native blur regions.

Validation: actual-size desktop screenshots, sampled animation contours,
independent visual critique, and a live QML check for rapid reversal, the final
gap, single-pill state and fully hidden state. Existing shell test suites pass.
Static previews cannot establish whether the motion feels right to the owner.
