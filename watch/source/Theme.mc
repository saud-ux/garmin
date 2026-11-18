import Toybox.Lang;
import Toybox.Graphics;

// Shared colors — smoky vertical gradient (light slate at top, black at bottom).
module Theme {
    // gradient stops
    const BG_TOP      = 0x232B31;
    const BG_MID      = 0x121A1F;
    const BG_BOT      = 0x04060A;
    const BG          = 0x0E161B;   // flat fallback (text background param)

    const FACE        = 0x171E23;   // subtle bezel ring
    const CARD        = 0x1C242A;
    const TXT         = 0xFFFFFF;
    const SUB         = 0xDCE3E7;   // supporting text on notifications
    const MUTED       = 0x93A0A8;   // secondary labels
    const DIM         = 0x7C8890;   // tertiary (team names, score meta)
    const HOME        = 0x34B36A;   // صاحب الأرض (accent green)
    const AWAY        = 0x3B82F6;   // الفريق الضيف (accent blue)
    const AMBER       = 0xF5A623;   // الوقت الإضافي
    const AMBER_DIM   = 0x8A6A2A;   // added-time secondary text
    const RED         = 0xEF4444;   // بطاقة حمراء / تحذير
    const YELLOW      = 0xFACC15;   // بطاقة صفراء
    const TRACK       = 0x2C343A;   // progress ring track (green context)
    const TRACK_AMBER = 0x332612;   // progress ring track (added-time)
    const KEYBG       = 0x222A30;   // number pad key
    const KEY_DONE    = 0x14301E;   // "تم" key
    const KEY_CLEAR   = 0x30191A;   // "مسح" key

    const BANDS = 44;

    // Blend two 0xRRGGBB colors, t in 0.0 .. 1.0
    function mix(a, b, t) {
        var ar = (a >> 16) & 0xFF;
        var ag = (a >> 8) & 0xFF;
        var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF;
        var bgr = (b >> 8) & 0xFF;
        var bb = b & 0xFF;
        var r = ar + ((br - ar) * t).toNumber();
        var g = ag + ((bgr - ag) * t).toNumber();
        var l = ab + ((bb - ab) * t).toNumber();
        return (r << 16) | (g << 8) | l;
    }

    // Paint the full-screen smoky gradient. Replaces dc.clear().
    function fillBg(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bh = (h / BANDS) + 1;
        var last = BANDS - 1;
        for (var i = 0; i < BANDS; i++) {
            var t = i.toFloat() / last.toFloat();
            var c;
            if (t < 0.48) {
                c = mix(BG_TOP, BG_MID, t / 0.48);
            } else {
                c = mix(BG_MID, BG_BOT, (t - 0.48) / 0.52);
            }
            dc.setColor(c, c);
            dc.fillRectangle(0, (i * h) / BANDS, w, bh);
        }
        dc.setColor(TXT, Graphics.COLOR_TRANSPARENT);
    }

    // Kit color id -> hex, matching website COLORS (refined).
    function kit(id) {
        if (id == null) { return 0x888888; }
        if (id.equals("red"))    { return 0xEF4444; }
        if (id.equals("blue"))   { return 0x3B82F6; }
        if (id.equals("yellow")) { return 0xFACC15; }
        if (id.equals("green"))  { return 0x34B36A; }
        if (id.equals("white"))  { return 0xF2F5F3; }
        if (id.equals("black"))  { return 0x2B2B2B; }
        if (id.equals("orange")) { return 0xF08A3C; }
        if (id.equals("purple")) { return 0x8E6BE8; }
        return 0x888888;
    }

    function accent(team) {
        return team.equals("home") ? HOME : AWAY;
    }
}
