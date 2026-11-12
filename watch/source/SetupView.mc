import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;

// Entry screen: shows the upcoming match (loaded from Firebase, if any),
// lets the ref choose which team kicks off, then starts the match.
class SetupView extends WatchUi.View {

    var homeName, homeColor, awayName, awayColor, halfLen, brkLen, matchId;
    var kickoffSel;
    var loading;
    // hit regions [x,y,w,h]
    var homeBox, awayBox, startBox;

    function initialize() {
        View.initialize();
        homeName = "الأرض";  homeColor = "green";
        awayName = "الضيف";  awayColor = "blue";
        halfLen = 45; brkLen = 15; matchId = null;
        kickoffSel = "home";
        loading = true;
        homeBox = [0,0,0,0]; awayBox = [0,0,0,0]; startBox = [0,0,0,0];
    }

    function onShow() as Void {
        if (gSync != null) {
            gSync.fetchMatches(method(:onMatches));
        } else {
            loading = false;
        }
    }

    // Callback from Sync.fetchMatches
    function onMatches(list) as Void {
        loading = false;
        for (var i = 0; i < list.size(); i++) {
            var m = list[i];
            if (!m["status"].equals("done")) {
                homeName  = m["homeName"];
                homeColor = m["homeColor"];
                awayName  = m["awayName"];
                awayColor = m["awayColor"];
                halfLen   = m["halfLen"];
                brkLen    = m["brkLen"];
                matchId   = m["id"];
                break;
            }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.TXT, Theme.BG);
        dc.clear();

        // title
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.12, Graphics.FONT_TINY, "ركلة البداية لمن؟",
            Graphics.TEXT_JUSTIFY_CENTER);

        if (loading) {
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL, "جارٍ التحميل…",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var bw = (w * 0.56).toNumber();
        var bh = (h * 0.14).toNumber();
        var bx = cx - bw / 2;

        // home box
        var hy = (h * 0.24).toNumber();
        homeBox = [bx, hy, bw, bh];
        drawTeamBox(dc, homeBox, homeName, homeColor, Theme.HOME, kickoffSel.equals("home"));

        // away box
        var ay = (h * 0.42).toNumber();
        awayBox = [bx, ay, bw, bh];
        drawTeamBox(dc, awayBox, awayName, awayColor, Theme.AWAY, kickoffSel.equals("away"));

        // start button
        var sw = (w * 0.42).toNumber();
        var sh = (h * 0.13).toNumber();
        var sx = cx - sw / 2;
        var sy = (h * 0.62).toNumber();
        startBox = [sx, sy, sw, sh];
        dc.setColor(0x1F261F, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(sx, sy, sw, sh, 14);
        dc.setColor(0x8FC98F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sy + sh / 2, Graphics.FONT_MEDIUM, "ابدأ",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // hint
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.80, Graphics.FONT_XTINY, "الثاني للفريق الآخر تلقائياً",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawTeamBox(dc, box, name, kitId, accent, selected) {
        var x = box[0]; var y = box[1]; var bw = box[2]; var bh = box[3];
        dc.setColor(selected ? 0x1F261F : Theme.CARD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, 12);
        if (selected) {
            dc.setPenWidth(3);
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, bw, bh, 12);
            dc.setPenWidth(1);
        }
        // kit dot
        dc.setColor(Theme.kit(kitId), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 20, y + bh / 2, 7);
        // name
        dc.setColor(selected ? Theme.TXT : Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + bw / 2 + 10, y + bh / 2, Graphics.FONT_SMALL, name,
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

    function hit(box, x, y) {
        return x >= box[0] && x <= box[0] + box[2] &&
               y >= box[1] && y <= box[1] + box[3];
    }
}
