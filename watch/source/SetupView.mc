import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;

// Kickoff screen: two side-by-side team cards. The chosen team shows a ball
// icon + colored border. Long names wrap to two lines.
class SetupView extends WatchUi.View {

    var homeName, homeColor, awayName, awayColor, halfLen, brkLen, matchId;
    var kickoffSel;
    var homeBox, awayBox, startBox;

    function initialize() {
        View.initialize();
        homeName = "الأرض";  homeColor = "green";
        awayName = "الضيف";  awayColor = "blue";
        halfLen = 45; brkLen = 15; matchId = null;
        kickoffSel = "home";
        homeBox = [0,0,0,0]; awayBox = [0,0,0,0]; startBox = [0,0,0,0];
    }

    function preload(m) {
        homeName  = m["homeName"];
        homeColor = m["homeColor"];
        awayName  = m["awayName"];
        awayColor = m["awayColor"];
        halfLen   = m["halfLen"];
        brkLen    = m["brkLen"];
        matchId   = m["id"];
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.TXT, Theme.BG);
        dc.clear();

        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_XTINY, "ركلة البداية لمن؟",
            Graphics.TEXT_JUSTIFY_CENTER);

        var cardW = (w * 0.36).toNumber();
        var cardH = (h * 0.33).toNumber();
        var gap = (w * 0.05).toNumber();
        var totalW = cardW * 2 + gap;
        var sx = (w - totalW) / 2;
        var cardY = (h * 0.22).toNumber();

        // home on the right, away on the left (RTL)
        homeBox = [sx + cardW + gap, cardY, cardW, cardH];
        drawTeamCard(dc, homeBox, homeName, homeColor, Theme.HOME, kickoffSel.equals("home"));
        awayBox = [sx, cardY, cardW, cardH];
        drawTeamCard(dc, awayBox, awayName, awayColor, Theme.AWAY, kickoffSel.equals("away"));

        // start button
        var bw = (w * 0.42).toNumber();
        var bh = (h * 0.13).toNumber();
        var bx = cx - bw / 2;
        var by = cardY + cardH + (h * 0.05).toNumber();
        startBox = [bx, by, bw, bh];
        dc.setColor(0x102418, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 14);
        dc.setColor(Theme.HOME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh / 2, Graphics.FONT_MEDIUM, "ابدأ",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh + (h * 0.045), Graphics.FONT_XTINY, "الثاني للفريق الآخر",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawTeamCard(dc, box, name, kitId, accent, selected) {
        var x = box[0]; var y = box[1]; var bw = box[2]; var bh = box[3];
        var cx = x + bw / 2;

        dc.setColor(selected ? 0x10140f : 0x0B0D0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, 12);
        if (selected) {
            dc.setPenWidth(2);
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, bw, bh, 12);
            dc.setPenWidth(1);
        }

        // icon: a "ball" (white ring) on the chosen team, else a kit-color dot
        var iconY = y + (bh * 0.28);
        if (selected) {
            dc.setPenWidth(2);
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, iconY, 9);
            dc.setPenWidth(1);
        } else {
            dc.setColor(Theme.kit(kitId), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, iconY, 6);
        }

        drawWrappedName(dc, cx, y + (bh * 0.64), bw - 12, name,
            selected ? Theme.TXT : Theme.MUTED);
    }

    // Draw a team name centered, wrapping to two lines if it is too wide.
    function drawWrappedName(dc, cx, baseY, maxW, name, color) {
        var font = Graphics.FONT_TINY;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var tw = dc.getTextWidthInPixels(name, font);
        if (tw <= maxW) {
            dc.drawText(cx, baseY, font, name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var sp = name.find(" ");
        if (sp == null) {
            dc.drawText(cx, baseY, font, name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var line1 = name.substring(0, sp);
        var line2 = name.substring(sp + 1, name.length());
        var lh = dc.getFontHeight(font);
        dc.drawText(cx, baseY - (lh * 0.42), font, line1,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, baseY + (lh * 0.42), font, line2,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function startMatch() {
        var cfg = {
            "homeName" => homeName, "homeColor" => homeColor,
            "awayName" => awayName, "awayColor" => awayColor,
            "halfLen" => halfLen, "brkLen" => brkLen,
            "kickoff" => kickoffSel,
            "isNew" => (matchId == null)
        };
        if (matchId != null) { cfg["id"] = matchId; }
        gMatch = new Match(cfg);
        gMatch.start();
        var mv = new MainView();
        WatchUi.switchToView(mv, new MainDelegate(mv), WatchUi.SLIDE_LEFT);
    }
}

class SetupDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onTap(evt) as Lang.Boolean {
        var c = evt.getCoordinates();
        var x = c[0]; var y = c[1];
        if (hit(view.homeBox, x, y)) { view.kickoffSel = "home"; WatchUi.requestUpdate(); return true; }
        if (hit(view.awayBox, x, y)) { view.kickoffSel = "away"; WatchUi.requestUpdate(); return true; }
        if (hit(view.startBox, x, y)) { view.startMatch(); return true; }
        return false;
    }

    function onBack() as Lang.Boolean {
        var lv = new MatchListView();
        WatchUi.switchToView(lv, new MatchListDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }

    function hit(box, x, y) {
        return x >= box[0] && x <= box[0] + box[2] &&
               y >= box[1] && y <= box[1] + box[3];
    }
}
