import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

// Launch screen: fetches matches, then shows a chooser list.
// Never auto-selects — the ref always picks.
class MatchListView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        if (gSync != null) {
            gSync.fetchMatches(method(:onMatches));
        } else {
            showList([]);
        }
    }

    function onMatches(list) as Void {
        showList(list);
    }

    function showList(list) as Void {
        // upcoming matches only
        var upcoming = [];
        for (var i = 0; i < list.size(); i++) {
            if (list[i]["status"].equals("upcoming")) {
                upcoming.add(list[i]);
            }
        }

        var menu = new WatchUi.Menu2({ :title => "المباريات" });
        menu.addItem(new WatchUi.MenuItem("مباراة جديدة", null, "__new__", null));
        for (var i = 0; i < upcoming.size(); i++) {
            var m = upcoming[i];
            var title = m["homeName"] + " · " + m["awayName"];
            var sub = fmtWhen(m["date"]);
            menu.addItem(new WatchUi.MenuItem(title, sub, i.toString(), null));
        }
        WatchUi.switchToView(menu, new MatchMenuDelegate(upcoming), WatchUi.SLIDE_LEFT);
    }

    // "2026-11-13T20:00" -> "13/11 · 20:00"
    function fmtWhen(s) {
        if (s == null || s.equals("")) { return null; }
        var datePart = s;
        var timePart = "";
        var ti = s.find("T");
        if (ti != null) {
            datePart = s.substring(0, ti);
            timePart = s.substring(ti + 1, s.length());
        }
        var dd = "";
        var mm = "";
        if (datePart.length() >= 10) {
            mm = datePart.substring(5, 7);
            dd = datePart.substring(8, 10);
        }
        var hhmm = (timePart.length() >= 5) ? timePart.substring(0, 5) : timePart;
        if (!dd.equals("")) {
            return hhmm.equals("") ? (dd + "/" + mm) : (dd + "/" + mm + " · " + hhmm);
        }
        return s;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.TXT, Theme.BG);
        dc.clear();
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, "جارٍ التحميل…",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Delegate for the loading view (no interaction needed).
class MatchListDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
}

// Handles selection from the match chooser menu.
class MatchMenuDelegate extends WatchUi.Menu2InputDelegate {
    var matches;

    function initialize(m) {
        Menu2InputDelegate.initialize();
        matches = m;
    }

    function onSelect(item) {
        var id = item.getId() as Lang.String;
        if (id.equals("__new__")) {
            var sv = new SetupView();
            WatchUi.switchToView(sv, new SetupDelegate(sv), WatchUi.SLIDE_LEFT);
        } else {
            var idx = id.toNumber();
            if (idx != null && idx >= 0 && idx < matches.size()) {
                var sv = new SetupView();
                sv.preload(matches[idx]);
                WatchUi.switchToView(sv, new SetupDelegate(sv), WatchUi.SLIDE_LEFT);
            }
        }
    }
}
