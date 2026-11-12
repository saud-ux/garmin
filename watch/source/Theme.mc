import Toybox.Lang;
import Toybox.Graphics;

// Shared colors, matching the website / spec.
module Theme {
    const BG      = 0x000000;
    const CARD    = 0x1A1F1B;
    const TXT     = 0xE8ECE9;
    const MUTED   = 0x687068;
    const HOME    = 0x4E7A4E;   // صاحب الأرض (accent)
    const AWAY    = 0x4A88C8;   // الفريق الضيف (accent)
    const AMBER   = 0xD4982A;   // الوقت الإضافي
    const RED     = 0xC84A4A;   // بطاقة حمراء / تحذير
    const YELLOW  = 0xE0C040;   // بطاقة صفراء
    const KEYBG   = 0x3A403B;

    // Kit color id -> hex, matching website COLORS.
    function kit(id) {
        if (id == null) { return 0x888888; }
        if (id.equals("red"))    { return 0xE5484D; }
        if (id.equals("blue"))   { return 0x3E8EF7; }
        if (id.equals("yellow")) { return 0xF5D442; }
        if (id.equals("green"))  { return 0x2FA866; }
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
