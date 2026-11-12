import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;

// Main in-match screen: timer + score, plus break and final screens.
class MainView extends WatchUi.View {

    var toastText;
    var toastTimer;

    function initialize() {
        View.initialize();
        toastText = null;
        gMainView = self;
    }

    function showToast(text) {
        toastText = text;
        if (toastTimer == null) { toastTimer = new Timer.Timer(); }
        toastTimer.stop();
        toastTimer.start(method(:clearToast), 2000, false);
        WatchUi.requestUpdate();
    }

    function clearToast() as Void {
        toastText = null;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.TXT, Theme.BG);
        dc.clear();

        var m = gMatch;
        if (m == null) { return; }

        if (m.phase.equals("half")) {
            drawBreak(dc, w, h, cx, m);
        } else if (m.phase.equals("done")) {
            drawDone(dc, w, h, cx, m);
        } else {
            drawPlay(dc, w, h, cx, m);
        }

        if (toastText != null) {
            drawToast(dc, w, h, cx);
        }
    }

    function drawPlay(dc, w, h, cx, m) {
        var label = m.phase.equals("1st") ? "الشوط الأول" : "الشوط الثاني";
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_CENTER);

        // main clock
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.38, Graphics.FONT_NUMBER_MEDIUM, m.clockText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var scoreY = h * 0.72;
        if (m.addedRunning) {
            dc.setColor(Theme.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.57, Graphics.FONT_SMALL, m.addedText(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            // progress bar
            var bw = (w * 0.5).toNumber();
            var bx = cx - bw / 2;
            var by = (h * 0.64).toNumber();
            dc.setColor(0x2A2016, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, by, bw, 7, 3);
            if (m.addedTargetSec > 0) {
                var frac = m.addedElapsedSec.toFloat() / m.addedTargetSec.toFloat();
                if (frac > 1.0) { frac = 1.0; }
                var fw = (bw * frac).toNumber();
                if (fw > 0) {
                    dc.setColor(Theme.AMBER, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(bx, by, fw, 7, 3);
                }
            }
        }

        drawScore(dc, cx, scoreY, m);
    }

    function drawScore(dc, cx, y, m) {
        var s = m.score();
        dc.setColor(Theme.kit(m.homeColor), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 48, y, 6);
        dc.setColor(Theme.kit(m.awayColor), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 48, y, 6);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_MEDIUM, s[0].toString() + " - " + s[1].toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawBreak(dc, w, h, cx, m) {
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.28, Graphics.FONT_SMALL, "الاستراحة", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.50, Graphics.FONT_NUMBER_MEDIUM, m.breakText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.HOME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.72, Graphics.FONT_XTINY, "الزر السفلي ← بدء الشوط الثاني",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawDone(dc, w, h, cx, m) {
        var s = m.score();
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.22, Graphics.FONT_TINY, "انتهت المباراة", Graphics.TEXT_JUSTIFY_CENTER);
        drawScore(dc, cx, h * 0.46, m);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.64, Graphics.FONT_XTINY, m.homeName + " · " + m.awayName,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "الزر السفلي: مباراة جديدة",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawToast(dc, w, h, cx) {
        var bw = (w * 0.64).toNumber();
        var bh = (h * 0.20).toNumber();
        var bx = cx - bw / 2;
        var by = (h * 0.40).toNumber();
        dc.setColor(0x15110A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 14);
        dc.setPenWidth(2);
        dc.setColor(Theme.AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 14);
        dc.setPenWidth(1);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh / 2, Graphics.FONT_SMALL, toastText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Top button -> added time entry
    function onSelect() as Lang.Boolean {
        var m = gMatch;
        if (m != null && (m.phase.equals("1st") || m.phase.equals("2nd"))) {
            var np = new NumberPad("added", null, null);
            WatchUi.pushView(np, new NumberPadDelegate(np), WatchUi.SLIDE_UP);
        }
        return true;
    }

    // Bottom button -> control menu
    function onBack() as Lang.Boolean {
        var m = gMatch;
        if (m == null) { return false; }
        if (m.phase.equals("done")) {
            // start a new match
            var sv = new SetupView();
            WatchUi.switchToView(sv, new SetupDelegate(sv), WatchUi.SLIDE_RIGHT);
            return true;
        }
        var menu = buildControlMenu(m);
        WatchUi.pushView(menu, new ControlMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Swipe down -> home menu, swipe up -> away menu
    function onSwipe(evt) as Lang.Boolean {
        var m = gMatch;
        if (m == null || !(m.phase.equals("1st") || m.phase.equals("2nd"))) {
            return false;
        }
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_DOWN) {
            openTeamMenu("home");
            return true;
        } else if (dir == WatchUi.SWIPE_UP) {
            openTeamMenu("away");
            return true;
        }
        return false;
    }

    function openTeamMenu(team) {
        var menu = buildTeamMenu(gMatch, team);
        WatchUi.pushView(menu, new TeamMenuDelegate(team), WatchUi.SLIDE_UP);
    }
}
