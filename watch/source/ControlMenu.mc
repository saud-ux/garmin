import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

// Bottom-button control menu. Content depends on match phase.
function buildControlMenu(match) {
    var menu = new WatchUi.Menu2({ :title => "التحكم" });
    if (match.phase.equals("1st")) {
        menu.addItem(new WatchUi.MenuItem("إنهاء الشوط الأول", null, "endFirst", null));
    } else if (match.phase.equals("half")) {
        menu.addItem(new WatchUi.MenuItem("بدء الشوط الثاني", null, "startSecond", null));
    } else if (match.phase.equals("2nd")) {
        menu.addItem(new WatchUi.MenuItem("إنهاء المباراة", null, "endMatch", null));
    }
    menu.addItem(new WatchUi.MenuItem("المنذَرون", null, "booked", null));
    menu.addItem(new WatchUi.MenuItem("تراجع عن آخر حدث", null, "undo", null));
    return menu;
}

class ControlMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        var m = gMatch;
        if (m == null) { WatchUi.popView(WatchUi.SLIDE_DOWN); return; }

        if (id.equals("endFirst")) {
            m.endFirstHalf();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id.equals("startSecond")) {
            m.startSecondHalf();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id.equals("endMatch")) {
            m.endMatch();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id.equals("booked")) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.pushView(new BookedView(), new BookedDelegate(), WatchUi.SLIDE_UP);
        } else if (id.equals("undo")) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // close menu -> main
            var dialog = new WatchUi.Confirmation("تراجع عن آخر حدث؟");
            WatchUi.pushView(dialog, new UndoConfirmDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class UndoConfirmDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES && gMatch != null) {
            gMatch.undoLast();
            if (gMainView != null) {
                gMainView.showToast("تم التراجع");
            }
        }
        return true;
    }
}

// Booked players list (yellow / red per team).
class BookedView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        var m = gMatch;
        dc.setColor(Theme.SUB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_XTINY, "المنذَرون", Graphics.TEXT_JUSTIFY_CENTER);
        if (m == null) { return; }

        var hasAny = (m.count("yellow") + m.count("red")) > 0;
        if (!hasAny) {
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.5, Graphics.FONT_XTINY, "لا يوجد منذَرون", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setPenWidth(1);
        dc.setColor(0x2A2F2B, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, (h * 0.22).toNumber(), cx, (h * 0.9).toNumber());
        drawTeamBooked(dc, m, "home", (cx + w * 0.24).toNumber(), h);
        drawTeamBooked(dc, m, "away", (cx - w * 0.24).toNumber(), h);
    }

    function drawTeamBooked(dc, m, team, x, h) {
        dc.setColor(Theme.accent(team), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 0.26, Graphics.FONT_XTINY, m.teamName(team), Graphics.TEXT_JUSTIFY_CENTER);
        var y = h * 0.40;
        for (var i = 0; i < m.events.size(); i++) {
            var e = m.events[i];
            if (!e["team"].equals(team)) { continue; }
            var red = e["kind"].equals("red");
            if (!(e["kind"].equals("yellow") || red)) { continue; }
            var p = e["player"];
            if (p == null || p.equals("")) { p = "؟"; }
            dc.setColor(red ? Theme.RED : Theme.YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle((x - 26).toNumber(), (y - 7).toNumber(), 10, 15, 2);
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + 4, y, Graphics.FONT_SMALL, "#" + p,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            y += h * 0.13;
            if (y > h * 0.9) { break; }
        }
    }
}

class BookedDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
