import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

// Unified number pad (1-9, 0, تم, مسح) used for player number AND added time.
// mode: "added" -> minutes of added time ; "player" -> player number for an event.
class NumberPad extends WatchUi.View {

    var mode, kind, team;
    var value;
    var title;
    var cells;   // array of [x,y,w,h,label,action]

    function initialize(m, k, t) {
        View.initialize();
        mode = m; kind = k; team = t;
        value = "";
        cells = [];
        if (mode.equals("added")) {
            title = "الوقت الإضافي";
        } else {
            title = "رقم اللاعب";
        }
    }

    function press(action) {
        if (action.equals("clear")) {
            if (value.length() > 0) { value = value.substring(0, value.length() - 1); }
        } else if (action.equals("done")) {
            complete();
            return;
        } else {
            if (value.length() < 2) { value += action; }
        }
        WatchUi.requestUpdate();
    }

    function complete() {
        var m = gMatch;
        if (m != null) {
            if (mode.equals("added")) {
                var n = value.length() > 0 ? value.toNumber() : 0;
                m.setAddedTime(n);
                if (gMainView != null) {
                    gMainView.showToast("الوقت الإضافي +" + n.toString());
                }
            } else {
                var min = m.currentMinute();
                var second = m.addEvent(kind, team, value, "");
                if (gMainView != null) {
                    gMainView.showToast(toastFor(m, min, second));
                }
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function toastFor(m, min, second) {
        if (second) {
            return m.teamName(team) + " · صفراء ثانية · طرد · " + min.toString() + "'";
        }
        var label = kind.equals("goal") ? "هدف" :
                    (kind.equals("yellow") ? "بطاقة صفراء" : "بطاقة حمراء");
        var who = value.length() > 0 ? " #" + value : "";
        return m.teamName(team) + " · " + label + who + " · " + min.toString() + "'";
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.TXT, Theme.BG);
        dc.clear();

        // title + current value
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.07, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.15, Graphics.FONT_SMALL,
            value.length() > 0 ? value : "—", Graphics.TEXT_JUSTIFY_CENTER);

        // grid
        var cols = 3;
        var cellW = (w * 0.20).toNumber();
        var cellH = (h * 0.14).toNumber();
        var gapX = (w * 0.03).toNumber();
        var gapY = (h * 0.018).toNumber();
        var totalW = cols * cellW + (cols - 1) * gapX;
        var startX = cx - totalW / 2;
        var startY = (h * 0.24).toNumber();

        var layout = [
            ["1","1"],["2","2"],["3","3"],
            ["4","4"],["5","5"],["6","6"],
            ["7","7"],["8","8"],["9","9"],
            ["تم","done"],["0","0"],["⌫","clear"]
        ];
        cells = [];
        for (var i = 0; i < layout.size(); i++) {
            var r = i / cols;
            var c = i % cols;
            var x = startX + c * (cellW + gapX);
            var y = startY + r * (cellH + gapY);
            var label = layout[i][0];
            var action = layout[i][1];
            cells.add([x, y, cellW, cellH, label, action]);
            drawKey(dc, x, y, cellW, cellH, label, action);
        }
    }

    function drawKey(dc, x, y, cw, ch, label, action) {
        var bg = Theme.KEYBG;
        var fg = Theme.TXT;
        if (action.equals("done")) { bg = 0x1F261F; fg = 0x8FC98F; }
        else if (action.equals("clear")) { bg = 0x2A1F1F; fg = Theme.MUTED; }
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, cw, ch, 8);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + cw / 2, y + ch / 2, Graphics.FONT_SMALL, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class NumberPadDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onTap(evt) as Lang.Boolean {
        var co = evt.getCoordinates();
        var x = co[0]; var y = co[1];
        var cells = view.cells;
        for (var i = 0; i < cells.size(); i++) {
            var cell = cells[i];
            if (x >= cell[0] && x <= cell[0] + cell[2] &&
                y >= cell[1] && y <= cell[1] + cell[3]) {
                view.press(cell[5]);
                return true;
            }
        }
        return false;
    }

    // back button cancels number entry
    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
