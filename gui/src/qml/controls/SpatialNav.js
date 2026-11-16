.pragma library

// Geometric (spatial) focus navigation for controller input.
// Candidates are the items in the window's tab focus chain that are visible, enabled and
// share the nearest "navigation scope" ancestor (an item with `spatialNavScope: true`, or the
// window content item). The best candidate is chosen by direction:
//   left/right: items whose vertical extent overlaps the current item (same visual row);
//   up/down:    items above/below, preferring the ones that overlap horizontally.
// move() returns true when focus moved.

function scopeOf(item) {
    let p = item ? item.parent : null;
    while (p) {
        if (p.spatialNavScope === true)
            return p;
        p = p.parent;
    }
    return null;
}

function usable(item) {
    if (!item || !item.visible || item.enabled === false)
        return false;
    if (item.width <= 0 || item.height <= 0)
        return false;
    // Fully transparent ancestors (fading pages) are not targets.
    for (let p = item; p; p = p.parent) {
        if (p.opacity !== undefined && p.opacity <= 0.01)
            return false;
    }
    return true;
}

function rectOf(item, ref) {
    const p = item.mapToItem(ref, 0, 0);
    return { x: p.x, y: p.y, w: item.width, h: item.height };
}

function candidates(item) {
    const scope = scopeOf(item);
    const out = [];
    let next = item.nextItemInFocusChain(true);
    let guard = 0;
    while (next && next !== item && guard++ < 400) {
        if (usable(next) && scopeOf(next) === scope && !isAncestor(next, item) && !isAncestor(item, next))
            out.push(next);
        next = next.nextItemInFocusChain(true);
    }
    return { scope: scope, items: out };
}

function isAncestor(a, b) {
    for (let p = b ? b.parent : null; p; p = p.parent)
        if (p === a)
            return true;
    return false;
}

function overlap(a0, a1, b0, b1) {
    return Math.min(a1, b1) - Math.max(a0, b0);
}

function best(item, dir) {
    const c = candidates(item);
    const ref = c.scope || (item.Window ? item.Window.contentItem : null) || item.parent;
    if (!ref)
        return null;
    const cur = rectOf(item, ref);
    const cx = cur.x + cur.w / 2, cy = cur.y + cur.h / 2;
    let winner = null, winnerScore = Infinity;
    for (const cand of c.items) {
        const r = rectOf(cand, ref);
        const rx = r.x + r.w / 2, ry = r.y + r.h / 2;
        let score;
        if (dir === "left" || dir === "right") {
            const ov = overlap(cur.y, cur.y + cur.h, r.y, r.y + r.h);
            if (ov < Math.min(cur.h, r.h) * 0.3)
                continue;
            const gap = dir === "right" ? r.x - (cur.x + cur.w) : cur.x - (r.x + r.w);
            if (gap < -Math.min(cur.w, r.w) * 0.5)
                continue;
            score = Math.max(0, gap) + Math.abs(ry - cy) * 2;
        } else {
            const gap = dir === "down" ? r.y - (cur.y + cur.h) : cur.y - (r.y + r.h);
            if (gap < -Math.min(cur.h, r.h) * 0.5)
                continue;
            const ov = overlap(cur.x, cur.x + cur.w, r.x, r.x + r.w);
            // Strongly prefer items in the same column; ties go to the left-most item.
            score = Math.max(0, gap) * 4 + (ov > 0 ? 0 : 2000) + Math.abs(rx - cx) * 0.5 + r.x * 0.001;
        }
        if (score < winnerScore) {
            winner = cand;
            winnerScore = score;
        }
    }
    return winner;
}

function move(item, dir) {
    const target = best(item, dir);
    if (!target)
        return false;
    target.forceActiveFocus(Qt.TabFocusReason);
    return true;
}

// Shared key handler for the custom controls. `horizontal` is false for controls that use
// left/right themselves (sliders, text fields). Returns true when the event was handled.
function handleKey(item, event, horizontal) {
    let dir = "";
    switch (event.key) {
    case Qt.Key_Up: dir = "up"; break;
    case Qt.Key_Down: dir = "down"; break;
    case Qt.Key_Left: dir = horizontal ? "left" : ""; break;
    case Qt.Key_Right: dir = horizontal ? "right" : ""; break;
    }
    if (!dir)
        return false;
    if ((dir === "up" && item.firstInFocusChain) || (dir === "down" && item.lastInFocusChain))
        return false;
    // No item in that direction: stay put (no wrap-around), let the key bubble up.
    return move(item, dir);
}
