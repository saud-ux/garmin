import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;

// Main in-match screen: progress ring + timer + score, plus break, final,
// and full-screen event notifications (minute is the hero).
class MainView extends WatchUi.View {

    // Notification state. notifKind: null | "goal" | "yellow" | "red" | "added" | "text"
    var notifKind;
    var notifTeam;
    var notifPlayer;
    var notifMin;
    var notifSecond;
    var notifText;
    var notifTimer;

    function initialize() {
        View.initialize();
        notifKind = null;
        notifTeam = "home";
        notifPlayer = "";
        notifMin = 0;
        notifSecond = false;
        notifText = "";
        gMainView = self;
    }

    // ---- notifications ----
    function startNotifTimer(ms) {
        if (notifTimer == null) { notifTimer = new Timer.Timer(); }
        notifTimer.stop();
        notifTimer.start(method(:clearNotif), ms, false);
    }

    function clearNotif() as Void {
        notifKind = null;
        WatchUi.requestUpdate();
    }

    // Called after a goal/card. The minute is shown large.
    function showEvent(kind, team, player, minVal, second) {
        notifKind = kind;
        notifTeam = team;
        notifPlayer = (player == null) ? "" : player;
        notifMin = minVal;
        notifSecond = second;
        startNotifTimer(2200);
        WatchUi.requestUpdate();
    }

    function showAdded(minutes) {
        notifKind = "added";
        notifText = "+" + minutes.toString();
        startNotifTimer(1600);
        WatchUi.requestUpdate();
    }

    function showMessage(text) {
        notifKind = "text";
        notifText = text;
        startNotifTimer(1400);
        WatchUi.requestUpdate();
    }

    // Back-compat: plain text toast maps to a centered message.
    function showToast(text) {
        showMessage(text);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.TXT, Theme.BG);
        dc.clear();

        if (notifKind != null) {
            drawNotification(dc, w, h, cx, gMatch);
            return;
        }

        var m = gMatch;
        if (m == null) { return; }

        if (m.phase.equals("half")) {
            drawBreak(dc, w, h, cx, m);
        } else if (m.phase.equals("done")) {
            drawDone(dc, w, h, cx, m);
        } else {
            drawPlay(dc, w, h, cx, m);
        }
    }

    // ---- play screen ----
    function drawPlay(dc, w, h, cx, m) {
        var cy = h / 2;
        var r = (w / 2) - 5;

        // progress ring: green for the half, amber while added-time counts
        if (m.addedRunning && m.addedTargetSec > 0) {
            var af = m.addedElapsedSec.toFloat() / m.addedTargetSec.toFloat();
            if (af > 1.0) { af = 1.0; }
            drawRing(dc, cx, cy, r, Theme.TRACK_AMBER, Theme.AMBER, af);
        } else {
            var total = m.halfLen * 60;
            var into = m.phase.equals("2nd") ? (m.elapsedSec - total) : m.elapsedSec;
            var frac = (total > 0) ? (into.toFloat() / total) : 0.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            drawRing(dc, cx, cy, r, Theme.TRACK, Theme.HOME, frac);
        }

        // phase label
        dc.setColor(m.addedRunning ? Theme.AMBER : Theme.HOME, Graphics.COLOR_TRANSPARENT);
        var label = m.phase.equals("1st") ? "الشوط الأول" : "الشوط الثاني";
        dc.drawText(cx, h * 0.20, Graphics.FONT_XTINY,
            m.addedRunning ? "بدل الضائع" : label, Graphics.TEXT_JUSTIFY_CENTER);

        // main clock (hero)
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.40, Graphics.FONT_NUMBER_HOT, m.clockText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var scoreY = h * 0.70;
        if (m.addedRunning) {
            dc.setColor(Theme.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.57, Graphics.FONT_MEDIUM, "+" + Match.mmss(m.addedElapsedSec),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.AMBER_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.65, Graphics.FONT_XTINY, "من +" + Match.mmss(m.addedTargetSec),
                Graphics.TEXT_JUSTIFY_CENTER);
            scoreY = h * 0.82;
            drawScore(dc, cx, scoreY, m);
        } else {
            drawScore(dc, cx, scoreY, m);
            dc.setColor(Theme.SUB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, m.homeName + " · " + m.awayName,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawRing(dc, cx, cy, r, trackColor, fgColor, frac) {
        dc.setPenWidth(5);
        dc.setColor(trackColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        if (frac > 0.0) {
            var endDeg = 90.0 - (360.0 * frac);
            while (endDeg < 0.0) { endDeg += 360.0; }
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endDeg.toNumber());
        }
        dc.setPenWidth(1);
    }

    function drawScore(dc, cx, y, m) {
        var s = m.score();
        dc.setColor(Theme.kit(m.homeColor), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 52, y, 5);
        dc.setColor(Theme.kit(m.awayColor), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 52, y, 5);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_MEDIUM, s[0].toString() + " - " + s[1].toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- break / done ----
    function drawBreak(dc, w, h, cx, m) {
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.26, Graphics.FONT_SMALL, "الاستراحة", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.48, Graphics.FONT_NUMBER_MEDIUM, m.breakText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.HOME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.72, Graphics.FONT_XTINY, "الزر السفلي ← بدء الشوط الثاني",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawDone(dc, w, h, cx, m) {
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.20, Graphics.FONT_TINY, "انتهت المباراة", Graphics.TEXT_JUSTIFY_CENTER);
        drawScore(dc, cx, h * 0.46, m);
        dc.setColor(Theme.SUB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.63, Graphics.FONT_XTINY, m.homeName + " · " + m.awayName,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.77, Graphics.FONT_XTINY, "الزر السفلي: مباراة جديدة",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- full-screen notification (minute is the hero) ----
    function drawNotification(dc, w, h, cx, m) {
        if (notifKind.equals("goal")) {
            dc.setColor(Theme.accent(notifTeam), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.22, Graphics.FONT_SMALL, "هدف",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            drawTwoNumbers(dc, w, h, cx);
            dc.setColor(Theme.SUB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.82, Graphics.FONT_SMALL, teamOnly(m), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (notifKind.equals("yellow") || notifKind.equals("red")) {
            var isRed = notifKind.equals("red");
            var c = isRed ? Theme.RED : Theme.YELLOW;
            var lbl = notifSecond ? "صفراء ثانية · طرد" : (isRed ? "بطاقة حمراء" : "بطاقة صفراء");
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            var lw = dc.getTextWidthInPixels(lbl, Graphics.FONT_SMALL);
            dc.fillRoundedRectangle((cx + lw / 2 + 9).toNumber(), (h * 0.22 - 9).toNumber(), 13, 18, 3);
            dc.drawText(cx - 6, h * 0.22, Graphics.FONT_SMALL, lbl,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            drawTwoNumbers(dc, w, h, cx);
            dc.setColor(Theme.SUB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.82, Graphics.FONT_SMALL, teamOnly(m), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (notifKind.equals("added")) {
            dc.setColor(Theme.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.30, Graphics.FONT_SMALL, "الوقت الإضافي", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.52, Graphics.FONT_LARGE, notifText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.50, Graphics.FONT_MEDIUM, notifText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Big minute number with a small ' marker next to it.
    function drawMinuteHero(dc, cx, cy) {
        var s = notifMin.toString();
        var f = Graphics.FONT_NUMBER_HOT;
        var wNum = dc.getTextWidthInPixels(s, f);
        var wMark = dc.getTextWidthInPixels("'", Graphics.FONT_SMALL);
        var totalW = wNum + wMark + 3;
        var startX = cx - totalW / 2;
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, cy, f, s,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + wNum + 3, cy - (dc.getFontHeight(f) / 5), Graphics.FONT_SMALL, "'",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Minute and player number side by side, both large. If no player was
    // entered, the minute shows large and centered on its own.
    function drawTwoNumbers(dc, w, h, cx) {
        if (notifPlayer != null && !notifPlayer.equals("")) {
            dc.setPenWidth(1);
            dc.setColor(0x2A2F2B, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx, (h * 0.45).toNumber(), cx, (h * 0.65).toNumber());
            var rx = (cx + w * 0.18).toNumber();
            var lx = (cx - w * 0.18).toNumber();
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rx, h * 0.47, Graphics.FONT_XTINY, "الدقيقة", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(lx, h * 0.47, Graphics.FONT_XTINY, "اللاعب", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rx, h * 0.585, Graphics.FONT_LARGE, notifMin.toString() + "'",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(lx, h * 0.585, Graphics.FONT_LARGE, "#" + notifPlayer,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            drawMinuteHero(dc, cx, h * 0.52);
        }
    }

    function teamOnly(m) {
        return (m != null) ? m.teamName(notifTeam)
                           : (notifTeam.equals("home") ? "الأرض" : "الضيف");
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
            var lv = new MatchListView();
            WatchUi.switchToView(lv, new MatchListDelegate(), WatchUi.SLIDE_RIGHT);
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
