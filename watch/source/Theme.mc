import Toybox.Lang;
import Toybox.Graphics;

// Shared colors — refined premium palette.
module Theme {
    const BG          = 0x000000;
    const FACE        = 0x0A0D0B;   // subtle bezel ring
    const CARD        = 0x0F1A13;
    const TXT         = 0xFFFFFF;
    const SUB         = 0xCFD4CF;   // supporting text on notifications
    const MUTED       = 0x6B746D;   // secondary labels
    const DIM         = 0x5F685F;   // tertiary (team names, score meta)
    const HOME        = 0x34B36A;   // صاحب الأرض (accent green)
    const AWAY        = 0x3B82F6;   // الفريق الضيف (accent blue)
    const AMBER       = 0xF5A623;   // الوقت الإضافي
    const AMBER_DIM   = 0x8A6A2A;   // added-time secondary text
    const RED         = 0xEF4444;   // بطاقة حمراء / تحذير
    const YELLOW      = 0xFACC15;   // بطاقة صفراء
    const TRACK       = 0x141A16;   // progress ring track (green context)
    const TRACK_AMBER = 0x231A0C;   // progress ring track (added-time)
    const KEYBG       = 0x141A16;   // number pad key
    const KEY_DONE    = 0x102418;   // "تم" key
    const KEY_CLEAR   = 0x1A1414;   // "مسح" key

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
